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

/// The Sign in with Apple *identity* — the Apple stable user identifier and the display
/// name — which lives in the Keychain and never in `prefs.json` (audit SEC-1).
///
/// `UserState` only ever needs to be able to drop it: sign-out and "delete my data" both
/// happen in Settings, which holds a `UserStore` and nothing else, so the store has to be
/// able to clear the record it deliberately does not own. `FeatureOnboarding`'s
/// `KeychainAccountSink` is what satisfies this; the shell attaches it at launch.
@MainActor
public protocol AccountIdentityStore: AnyObject {
    /// Forget the Apple user identifier, the address and the display name.
    func signOut()
}

/// Sign in with Apple's slice: the *state* of the account, which is all `UserStore` keeps.
///
/// The Apple user identifier is deliberately not a parameter (audit SEC-1/SEC-2). `prefs.json`
/// is plaintext in the App Group container and travels in unencrypted backups; what Settings
/// needs from it is a boolean and an address to show, so that is all it is given. The
/// identifier goes to `AccountIdentityStore` — the Keychain — instead.
@MainActor
public protocol AccountSink: AnyObject {
    var accountEmail: String? { get }
    var isSignedIn: Bool { get }
    /// Records that Sign in with Apple succeeded. Apple hands over the address on the first
    /// sign-in only, so a later `nil` must not wipe the one already stored.
    func signIn(email: String?)
    func signOut()
    /// Hands the store the Keychain record it must clear alongside its own flag.
    func attachIdentity(_ identity: any AccountIdentityStore)
}

/// The reader's slice: mark an ayah read, remember where we were.
@MainActor
public protocol ReadingPositionStore: AnyObject {
    var lastReaderPosition: ReaderPosition? { get }
    func setReaderPosition(_ verse: VerseRef, page: Int)
    func markRead(_ verse: VerseRef, in span: SurahSpan)
}
