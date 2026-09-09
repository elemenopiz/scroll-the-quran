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
    public var isShowingSignIn = false
    public var email = ""

    public let content: OnboardingContent
    public let stats: OnboardingStats?

    @ObservationIgnored private let progress: any OnboardingProgressStore
    @ObservationIgnored private let account: any OnboardingAccountSink
    @ObservationIgnored private let onFinished: () -> Void

    public init(
        content: OnboardingContent = .bundled,
        stats: OnboardingStats? = nil,
        progress: any OnboardingProgressStore = EphemeralOnboardingProgressStore(),
        account: any OnboardingAccountSink = EphemeralAccountSink(),
        startAt: OnboardingStep? = nil,
        onFinished: @escaping () -> Void = {}
    ) {
        self.content = content
        self.stats = stats
        self.progress = progress
        self.account = account
        self.onFinished = onFinished
        step = startAt ?? OnboardingStep(index: progress.onboardingStep)
    }

    // MARK: - Navigation

    public func advance() {
        guard let next = step.next else {
            finish()
            return
        }
        step = next
        progress.onboardingStep = next.index
    }

    public func goBack() {
        guard let previous = step.previous else { return }
        step = previous
        progress.onboardingStep = previous.index
    }

    public func finish() {
        progress.onboardingStep = OnboardingStep.allCases.count - 1
        progress.onboardingFinished = true
        onFinished()
    }

    // MARK: - Sign in

    public func showSignIn() {
        isShowingSignIn = true
    }

    public func dismissSignIn() {
        commitEmail()
        isShowingSignIn = false
    }

    public func signedInWithApple(userID: String, email: String?, fullName: PersonNameComponents?) {
        account.signedInWithApple(userID: userID, email: email, fullName: fullName)
        isShowingSignIn = false
        advance()
    }

    /// The optional address is stored locally the moment the sheet goes away; there is
    /// no code to send and no request to make.
    public func commitEmail() {
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
