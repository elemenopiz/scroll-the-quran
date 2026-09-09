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
                if let url = launch.openURL {
                    open(url)
                }
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
                offers: env.offers,
                onDismiss: dismissPaywall,
                onPurchased: { flow.advance() }
            )
        case .tabs:
            TabRoot(env: env, model: tabs)
        }
    }

    /// Dismissing the trial paywall earns the one-time gift offer, once ever; dismissing
    /// the gift itself goes straight to the tabs.
    private func dismissPaywall() {
        if flow.phase == .gift {
            env.user.markOneTimeOfferSeen()
            flow.advance()
        } else {
            flow.dismissPaywall(seenOneTimeOffer: env.user.hasSeenOneTimeOffer)
        }
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
