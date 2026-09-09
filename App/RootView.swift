import AppShell
import Commerce
import FeatureOnboarding
import FeaturePaywall
import SwiftUI

/// The app's state machine: onboarding, then the paywall, then the one-time gift
/// offer if the paywall was dismissed, then the tab bar. `FeatureOnboarding` and
/// `FeaturePaywall` render the first three, so no `PlaceholderScreen` is left on
/// the funnel.
///
/// `--screenshot <id>` routes straight to a screen and `SCROLL_FIXED_DATE` pins
/// "today", so every screen is capturable headlessly and deterministically.
struct RootView: View {
    private let launch: LaunchOptions
    @State private var flow: RootFlowModel
    @State private var tabs: TabRootModel
    @State private var entitlements = MockEntitlementStore()
    @State private var offers = InMemoryOneTimeOfferStore()

    init(launch: LaunchOptions = .live) {
        self.launch = launch
        _flow = State(initialValue: RootFlowModel(launch: launch))
        _tabs = State(initialValue: TabRootModel(selection: launch.screenshot?.tab ?? .home))
    }

    var body: some View {
        content
            .environment(\.appToday, launch.fixedDate ?? Date())
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                tabs.handle(link)
            }
    }

    @ViewBuilder
    private var content: some View {
        if launch.screenshot?.screen == .gallery {
            GalleryScreen()
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
                onFinished: { flow.advance() }
            )
        case .paywall, .gift:
            PaywallScreens.view(
                forScreenID: launch.screenshot?.screen.rawValue
                    ?? (flow.phase == .gift ? "gift-closed" : "paywall-trial"),
                store: entitlements,
                offers: offers,
                onDismiss: { flow.advance() },
                onPurchased: { flow.advance() }
            )
        case .tabs:
            TabRoot(model: tabs)
        }
    }
}

#Preview("Root") {
    RootView(launch: LaunchOptions())
}
