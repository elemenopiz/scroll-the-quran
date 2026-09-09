import Foundation
import Observation
import UserState

/// The free tier's daily allowance, as a value.
///
/// The rule the reference app enforces: a free reader may open **three Discover cards a
/// day**; the fourth raises the paywall. "A day" is the local calendar day, so the count
/// resets at midnight rather than 24 hours after the first card. Re-reading a card that
/// was already counted today is free — the limit is on *distinct* cards, not on scrolls.
public struct DiscoverGate: Equatable, Codable, Sendable {
    /// Cards a free reader gets per day.
    public static let freeCardsPerDay = 3

    /// The day `keys` belongs to. A different day means the count starts over.
    public private(set) var day: DayKey
    /// The distinct card keys counted today, in the order they were first seen.
    public private(set) var keys: [String]

    public init(day: DayKey, keys: [String] = []) {
        self.day = day
        self.keys = keys
    }

    /// How many of today's free cards have been used.
    public var used: Int {
        keys.count
    }

    public var remaining: Int {
        max(0, DiscoverGate.freeCardsPerDay - used)
    }

    /// Rolls the day over when `now` is a new calendar day. Idempotent within a day.
    public mutating func roll(to now: Date, calendar: Calendar) {
        let today = DayKey(now, in: calendar)
        guard today != day else { return }
        day = today
        keys.removeAll()
    }

    /// Whether the card may be shown without paying, *without* counting it.
    public func allows(_ key: String, on now: Date, calendar: Calendar) -> Bool {
        var probe = self
        probe.roll(to: now, calendar: calendar)
        return probe.keys.contains(key) || probe.used < DiscoverGate.freeCardsPerDay
    }

    /// Counts a card against today's allowance and reports whether it is allowed.
    /// A card already counted today is allowed again and does not consume a second slot.
    @discardableResult
    public mutating func record(_ key: String, on now: Date, calendar: Calendar) -> Bool {
        roll(to: now, calendar: calendar)
        if keys.contains(key) {
            return true
        }
        guard used < DiscoverGate.freeCardsPerDay else {
            return false
        }
        keys.append(key)
        return true
    }
}

/// Holds the gate across launches.
///
/// `UserState` has no field for this yet and is owned by another task, so the value is
/// kept in `UserDefaults` under one key. The suite is injectable so tests never touch
/// the real defaults.
@MainActor
@Observable
public final class DiscoverGateStore {
    public static let defaultsKey = "discover.gate"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored public var calendar: Calendar
    /// Free readers are gated; a subscriber never is.
    public var isSubscribed: Bool

    public private(set) var gate: DiscoverGate

    public init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: Date = Date(),
        isSubscribed: Bool = false
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.isSubscribed = isSubscribed
        var loaded = DiscoverGateStore.read(from: defaults) ?? DiscoverGate(day: DayKey(now, in: calendar))
        loaded.roll(to: now, calendar: calendar)
        gate = loaded
    }

    public var used: Int {
        gate.used
    }

    public var remaining: Int {
        isSubscribed ? Int.max : gate.remaining
    }

    /// Whether the card is readable right now, without consuming a slot.
    public func allows(_ key: String, on now: Date = Date()) -> Bool {
        isSubscribed || gate.allows(key, on: now, calendar: calendar)
    }

    /// Counts the card. Returns false when the paywall should be raised instead.
    @discardableResult
    public func record(_ key: String, on now: Date = Date()) -> Bool {
        guard !isSubscribed else {
            gate.roll(to: now, calendar: calendar)
            return true
        }
        let allowed = gate.record(key, on: now, calendar: calendar)
        persist()
        return allowed
    }

    /// Test and "delete my data" hook.
    public func reset(on now: Date = Date()) {
        gate = DiscoverGate(day: DayKey(now, in: calendar))
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(gate) else { return }
        defaults.set(data, forKey: DiscoverGateStore.defaultsKey)
    }

    private static func read(from defaults: UserDefaults) -> DiscoverGate? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(DiscoverGate.self, from: data)
    }
}
