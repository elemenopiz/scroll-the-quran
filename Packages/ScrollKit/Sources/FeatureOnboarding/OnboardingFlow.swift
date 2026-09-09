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

    public init(
        content: OnboardingContent = .bundled,
        stats: OnboardingStats? = nil,
        progress: any OnboardingProgressStore = UserDefaultsOnboardingProgressStore(),
        account: any OnboardingAccountSink = UserDefaultsAccountSink(),
        startAt: OnboardingStep? = nil,
        showingSignIn: Bool = false,
        onFinished: @escaping () -> Void = {}
    ) {
        let model = OnboardingModel(
            content: content,
            stats: stats,
            progress: progress,
            account: account,
            startAt: startAt,
            onFinished: onFinished
        )
        model.isShowingSignIn = showingSignIn
        _model = State(initialValue: model)
    }

    public var body: some View {
        OnboardingCanvas { scale in
            step(scale)
                .animation(.easeInOut(duration: 0.25), value: model.step)
                .overlay {
                    // The reference sheet sits on a ~48% black scrim (measured #828283 over
                    // #FAFAFC). iOS only dims for itself at detents at or above `.medium`,
                    // and this one is shorter, so the scrim is ours to draw.
                    Color.black
                        .opacity(model.isShowingSignIn ? OnboardingMetrics.sheetScrimOpacity : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .sheet(isPresented: $model.isShowingSignIn, onDismiss: model.commitEmail) {
                    signInSheet(scale)
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
        // A detent this short leaves the background undimmed by default; the reference
        // sheet sits on a ~48% black scrim, and disabling background interaction is what
        // brings that scrim back.
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
