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
    /// that renders it, with deterministic fixture state: nothing is read from or
    /// written to `UserDefaults`, and the reviews screen gets its fixture stats.
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

    /// What `RootView` renders for `RootPhase.onboarding`.
    ///
    /// `id` is the `--screenshot` route when there is one: that pins the funnel to a
    /// single screen with fixture state so `Tools/snapshot/capture.sh` shoots the same
    /// pixels every run. With no route — the real first launch — the funnel starts from
    /// persisted progress and writes each step back, so a relaunch resumes where the
    /// user stopped. `onFinished` is `RootFlowModel.advance()`, which moves to the paywall.
    ///
    /// Mirrors `PaywallScreens.view(forScreenID:…)`, which is how `RootView` reaches the
    /// paywall, so the composition root treats both phases the same way.
    ///
    /// `account` is where a completed Sign in with Apple goes. The shell passes a
    /// `CompositeAccountSink` so the credential reaches both the Keychain and `UserStore`
    /// (audit SEC-2); the default keeps previews and `#Preview` builds on the Keychain sink
    /// alone, and a `--screenshot` route never reaches it at all — `screen(for:)` pins the
    /// funnel to `EphemeralAccountSink`, which writes nowhere.
    @MainActor
    static func view(
        forScreenID id: String?,
        account: any OnboardingAccountSink = KeychainAccountSink(),
        onFinished: @escaping () -> Void = {}
    ) -> AnyView {
        if let id, let screen = screen(for: id, onFinished: onFinished) {
            return screen
        }
        return AnyView(OnboardingFlow(account: account, onFinished: onFinished))
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
