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
    /// Which detent the sign-in sheet is on. Starts at the measured height and only
    /// moves to `.large` while the email field is being edited. Held in state rather
    /// than recomputed because `presentationDetents(_:selection:)` matches the
    /// selection against the set by equality, so both have to be the same value.
    @State private var signInDetent: PresentationDetent = .height(OnboardingMetrics.sheetHeight)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onFinished: () -> Void

    public init(
        content: OnboardingContent = .bundled,
        stats: OnboardingStats? = nil,
        progress: any OnboardingProgressStore = UserDefaultsOnboardingProgressStore(),
        account: any OnboardingAccountSink = KeychainAccountSink(),
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
                // The detent set is scaled to the running device, and the selection has
                // to be the *same* value or iOS falls back to the taller one. Resolved
                // as soon as the canvas has measured, before the sheet can be raised.
                .onAppear { signInDetent = Self.detent(scale) }
                .onChange(of: scale) { _, new in
                    if !model.isEditingEmail { signInDetent = Self.detent(new) }
                }
        }
        .background(Color.appBackground.ignoresSafeArea())
        // The screen id lives here, not only on the step view. Each step marks itself
        // `.accessibilityElement(children: .contain)` with `screen.<id>`, but that
        // container fills the window exactly like this one, and SwiftUI collapses the
        // pair into a single `Other` node carrying the OUTER identifier — so an id set
        // only here (it used to read "onboarding.flow") is the one XCUITest sees, and
        // `screen.onboarding-hook` was unreachable. Deriving it from the current step
        // keeps whichever node survives labelled with the screen actually on display.
        // The sign-in sheet is its own presentation, so `screen.onboarding-signin`
        // is unaffected.
        .accessibilityIdentifier("screen.\(model.step.rawValue)")
    }

    /// The sheet's measured height on the running device.
    private static func detent(_ scale: ReferenceScale) -> PresentationDetent {
        .height(scale.height(OnboardingMetrics.sheetHeight))
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
            onSkip: model.dismissSignIn,
            isEditingEmail: $model.isEditingEmail
        )
        // Two detents, with the selection bound: the sheet still *opens* on the measured
        // height from onboarding-signin.png (that is what `signInDetent` starts at, and
        // an explicit selection is what stops iOS choosing the taller one), and raising
        // the keyboard moves it to `.large` so the email field is not covered. It drops
        // back to the measured height when the field resigns, so the capture is
        // unchanged and the screen is usable.
        .presentationDetents([Self.detent(scale), .large], selection: $signInDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.disabled)
        .onChange(of: model.isEditingEmail) { _, editing in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                signInDetent = editing ? .large : Self.detent(scale)
            }
        }
        .onDisappear { signInDetent = Self.detent(scale) }

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
