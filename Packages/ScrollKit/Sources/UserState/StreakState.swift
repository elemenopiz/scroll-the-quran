import Foundation

/// One dot in the streak card's Monday-to-Sunday week row.
public struct StreakDay: Hashable, Sendable {
    public let day: DayKey
    /// `"M"`, `"T"`, `"W"`, `"T"`, `"F"`, `"S"`, `"S"` — the letters the card prints under each dot.
    public let letter: String
    /// The app was opened on this day.
    public let isOpened: Bool
    /// This is the day the row was built for.
    public let isToday: Bool
    /// Later this week than today, so it is drawn empty rather than missed.
    public let isFuture: Bool

    public init(day: DayKey, letter: String, isOpened: Bool, isToday: Bool, isFuture: Bool) {
        self.day = day
        self.letter = letter
        self.isOpened = isOpened
        self.isToday = isToday
        self.isFuture = isFuture
    }
}

/// Every day the app was opened, plus the derived current and longest run.
///
/// `current` and `longest` are stored so the widget and Home card can read them without a
/// calendar, but they are always recomputed from `openedDays` on `recordOpen`, so a file that
/// predates them (or was hand-edited) heals itself.
public struct StreakState: Hashable, Codable, Sendable {
    /// Monday-first letters for the week row.
    public static let weekLetters = ["M", "T", "W", "T", "F", "S", "S"]

    public private(set) var openedDays: Set<DayKey>
    public private(set) var current: Int
    public private(set) var longest: Int

    public init(openedDays: Set<DayKey> = [], current: Int = 0, longest: Int = 0) {
        self.openedDays = openedDays
        self.current = current
        self.longest = longest
    }

    /// The most recent day the app was opened.
    public var lastOpenedDay: DayKey? {
        openedDays.max()
    }

    public func hasOpened(on day: DayKey) -> Bool {
        openedDays.contains(day)
    }

    /// Records an app open. Returns true when this was the first open of that day.
    ///
    /// Opening twice in one day is a no-op; opening the next day extends the run; skipping a
    /// day starts a new run of 1 while `longest` keeps the old high-water mark.
    @discardableResult
    public mutating func recordOpen(now: Date, calendar: Calendar) -> Bool {
        let today = DayKey(now, in: calendar)
        let isNewDay = openedDays.insert(today).inserted
        current = Self.runLength(endingAt: today, in: openedDays, calendar: calendar)
        longest = max(longest, Self.longestRun(in: openedDays, calendar: calendar))
        return isNewDay
    }

    /// The streak as of `now` without recording an open: today's run if the app was opened
    /// today, yesterday's run if it has not been opened yet today, otherwise zero.
    public func currentStreak(asOf now: Date, calendar: Calendar) -> Int {
        let today = DayKey(now, in: calendar)
        if openedDays.contains(today) {
            return Self.runLength(endingAt: today, in: openedDays, calendar: calendar)
        }
        let yesterday = today.adding(-1, in: calendar)
        if openedDays.contains(yesterday) {
            return Self.runLength(endingAt: yesterday, in: openedDays, calendar: calendar)
        }
        return 0
    }

    /// Seven dots, Monday through Sunday, for the week containing `now`.
    public func weekRow(now: Date, calendar: Calendar) -> [StreakDay] {
        let today = DayKey(now, in: calendar)
        let weekday = calendar.component(.weekday, from: today.date(in: calendar)) // 1 = Sunday
        let offsetFromMonday = (weekday + 5) % 7
        let monday = today.adding(-offsetFromMonday, in: calendar)
        return (0 ..< 7).map { index in
            let day = monday.adding(index, in: calendar)
            return StreakDay(
                day: day,
                letter: Self.weekLetters[index],
                isOpened: openedDays.contains(day),
                isToday: day == today,
                isFuture: day > today
            )
        }
    }

    /// Drops every recorded day. Used by Settings' "delete my data".
    public mutating func reset() {
        openedDays = []
        current = 0
        longest = 0
    }

    // MARK: Run maths

    static func runLength(endingAt day: DayKey, in days: Set<DayKey>, calendar: Calendar) -> Int {
        guard days.contains(day) else { return 0 }
        var length = 0
        var cursor = day
        while days.contains(cursor) {
            length += 1
            cursor = cursor.adding(-1, in: calendar)
        }
        return length
    }

    static func longestRun(in days: Set<DayKey>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1
        var run = 1
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            if day.isDayAfter(previous, in: calendar) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Codable — tolerant of files written before `current`/`longest` existed.

    private enum CodingKeys: String, CodingKey {
        case openedDays, current, longest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let days = try container.decodeIfPresent(Set<DayKey>.self, forKey: .openedDays) ?? []
        let calendar = Calendar(identifier: .gregorian)
        openedDays = days
        longest = try container.decodeIfPresent(Int.self, forKey: .longest)
            ?? Self.longestRun(in: days, calendar: calendar)
        current = try container.decodeIfPresent(Int.self, forKey: .current)
            ?? days.max().map { Self.runLength(endingAt: $0, in: days, calendar: calendar) } ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(openedDays.sorted(), forKey: .openedDays)
        try container.encode(current, forKey: .current)
        try container.encode(longest, forKey: .longest)
    }
}
