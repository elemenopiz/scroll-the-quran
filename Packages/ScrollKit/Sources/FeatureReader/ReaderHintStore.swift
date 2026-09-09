import Foundation

/// Whether the reader's "Tap or slide" coaching toast has been dismissed. It shows once, ever.
///
/// `UserState.Prefs` has no key for this and `UserState` is not this task's to change, so the
/// flag lives in `UserDefaults` behind a protocol. Moving it into `Prefs` later is a matter of
/// writing another conformance — nothing else in the reader knows where the flag is kept.
@MainActor
public protocol ReaderHintStore: AnyObject {
    var hasSeenRailHint: Bool { get }
    func markRailHintSeen()
}

/// The shipping implementation.
@MainActor
public final class UserDefaultsReaderHintStore: ReaderHintStore {
    public static let railHintKey = "com.scrollthequran.reader.railHintSeen"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasSeenRailHint: Bool {
        defaults.bool(forKey: Self.railHintKey)
    }

    public func markRailHintSeen() {
        defaults.set(true, forKey: Self.railHintKey)
    }
}

/// An in-memory store: previews, tests, and the `--screenshot` runs, which must always show
/// the toast because the reference capture has it on screen.
@MainActor
public final class EphemeralReaderHintStore: ReaderHintStore {
    public private(set) var hasSeenRailHint: Bool

    public init(hasSeenRailHint: Bool = false) {
        self.hasSeenRailHint = hasSeenRailHint
    }

    public func markRailHintSeen() {
        hasSeenRailHint = true
    }
}
