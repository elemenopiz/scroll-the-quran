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
        step
            .animation(.easeInOut(duration: 0.25), value: model.step)
            .sheet(isPresented: $model.isShowingSignIn, onDismiss: model.commitEmail) {
                SignInSheet(
                    content: model.content.signIn,
                    email: $model.email,
                    onAppleSignIn: { credential in
                        model.signedInWithApple(
                            userID: credential.user,
                            email: credential.email,
                            fullName: credential.fullName
                        )
                    },
                    onSkip: model.dismissSignIn
                )
                .presentationDetents([.height(OnboardingMetrics.sheetHeight)])
                .presentationDragIndicator(.visible)
            }
            .accessibilityIdentifier("onboarding.flow")
    }

    @ViewBuilder
    private var step: some View {
        switch model.step {
        case .hook:
            HookScreen(
                content: model.content.hook,
                onContinue: model.advance,
                onAlreadySignedUp: model.showSignIn
            )
        case .slide1, .slide2, .slide3, .slide4:
            if let index = model.step.slideIndex, index < model.content.slides.count {
                SlideScreen(
                    slide: model.content.slides[index],
                    primaryCTA: model.content.hook.primaryCTA,
                    onContinue: model.advance
                )
            }
        case .reviews:
            ReviewsScreen(
                content: model.content.reviews,
                subtitle: model.reviewsSubtitle,
                ratingValue: model.reviewsRatingValue,
                ratingCount: model.reviewsRatingCount,
                onContinue: model.advance
            )
        }
    }
}

#Preview("Flow") {
    OnboardingFlow(content: .sample, progress: EphemeralOnboardingProgressStore(), account: EphemeralAccountSink())
}
