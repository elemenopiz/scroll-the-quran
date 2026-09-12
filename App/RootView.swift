import AppShell
import Commerce
import FeatureOnboarding
import FeaturePaywall
import SwiftUI
import UserState

/// The app's state machine: onboarding, then the paywall, then the one-time gift
/// offer if the paywall was dismissed, then the tab bar. `FeatureOnboarding` and
/// `FeaturePaywall` render the first three, so no `PlaceholderScreen` is left on
/// the funnel.
///
/// Everything long-lived is built once, here, by `AppEnvironment.live()` and handed down:
/// the bundled content, `UserStore`, and the single StoreKit entitlement store whose
/// `Transaction.updates` listener has to be running before the paywall appears.
///
/// `--screenshot <id>` bypasses the state machine and asks `ScreenRegistry` for that screen
/// directly, and `SCROLL_FIXED_DATE` pins "today", so every screen is capturable headlessly
/// and deterministically.
struct RootView: View {
    private let launch: LaunchOptions
    @State private var env: AppEnvironment
    @State private var flow: RootFlowModel
    @State private var tabs: TabRootModel
    @Environment(\.scenePhase) private var scenePhase

    /// The funnel — not `PaywallFlow` — decides whether dismissing the paywall earns the
    /// gift, because only the shell can see `Prefs.seenOneTimeOffer`. Handing the flow a
    /// store that already says "seen" makes `dismissTrial()` return control here instead of
    /// switching to the envelope behind the shell's back, so there is one state machine.
    private let funnelOffers = InMemoryOneTimeOfferStore(seenOneTimeOffer: true)

    init(launch: LaunchOptions = .live) {
        self.launch = launch
        let environment = AppEnvironment.shared(launch: launch)
        _env = State(initialValue: environment)
        _flow = State(
            initialValue: RootFlowModel(
                launch: launch,
                onboardingDone: environment.user.prefs.onboardingDone,
                subscribed: environment.entitlements.isPremium
            )
        )
        _tabs = State(initialValue: TabRootModel(selection: launch.screenshot?.tab ?? .home))
    }

    var body: some View {
        content
            .environment(\.appToday, env.today)
            .task {
                await env.start()
                enterTabsIfEntitled()
                if let url = launch.openURL {
                    open(url)
                }
            }
            // A subscription can lapse, be refunded, be approved by an Ask to Buy organiser
            // or fall into billing retry while the app is in the background, and StoreKit
            // does not redeliver a transaction for all of that. Re-read on every return.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await env.refresh()
                    enterTabsIfEntitled()
                }
            }
            // A purchase that lands anywhere — this paywall, another device, the updates
            // listener — ends the funnel. Watching the store rather than only the button's
            // callback means a renewal arriving mid-funnel is not shown a paywall.
            .onChange(of: env.entitlements.isPremium) { _, isPremium in
                guard isPremium else { return }
                enterTabsIfEntitled()
            }
            .onOpenURL { open($0) }
    }

    @ViewBuilder
    private var content: some View {
        if let route = launch.screenshot {
            ScreenRegistry.screen(for: route, env: env) { flow.advance() }
        } else {
            phaseContent
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch flow.phase {
        case .onboarding:
            // Phase 2d: the funnel itself, replacing the Phase 1 placeholder. With a
            // `--screenshot` route it pins to that screen with fixture state; without
            // one it resumes from persisted progress. Finishing moves to the paywall,
            // exactly as `PaywallScreens.view(forScreenID:…)` does below.
            FeatureOnboardingModule.view(
                forScreenID: launch.screenshot?.screen.rawValue,
                // The module does not know about `UserStore`; the funnel is only "done" once
                // the shell records it, or it replays on the next cold launch.
                onFinished: {
                    env.user.completeOnboarding()
                    flow.advance()
                }
            )
        case .paywall, .gift:
            PaywallScreens.view(
                forScreenID: flow.phase == .gift ? "gift-closed" : "paywall-trial",
                store: env.entitlements,
                offers: funnelOffers,
                links: env.legalLinks,
                onDismiss: dismissPaywall,
                onPurchased: purchased
            )
            // Both phases render the same view type in the same position, so without an
            // identity of their own SwiftUI keeps the first `PaywallModel` and the gift
            // never appears: the `stage` argument is only read by `init`.
            .id(flow.phase)
        case .tabs:
            TabRoot(env: env, model: tabs)
        }
    }

    /// Dismissing the trial paywall earns the one-time gift offer, once ever; dismissing
    /// the gift itself goes straight to the tabs.
    ///
    /// The envelope is marked seen the moment it is *shown*, not when it is dismissed: a
    /// force-quit on the offer screen must not hand the customer a second first-time
    /// discount on the next launch.
    private func dismissPaywall() {
        if flow.phase == .gift {
            flow.advance()
            return
        }
        let seen = env.user.hasSeenOneTimeOffer
        if !seen {
            env.user.markOneTimeOfferSeen()
        }
        flow.dismissPaywall(seenOneTimeOffer: seen)
    }

    /// A purchase anywhere in the funnel ends it.
    ///
    /// Onboarding is recorded as done at the same time: somebody who paid has been through
    /// the funnel, and a relaunch must not replay it while `Transaction.currentEntitlements`
    /// is still being read (the read is async; `RootFlowModel.init` is not).
    private func purchased() {
        env.user.completeOnboarding()
        flow.enterTabs()
    }

    /// Leaves the funnel once the store says the customer is entitled.
    private func enterTabsIfEntitled() {
        guard env.entitlements.isPremium, flow.phase != .tabs, launch.screenshot == nil else { return }
        purchased()
    }

    /// A deep link always ends on the tab bar, even on a cold launch that would otherwise
    /// have started in onboarding — a widget tap must land on its ayah.
    private func open(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        flow.enterTabs()
        tabs.handle(link)
    }
}

#Preview("Root") {
    RootView(launch: LaunchOptions())
}
