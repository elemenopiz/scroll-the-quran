import Foundation
#if canImport(Security)
    import Security
#endif

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
    /// Forget everything about the account.
    ///
    /// Audit SEC-4: the old `UserDefaults` sink only ever had `clearEmail()`, which left
    /// the Apple user identifier and the display name behind after a sign-out. Nothing in
    /// the funnel calls this — sign-out lives in Settings — but the sink is the thing that
    /// owns the identity, so the sink is what has to be able to drop it.
    func signOut()
}

// MARK: - Keychain

/// The slice of the Keychain this module needs.
///
/// A protocol rather than bare `SecItem*` calls so the sink can be unit-tested with an
/// in-memory double: a host test that wrote real items would be writing into whichever
/// login keychain the test machine happens to have.
public protocol KeychainStoring: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    func removeValue(forKey key: String)
}

/// The real thing: `kSecClassGenericPassword` items under one service.
///
/// `kSecAttrAccessibleAfterFirstUnlock` rather than `…WhenUnlocked` because the widget
/// refreshes its timeline while the device is locked, and rather than
/// `…ThisDeviceOnly` because a reader who restores a backup onto a new phone should not
/// have to sign in with Apple again to keep the account they already had.
public final class SystemKeychain: KeychainStoring {
    /// One service for the whole account record; each field is an "account" inside it.
    public static let accountService = "com.scrollthequran.account"

    private let service: String
    /// The App Group access group, when the app is entitled to one.
    ///
    /// **Not set today.** Sharing an item with the widget extension needs
    /// `keychain-access-groups` in both `App/ScrollTheQuran.entitlements` and
    /// `Widget/ScrollTheQuranWidget.entitlements`, and neither carries it; `App/` is frozen
    /// after Phase 1, so this is reported rather than added. Without it the items live in
    /// the app's own default access group, which is what the app itself needs and means the
    /// widget reads nothing — the widget does not display the reader's name today, so
    /// nothing regresses.
    private let accessGroup: String?

    public init(service: String = SystemKeychain.accountService, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    private func query(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    public func string(forKey key: String) -> String? {
        var query = query(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query = query(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        // Update first: `SecItemAdd` on an existing account returns `errSecDuplicateItem`
        // rather than replacing it, which is how "the email never changes" bugs happen.
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess {
            return
        }
        var insert = query
        insert.merge(attributes) { _, new in new }
        SecItemAdd(insert as CFDictionary, nil)
    }

    public func removeValue(forKey key: String) {
        SecItemDelete(query(forKey: key) as CFDictionary)
    }
}

/// Keychain double for tests and previews. Writes nothing anywhere.
public final class InMemoryKeychain: KeychainStoring {
    public private(set) var storage: [String: String]

    public init(_ storage: [String: String] = [:]) {
        self.storage = storage
    }

    public func string(forKey key: String) -> String? {
        storage[key]
    }

    public func set(_ value: String, forKey key: String) {
        storage[key] = value
    }

    public func removeValue(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}

/// Where the Sign in with Apple identity lives (audit SEC-1).
///
/// It used to be three `UserDefaults` strings — the Apple stable user identifier, the
/// email and the formatted full name — sitting in the clear in the app's plist, and
/// therefore in unencrypted backups. None of it is ever transmitted (`CLAUDE.md` rule 9,
/// and `App/PrivacyInfo.xcprivacy` declares no collected data), so this was never an App
/// Store rejection; it was simply more personal data in the open than the app needs.
///
/// Existing installs are migrated on first construction and the plist keys are deleted, so
/// an app that has already run once does not keep a plaintext copy alongside the new one.
public final class KeychainAccountSink: OnboardingAccountSink {
    /// The same key names the `UserDefaults` sink used, so the migration is a straight
    /// move and a keychain dump reads the way the old plist did.
    public static let accountIDKey = "accountId"
    public static let emailKey = "accountEmail"
    public static let nameKey = "accountName"
    static let legacyKeys = [accountIDKey, emailKey, nameKey]

    private let keychain: any KeychainStoring
    private let defaults: UserDefaults

    public init(
        keychain: any KeychainStoring = SystemKeychain(),
        defaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.defaults = defaults
        migrateFromDefaults()
    }

    // MARK: Reading

    /// The Apple stable user identifier, or `nil` when nobody has signed in.
    public var appleUserID: String? {
        keychain.string(forKey: Self.accountIDKey)
    }

    public var email: String? {
        keychain.string(forKey: Self.emailKey)
    }

    /// The formatted full name Apple hands over on the first sign-in only.
    public var displayName: String? {
        keychain.string(forKey: Self.nameKey)
    }

    // MARK: Writing

    public func signedInWithApple(userID: String, email: String?, fullName: PersonNameComponents?) {
        keychain.set(userID, forKey: Self.accountIDKey)
        // Apple only hands over the email and the name on the very first sign-in; a later
        // sign-in arrives with both `nil` and must not wipe what we already have.
        if let email, !email.isEmpty {
            keychain.set(email, forKey: Self.emailKey)
        }
        if let fullName {
            let formatted = PersonNameComponentsFormatter().string(from: fullName)
            if !formatted.isEmpty {
                keychain.set(formatted, forKey: Self.nameKey)
            }
        }
    }

    public func storeEmail(_ email: String?) {
        guard let trimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return }
        keychain.set(trimmed, forKey: Self.emailKey)
    }

    public func clearEmail() {
        keychain.removeValue(forKey: Self.emailKey)
    }

    public func signOut() {
        for key in Self.legacyKeys {
            keychain.removeValue(forKey: key)
        }
    }

    // MARK: Migration

    /// Move anything the `UserDefaults` sink left behind into the keychain, once, and
    /// delete the plist keys whether or not there was something to move — an install that
    /// never signed in has nothing to copy and still must not keep the keys around.
    private func migrateFromDefaults() {
        for key in Self.legacyKeys {
            defer { defaults.removeObject(forKey: key) }
            guard let legacy = defaults.string(forKey: key), !legacy.isEmpty else { continue }
            // Never overwrite: the keychain survives a delete-and-reinstall and the plist
            // does not, so a value already there is the newer of the two.
            guard keychain.string(forKey: key) == nil else { continue }
            keychain.set(legacy, forKey: key)
        }
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

    public func signOut() {
        appleUserID = nil
        email = nil
    }
}
