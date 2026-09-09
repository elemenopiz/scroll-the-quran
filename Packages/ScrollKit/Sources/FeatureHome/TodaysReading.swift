import Foundation
import QuranData

/// What the Home "Today's Reading" card shows once a plan is running.
///
/// Resolution is a pure function of the catalog, the stored plan progress and "now", so the
/// card is testable without a store, a clock or a view: `resolve(...)` returns nil when there
/// is no active plan (Home then draws the "Pick a plan to begin" state) and clamps the day to
/// the plan's length, so a plan left running for a year still points at its last day.
public struct TodaysReading: Hashable, Sendable {
    public let plan: ReadingPlan
    /// 1-based, clamped to `plan.lengthDays`.
    public let dayNumber: Int
    public let day: ReadingPlanDay?
    /// True once every day of the plan has been marked complete.
    public let isFinished: Bool

    public init(plan: ReadingPlan, dayNumber: Int, day: ReadingPlanDay?, isFinished: Bool = false) {
        self.plan = plan
        self.dayNumber = dayNumber
        self.day = day
        self.isFinished = isFinished
    }

    /// `"Day 4 of 31"`.
    public var dayLabel: String {
        "Day \(dayNumber) of \(plan.lengthDays)"
    }

    /// The passage keys for today, or an empty array when the schedule has no entry.
    public var refs: [String] {
        day?.refs ?? []
    }

    public var passages: [PassageRef] {
        day?.passages ?? []
    }

    /// The reference line: surah names when an index is given, raw keys otherwise.
    public func refsLine(using index: SurahIndex?) -> String {
        guard let day else { return "" }
        guard let index else { return day.refsLine }
        return day.refsLine(using: index)
    }

    /// How far through the plan the reader is, 0...1. Day 1 of 30 is 1/30, not 0.
    public var completion: Double {
        guard plan.lengthDays > 0 else { return 0 }
        return min(1, Double(dayNumber) / Double(plan.lengthDays))
    }

    /// Resolves the card's content. `startedAt` is the day the plan began; the plan day is a
    /// calendar-day count from it, matching `UserState.PlanProgress.currentDay`.
    public static func resolve(
        catalog: ReadingPlanCatalog,
        activePlanID: String?,
        startedAt: Date?,
        completedDays: Set<Int> = [],
        now: Date,
        calendar: Calendar
    ) -> TodaysReading? {
        guard let activePlanID, let plan = catalog.plan(activePlanID), let startedAt else { return nil }
        let elapsed = dayCount(from: startedAt, to: now, calendar: calendar)
        let raw = max(1, elapsed + 1)
        let dayNumber = plan.lengthDays > 0 ? min(raw, plan.lengthDays) : raw
        let finished = plan.lengthDays > 0
            && (1 ... plan.lengthDays).allSatisfy(completedDays.contains)
        return TodaysReading(
            plan: plan,
            dayNumber: dayNumber,
            day: plan.day(dayNumber),
            isFinished: finished
        )
    }

    /// Whole calendar days between two instants, never negative-rounded by a clock change
    /// inside a day: both are reduced to their start-of-day first.
    static func dayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
