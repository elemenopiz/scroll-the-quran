import DesignSystem
import FeatureHome
import FeatureOnboarding
import SwiftUI

/// The seam onto `FeatureHome`, which is still being built on another branch.
///
/// The Home tab and the `home`, `home#scrolled`, `plans-sheet`, `plan-detail` and
/// `verse-search` screenshot routes all come through here. Until `FeatureHome` exports a
/// view the shell renders the Phase 1 placeholder, which is what the parked UI tests skip
/// on; nothing else in `AppShell` has to change when it lands.
///
/// **When `FeatureHome` merges**, replace the body of `screen(anchor:env:)` with:
///
/// ```swift
/// HomeScreens.screen(
///     id: id, anchor: anchor, index: env.index, translations: env.translations,
///     studies: env.studies, user: env.user, today: env.today
/// )
/// ```
///
/// — one call, the same shape `DiscoverScreens.screen(id:anchor:…)` already has.
@MainActor
public enum HomeScreenProvider {
    /// The screen ids this seam answers to, in `Reference/manifest.json` order.
    public static let screenIDs = ["home", "plans-sheet", "plan-detail", "verse-search"]

    /// True once `FeatureHome` exports a real screen. Drives the UI tests' skip.
    public static let isWired = false

    public static func screen(id: String = "home", anchor: String? = nil, env _: AppEnvironment) -> some View {
        PlaceholderScreen(
            screenID: anchor.map { "\(id)#\($0)" } ?? id,
            title: title(for: id),
            systemImage: "house"
        )
    }

    private static func title(for id: String) -> String {
        switch id {
        case "plans-sheet": "Plans"
        case "plan-detail": "Plan"
        case "verse-search": "Search"
        default: "Home"
        }
    }
}

/// The same seam for `FeatureOnboarding`: the seven `onboarding-*` routes and the first
/// stage of `RootView`'s state machine.
///
/// **When `FeatureOnboarding` merges**, replace the body of `screen(id:env:onFinished:)`
/// with `OnboardingFlow(store: env.user, startingAt: id, onFinished: onFinished)`.
@MainActor
public enum OnboardingScreenProvider {
    public static let screenIDs = [
        "onboarding-hook", "onboarding-signin", "onboarding-slide1", "onboarding-slide2",
        "onboarding-slide3", "onboarding-slide4", "onboarding-reviews",
    ]

    public static let isWired = false

    public static func screen(
        id: String = "onboarding-hook",
        env: AppEnvironment,
        onFinished: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Spacing.lg) {
            PlaceholderScreen(screenID: id, title: "Onboarding", systemImage: "sparkle")
            if !env.launch.isSnapshotRun {
                Button("Continue", action: onFinished)
                    .accessibilityIdentifier("stage.continue")
                    .padding(.bottom, Spacing.xxl)
            }
        }
    }
}
