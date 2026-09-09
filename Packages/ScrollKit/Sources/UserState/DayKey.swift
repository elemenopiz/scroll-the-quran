import Foundation

/// One local calendar day, stored as `"2026-09-14"`.
///
/// Streaks, plans and the week row all reason in whole days, never in seconds: a `DayKey`
/// is derived from an instant *and a calendar*, so a device that changes timezone or crosses
/// a daylight-saving boundary still gets exactly one key per day it was actually used.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The local day `date` falls in, according to `calendar` (which carries the timezone).
    public init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses `"2026-09-14"`. Returns nil for anything else.
    public init?(text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1 ... 12).contains(month), (1 ... 31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// `"2026-09-14"`.
    public var text: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String {
        text
    }

    /// Midnight (or the first representable instant) of this day in `calendar`.
    public func date(in calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        if let exact = calendar.date(from: parts) {
            return calendar.startOfDay(for: exact)
        }
        // Timezones whose DST gap swallows midnight: ask for noon and walk back.
        parts.hour = 12
        if let noon = calendar.date(from: parts) {
            return calendar.startOfDay(for: noon)
        }
        return Date(timeIntervalSince1970: 0)
    }

    /// The day `days` calendar days away. DST-safe: it adds days, never 86,400 seconds.
    public func adding(_ days: Int, in calendar: Calendar) -> DayKey {
        guard days != 0 else { return self }
        guard let moved = calendar.date(byAdding: .day, value: days, to: date(in: calendar)) else { return self }
        return DayKey(moved, in: calendar)
    }

    /// Whole calendar days from `other` to `self` (negative when `self` is earlier).
    public func days(since other: DayKey, in calendar: Calendar) -> Int {
        let from = other.date(in: calendar)
        let to = date(in: calendar)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// True when `self` is exactly the day after `other`.
    public func isDayAfter(_ other: DayKey, in calendar: Calendar) -> Bool {
        other.adding(1, in: calendar) == self
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Codable — a single `"2026-09-14"` string, so sets of days read well in JSON.

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let parsed = DayKey(text: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd day key: \(text)")
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}
