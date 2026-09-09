import Foundation
import Observation

/// Real App Store numbers for the reviews screen. Nothing is rendered from a
/// placeholder token: with no stats injected the screen drops the count and hides
/// the rating pill rather than inventing social proof.
public struct OnboardingStats: Equatable, Sendable {
    public let installCount: String
    public let reviewCount: String
    public let ratingValue: String

    public init(installCount: String, reviewCount: String, ratingValue: String) {
        self.installCount = installCount
        self.reviewCount = reviewCount
        self.ratingValue = ratingValue
    }
}

/// Drives the funnel: which step is on screen, whether the sign-in sheet is up, and
/// persisting progress so a relaunch resumes where the user stopped.
@MainActor
@Observable
public final class OnboardingModel {
    public private(set) var step: OnboardingStep
    /// Set once, when the funnel is done. The view watches it and calls its own
    /// `onFinished`, so a stale closure captured at first render can never be called.
    public private(set) var isFinished = false
    public var isShowingSignIn = false
    public var email = ""
    /// True once Sign in with Apple has handed us an account, so dismissing the sheet
    /// does not then overwrite the Apple address with the empty text field.
    public private(set) var didSignInWithApple = false

    public let content: OnboardingContent
    public let stats: OnboardingStats?

    @ObservationIgnored private let progress: any OnboardingProgressStore
    @ObservationIgnored private let account: any OnboardingAccountSink
    /// The steps this content can actually render: a short `slides` array must not leave
    /// the funnel stuck on a blank screen it has already persisted.
    @ObservationIgnored private let steps: [OnboardingStep]

    public init(
        content: OnboardingContent = .bundled,
        stats: OnboardingStats? = nil,
        progress: any OnboardingProgressStore = EphemeralOnboardingProgressStore(),
        account: any OnboardingAccountSink = EphemeralAccountSink(),
        startAt: OnboardingStep? = nil
    ) {
        self.content = content
        self.stats = stats
        self.progress = progress
        self.account = account
        steps = OnboardingStep.allCases.filter { step in
            step.slideIndex.map { $0 < content.slides.count } ?? true
        }
        // Resume on the requested step, or the nearest reachable one before it when the
        // content no longer has the slide that index points at.
        let requested = startAt ?? OnboardingStep(index: progress.onboardingStep)
        step = steps.last { $0.index <= requested.index } ?? steps.first ?? .hook
    }

    // MARK: - Navigation

    public func advance() {
        guard let here = steps.firstIndex(of: step), here + 1 < steps.count else {
            finish()
            return
        }
        move(to: steps[here + 1])
    }

    public func goBack() {
        guard let here = steps.firstIndex(of: step), here > 0 else { return }
        move(to: steps[here - 1])
    }

    public func finish() {
        progress.onboardingStep = OnboardingStep.allCases.count - 1
        progress.onboardingFinished = true
        isFinished = true
    }

    private func move(to next: OnboardingStep) {
        step = next
        progress.onboardingStep = next.index
    }

    // MARK: - Sign in

    public func showSignIn() {
        isShowingSignIn = true
    }

    public func dismissSignIn() {
        isShowingSignIn = false
    }

    public func signedInWithApple(userID: String, email: String?, fullName: PersonNameComponents?) {
        didSignInWithApple = true
        account.signedInWithApple(userID: userID, email: email, fullName: fullName)
        isShowingSignIn = false
        advance()
    }

    /// The optional address is stored locally when the sheet goes away; there is no code
    /// to send and no request to make. A blank field after an Apple sign-in must not
    /// clear the address Apple just gave us.
    public func sheetDismissed() {
        guard !didSignInWithApple else { return }
        account.storeEmail(email)
    }

    // MARK: - Reviews copy

    /// The subtitle with a real install count folded in, or the honest wording when
    /// there is no number to show.
    public var reviewsSubtitle: String {
        guard let stats else { return content.reviews.subtitleWithoutCount }
        return content.reviews.subtitle.replacingOccurrences(of: "{{installCount}}", with: stats.installCount)
    }

    public var reviewsRatingCount: String? {
        stats?.reviewCount
    }

    public var reviewsRatingValue: String? {
        stats?.ratingValue
    }
}
