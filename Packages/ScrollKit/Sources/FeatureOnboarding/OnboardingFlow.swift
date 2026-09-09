import DesignSystem
import SwiftUI

/// The whole first-run funnel: hook -> four slides -> reviews, with the sign-in sheet
/// reachable from the hook. `onFinished` is what `RootView` uses to move to the paywall.
///
/// Progress is written to the injected `OnboardingProgressStore` on every step, so a
/// relaunch resumes on the screen the user stopped at.
@MainActor
public struct OnboardingFlow: View {
    @State private var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onFinished: () -> Void

    public init(
        content: OnboardingContent = .bundled,
        stats: OnboardingStats? = nil,
        progress: any OnboardingProgressStore = UserDefaultsOnboardingProgressStore(),
        account: any OnboardingAccountSink = UserDefaultsAccountSink(),
        startAt: OnboardingStep? = nil,
        showingSignIn: Bool = false,
        onFinished: @escaping () -> Void = {}
    ) {
        self.onFinished = onFinished
        let model = OnboardingModel(
            content: content,
            stats: stats,
            progress: progress,
            account: account,
            startAt: startAt
        )
        model.isShowingSignIn = showingSignIn
        _model = State(initialValue: model)
    }

    public var body: some View {
        OnboardingCanvas { scale in
            step(scale)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.step)
                .overlay {
                    // The reference sheet sits on a scrim measured at #828283 over #FAFAFC.
                    // `presentationBackgroundInteraction(.disabled)` below gets iOS to dim
                    // at a detent this short, but only lightly; this overlay makes up the
                    // rest. The pair was tuned against onboarding-signin.png, not guessed —
                    // change either one and re-run Tools/snapshot/compare.sh.
                    Color.black
                        .opacity(model.isShowingSignIn ? OnboardingMetrics.sheetScrimOpacity : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.isShowingSignIn)
                }
                .sheet(isPresented: $model.isShowingSignIn, onDismiss: model.sheetDismissed) {
                    signInSheet(scale)
                }
                .onChange(of: model.isFinished) { _, finished in
                    if finished {
                        onFinished()
                    }
                }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .accessibilityIdentifier("onboarding.flow")
    }

    private func signInSheet(_ scale: ReferenceScale) -> some View {
        SignInSheet(
            content: model.content.signIn,
            email: $model.email,
            scale: scale,
            onAppleSignIn: { credential in
                model.signedInWithApple(
                    userID: credential.user,
                    email: credential.email,
                    fullName: credential.fullName
                )
            },
            onSkip: model.dismissSignIn
        )
        .presentationDetents([.height(scale.height(OnboardingMetrics.sheetHeight))])
        .presentationDragIndicator(.visible)
        // One detent only: the sheet's height is measured off onboarding-signin.png, and
        // adding a second (.large) makes iOS open on the wrong one. The keyboard covering
        // the email field is a known gap — see the report.
        .presentationBackgroundInteraction(.disabled)
    }

    @ViewBuilder
    private func step(_ scale: ReferenceScale) -> some View {
        switch model.step {
        case .hook:
            HookScreen(
                content: model.content.hook,
                scale: scale,
                onContinue: model.advance,
                onAlreadySignedUp: model.showSignIn
            )
        case .slide1, .slide2, .slide3, .slide4:
            if let index = model.step.slideIndex, index < model.content.slides.count {
                SlideScreen(
                    slide: model.content.slides[index],
                    primaryCTA: model.content.hook.primaryCTA,
                    scale: scale,
                    onContinue: model.advance
                )
            }
        case .reviews:
            ReviewsScreen(
                content: model.content.reviews,
                subtitle: model.reviewsSubtitle,
                ratingValue: model.reviewsRatingValue,
                ratingCount: model.reviewsRatingCount,
                scale: scale,
                onContinue: model.advance
            )
        }
    }
}

#Preview("Flow") {
    OnboardingFlow(content: .sample, progress: EphemeralOnboardingProgressStore(), account: EphemeralAccountSink())
}
