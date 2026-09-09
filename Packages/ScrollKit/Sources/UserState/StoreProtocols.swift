import Foundation
import QuranData

// Narrow views onto `UserStore` for the feature packages, so `FeatureOnboarding`,
// `FeaturePaywall` and the sign-in flow can be built and tested against a protocol (and a
// stub) instead of the whole store. `UserStore` conforms to all three.

/// Onboarding's slice: where the user got to, and whether they finished.
@MainActor
public protocol OnboardingProgressStore: AnyObject {
    var onboardingStep: Int { get }
    var onboardingDone: Bool { get }
    func setOnboardingStep(_ step: Int)
    func completeOnboarding()
    func resetOnboarding()
}

/// The paywall's slice: the one-time offer envelope is shown once, ever.
@MainActor
public protocol OfferSeenStore: AnyObject {
    var hasSeenOneTimeOffer: Bool { get }
    func markOneTimeOfferSeen()
}

/// Sign in with Apple's slice: somewhere to put the credential once the user signs in.
@MainActor
public protocol AccountSink: AnyObject {
    var accountID: String? { get }
    var accountEmail: String? { get }
    var isSignedIn: Bool { get }
    func signIn(accountID: String, email: String?)
    func signOut()
}

/// The reader's slice: mark an ayah read, remember where we were.
@MainActor
public protocol ReadingPositionStore: AnyObject {
    var lastReaderPosition: ReaderPosition? { get }
    func setReaderPosition(_ verse: VerseRef, page: Int)
    func markRead(_ verse: VerseRef, in span: SurahSpan)
}
