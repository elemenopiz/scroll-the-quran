import Foundation
import QuranData

/// Where the reader was last left: the ayah and, for a long ayah split by `VersePaginator`,
/// which continuation page of it.
public struct ReaderPosition: Hashable, Codable, Sendable {
    public var verse: VerseRef
    /// 0-based continuation page inside the ayah.
    public var page: Int
    public var updatedAt: Date

    public init(verse: VerseRef, page: Int = 0, updatedAt: Date = Date()) {
        self.verse = verse
        self.page = max(0, page)
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case verse, page, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .verse)
        guard let verse = VerseRef(key: key) else {
            throw DecodingError.dataCorruptedError(forKey: .verse, in: container, debugDescription: "Not a verse key: \(key)")
        }
        self.verse = verse
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(verse.key, forKey: .verse)
        try container.encode(page, forKey: .page)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Everything that is a setting rather than content: which translation, how far through
/// onboarding, whether the one-time offer has been shown, the signed-in account, the charity
/// vote, the verse pinned to the widget and where the reader was left.
///
/// Every key decodes with `decodeIfPresent`, so a `prefs.json` written by an older build — or
/// an empty `{}` — migrates forward to the defaults instead of failing to decode.
public struct Prefs: Hashable, Codable, Sendable {
    /// ClearQuran (Talal Itani) is the app's default translation.
    public static let defaultTranslationID = "itani"

    public var translationID: String
    public var onboardingDone: Bool
    /// How far the user got in the onboarding flow (0 = the hook screen).
    public var onboardingStep: Int
    /// The paywall's one-time-offer envelope has been shown once; it never shows again.
    public var seenOneTimeOffer: Bool
    /// True once Sign in with Apple has succeeded.
    ///
    /// A boolean, not the Apple stable user identifier: this file is plaintext JSON in the
    /// App Group container and travels in unencrypted backups, so the identifier lives in the
    /// Keychain instead (audit SEC-1). Settings needs to know *that* the reader is signed in,
    /// not who they are.
    public var isSignedIn: Bool
    /// The address to show in Settings. Apple hands it over on the first sign-in only.
    public var accountEmail: String?
    /// The organisation id the user voted for on the Community tab.
    public var charityVote: String?
    /// The verse pinned to the home-screen widget, if the user pinned one.
    public var widgetVerseRef: VerseRef?
    public var lastReaderPosition: ReaderPosition?

    public init(
        translationID: String = Prefs.defaultTranslationID,
        onboardingDone: Bool = false,
        onboardingStep: Int = 0,
        seenOneTimeOffer: Bool = false,
        isSignedIn: Bool = false,
        accountEmail: String? = nil,
        charityVote: String? = nil,
        widgetVerseRef: VerseRef? = nil,
        lastReaderPosition: ReaderPosition? = nil
    ) {
        self.translationID = translationID
        self.onboardingDone = onboardingDone
        self.onboardingStep = onboardingStep
        self.seenOneTimeOffer = seenOneTimeOffer
        self.isSignedIn = isSignedIn
        self.accountEmail = accountEmail
        self.charityVote = charityVote
        self.widgetVerseRef = widgetVerseRef
        self.lastReaderPosition = lastReaderPosition
    }

    /// True when this value was decoded from a `prefs.json` still carrying the old plaintext
    /// `accountId`. Decoding drops the identifier; `UserStore.load()` watches this so the file
    /// is rewritten once and the identifier actually leaves the disk, rather than surviving
    /// until the reader next happens to change a preference. Never encoded, never decoded.
    public private(set) var carriesLegacyAccountID = false

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case translationID = "translationId"
        case onboardingDone, onboardingStep, seenOneTimeOffer
        /// Read-only: builds before the account split wrote the Apple user identifier here.
        case legacyAccountID = "accountId"
        case isSignedIn
        case accountEmail, charityVote, widgetVerseRef, lastReaderPosition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translationID = try container.decodeIfPresent(String.self, forKey: .translationID) ?? Self.defaultTranslationID
        onboardingDone = try container.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
        onboardingStep = try container.decodeIfPresent(Int.self, forKey: .onboardingStep) ?? 0
        seenOneTimeOffer = try container.decodeIfPresent(Bool.self, forKey: .seenOneTimeOffer) ?? false
        // The one-time account migration: a stored identifier means "signed in", and is then
        // never written back (`encode(to:)` has no `accountId` case at all).
        let legacyAccountID = try container.decodeIfPresent(String.self, forKey: .legacyAccountID)
        carriesLegacyAccountID = legacyAccountID != nil
        isSignedIn = try container.decodeIfPresent(Bool.self, forKey: .isSignedIn)
            ?? (legacyAccountID?.isEmpty == false)
        accountEmail = try container.decodeIfPresent(String.self, forKey: .accountEmail)
        charityVote = try container.decodeIfPresent(String.self, forKey: .charityVote)
        widgetVerseRef = try container.decodeIfPresent(String.self, forKey: .widgetVerseRef).flatMap(VerseRef.init(key:))
        lastReaderPosition = try container.decodeIfPresent(ReaderPosition.self, forKey: .lastReaderPosition)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(translationID, forKey: .translationID)
        try container.encode(onboardingDone, forKey: .onboardingDone)
        try container.encode(onboardingStep, forKey: .onboardingStep)
        try container.encode(seenOneTimeOffer, forKey: .seenOneTimeOffer)
        try container.encode(isSignedIn, forKey: .isSignedIn)
        try container.encodeIfPresent(accountEmail, forKey: .accountEmail)
        try container.encodeIfPresent(charityVote, forKey: .charityVote)
        try container.encodeIfPresent(widgetVerseRef?.key, forKey: .widgetVerseRef)
        try container.encodeIfPresent(lastReaderPosition, forKey: .lastReaderPosition)
    }
}
