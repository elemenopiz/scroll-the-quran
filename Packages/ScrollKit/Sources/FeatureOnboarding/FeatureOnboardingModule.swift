import SwiftUI

/// Entry points into `FeatureOnboarding`.
public enum FeatureOnboardingModule {
    public static let moduleName = "FeatureOnboarding"
}

public extension FeatureOnboardingModule {
    /// Fixture stats used only by `--screenshot onboarding-reviews`, so the rating pill
    /// has something to lay out. Never used by the shipping funnel: real numbers must
    /// come from App Store Connect before that screen ships.
    static let snapshotStats = OnboardingStats(
        installCount: "12,480",
        reviewCount: "310+",
        ratingValue: "4.8"
    )

    /// Routes a `--screenshot <id>` / `Reference/manifest.json` screen id to the view
    /// that renders it, with deterministic fixture state.
    ///
    /// **`RootView` does not call this yet.** Phase 1 froze `App/RootView.swift` rendering
    /// a `PlaceholderScreen` for the whole onboarding phase, and `AppShell` exposes no
    /// registration seam, so the orchestrator has to wire this in before
    /// `Tools/verify.sh --snap onboarding-*` can reach these screens.
    @MainActor
    static func screen(for id: String, onFinished: @escaping () -> Void = {}) -> AnyView? {
        guard let step = OnboardingStep(rawValue: id) ?? signInStep(for: id) else { return nil }
        return AnyView(
            OnboardingFlow(
                stats: step == .reviews ? snapshotStats : nil,
                progress: EphemeralOnboardingProgressStore(),
                account: EphemeralAccountSink(),
                startAt: step,
                showingSignIn: id == signInID,
                onFinished: onFinished
            )
        )
    }

    /// The sign-in sheet is not a step of its own: it is the hook with the sheet up.
    static let signInID = "onboarding-signin"

    private static func signInStep(for id: String) -> OnboardingStep? {
        id == signInID ? .hook : nil
    }

    /// Every screen id this module can render.
    static var screenIDs: [String] {
        OnboardingStep.allCases.map(\.rawValue) + [signInID]
    }
}
