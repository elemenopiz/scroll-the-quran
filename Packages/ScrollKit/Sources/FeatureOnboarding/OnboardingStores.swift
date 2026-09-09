import Foundation

// MARK: - Progress

/// Where "how far through onboarding are we" lives. Small on purpose: `UserState`
/// (Phase 2f) backs it with the App Group JSON store without this module changing.
public protocol OnboardingProgressStore: AnyObject {
    /// Index into `OnboardingStep.allCases`. 0 when the user has never started.
    var onboardingStep: Int { get set }
    /// Set once the funnel has been finished, so a relaunch skips it entirely.
    var onboardingFinished: Bool { get set }
}

/// Default `UserDefaults` implementation, used until `UserState` takes over.
public final class UserDefaultsOnboardingProgressStore: OnboardingProgressStore {
    public static let stepKey = "onboardingStep"
    public static let finishedKey = "onboardingFinished"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var onboardingStep: Int {
        get { defaults.integer(forKey: Self.stepKey) }
        set { defaults.set(newValue, forKey: Self.stepKey) }
    }

    public var onboardingFinished: Bool {
        get { defaults.bool(forKey: Self.finishedKey) }
        set { defaults.set(newValue, forKey: Self.finishedKey) }
    }
}

/// Progress that is never written anywhere: previews, snapshots and tests.
public final class EphemeralOnboardingProgressStore: OnboardingProgressStore {
    public var onboardingStep: Int
    public var onboardingFinished: Bool

    public init(onboardingStep: Int = 0, onboardingFinished: Bool = false) {
        self.onboardingStep = onboardingStep
        self.onboardingFinished = onboardingFinished
    }
}

// MARK: - Account

/// What the funnel learned about the user. The app provides the real sink later; the
/// funnel itself never talks to a network (`CLAUDE.md` rule 9).
public protocol OnboardingAccountSink: AnyObject {
    /// The stable user identifier Sign in with Apple hands back.
    func signedInWithApple(userID: String, email: String?, fullName: PersonNameComponents?)
    /// The optional address typed into the sheet. Stored on this device only.
    /// A blank address is a no-op, never a delete — use `clearEmail()` for that.
    func storeEmail(_ email: String?)
    func clearEmail()
}

/// Default `UserDefaults` implementation, used until `UserState` takes over.
public final class UserDefaultsAccountSink: OnboardingAccountSink {
    public static let accountIDKey = "accountId"
    public static let emailKey = "accountEmail"
    public static let nameKey = "accountName"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func signedInWithApple(userID: String, email: String?, fullName: PersonNameComponents?) {
        defaults.set(userID, forKey: Self.accountIDKey)
        if let email {
            defaults.set(email, forKey: Self.emailKey)
        }
        if let fullName {
            defaults.set(PersonNameComponentsFormatter().string(from: fullName), forKey: Self.nameKey)
        }
    }

    public func storeEmail(_ email: String?) {
        guard let trimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Self.emailKey)
    }

    public func clearEmail() {
        defaults.removeObject(forKey: Self.emailKey)
    }
}

/// Records what it was told and writes nothing: previews, snapshots and tests.
public final class EphemeralAccountSink: OnboardingAccountSink {
    public private(set) var appleUserID: String?
    public private(set) var email: String?

    public init() {}

    public func signedInWithApple(userID: String, email: String?, fullName _: PersonNameComponents?) {
        appleUserID = userID
        if let email {
            self.email = email
        }
    }

    public func storeEmail(_ email: String?) {
        guard let trimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return }
        self.email = trimmed
    }

    public func clearEmail() {
        email = nil
    }
}
