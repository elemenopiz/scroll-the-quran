import DesignSystem
import FeatureHome
import FeatureOnboarding
import SwiftUI

/// The seam onto `FeatureHome`.
///
/// The Home tab and the `home`, `home#scrolled`, `plans-sheet`, `plan-detail` and
/// `verse-search` screenshot routes all come through here. `FeatureHome` cannot name
/// `AppShell.ScreenRoute` — the dependency runs the other way — so the route crosses the
/// seam as the string `ScreenRoute.rawValue` already produces.
@MainActor
public enum HomeScreenProvider {
    /// The screen ids this seam answers to, in `Reference/manifest.json` order.
    public static let screenIDs = ["home", "plans-sheet", "plan-detail", "verse-search"]

    /// True once `FeatureHome` exports a real screen. Drives the UI tests' skip.
    public static let isWired = true

    /// - Parameters:
    ///   - id: the `ScreenID` half of the route (`"home"`, `"plans-sheet"`).
    ///   - anchor: the `#anchor` half (`"scrolled"`), which `HomeRoute` reads as part of its
    ///     raw value.
    ///   - env: the composition root.
    ///   - navigation: the shell's router. `nil` outside the tab bar, which makes Home's
    ///     buttons inert — what a headless capture wants.
    public static func screen(
        id: String = "home",
        anchor: String? = nil,
        env: AppEnvironment,
        navigation: (any HomeNavigation)? = nil
    ) -> some View {
        let raw = anchor.map { "\(id)#\($0)" } ?? id
        // An unknown anchor is not a reason to show nothing: fall back to the plain screen.
        let route = HomeRoute(rawValue: raw) ?? HomeRoute(rawValue: id) ?? .home
        return HomeFeature.screen(for: route, env.homeEnvironment(navigation: navigation))
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
