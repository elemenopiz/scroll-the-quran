import Foundation

/// The reading plan the user is on, if any.
///
/// A plan's "day" is a calendar day count from the day it was started, not an elapsed-hours
/// count: starting a plan at 23:50 and opening it ten minutes later puts you on day 2, which
/// is what a reader expects from something called a daily plan.
public struct PlanProgress: Hashable, Codable, Sendable {
    public private(set) var activePlanID: String?
    public private(set) var startedAt: Date?
    public private(set) var completedDays: Set<Int>

    public init(activePlanID: String? = nil, startedAt: Date? = nil, completedDays: Set<Int> = []) {
        self.activePlanID = activePlanID
        self.startedAt = startedAt
        self.completedDays = completedDays
    }

    public var isActive: Bool {
        activePlanID != nil
    }

    /// Starts (or restarts) a plan, clearing any previous progress.
    public mutating func start(planID: String, at date: Date) {
        activePlanID = planID
        startedAt = date
        completedDays = []
    }

    /// Leaves the plan and forgets its progress.
    public mutating func stop() {
        activePlanID = nil
        startedAt = nil
        completedDays = []
    }

    /// Which day of the plan today is: 1 on the day it was started, 2 the next calendar day.
    /// Nil when no plan is active. Never less than 1, even if the clock moved backwards.
    public func currentDay(now: Date, calendar: Calendar) -> Int? {
        guard activePlanID != nil, let startedAt else { return nil }
        let start = DayKey(startedAt, in: calendar)
        let today = DayKey(now, in: calendar)
        return max(1, today.days(since: start, in: calendar) + 1)
    }

    /// `currentDay` clamped to the plan's length, so a plan that ran over still points at its
    /// last day rather than off the end of the schedule.
    public func currentDay(now: Date, calendar: Calendar, lengthDays: Int) -> Int? {
        guard let day = currentDay(now: now, calendar: calendar) else { return nil }
        guard lengthDays > 0 else { return day }
        return min(day, lengthDays)
    }

    public func isCompleted(day: Int) -> Bool {
        completedDays.contains(day)
    }

    @discardableResult
    public mutating func complete(day: Int) -> Bool {
        guard day >= 1 else { return false }
        return completedDays.insert(day).inserted
    }

    @discardableResult
    public mutating func uncomplete(day: Int) -> Bool {
        completedDays.remove(day) != nil
    }

    /// The first unfinished day, or nil once the whole plan is done.
    public func nextIncompleteDay(lengthDays: Int) -> Int? {
        guard lengthDays > 0 else { return nil }
        return (1 ... lengthDays).first { !completedDays.contains($0) }
    }

    /// 0...1 across the whole plan.
    public func completion(lengthDays: Int) -> Double {
        guard lengthDays > 0 else { return 0 }
        let done = completedDays.filter { (1 ... lengthDays).contains($0) }.count
        return Double(done) / Double(lengthDays)
    }

    public func isFinished(lengthDays: Int) -> Bool {
        lengthDays > 0 && nextIncompleteDay(lengthDays: lengthDays) == nil
    }

    public mutating func reset() {
        stop()
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case activePlanID = "activePlanId", startedAt, completedDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activePlanID = try container.decodeIfPresent(String.self, forKey: .activePlanID)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedDays = try container.decodeIfPresent(Set<Int>.self, forKey: .completedDays) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(activePlanID, forKey: .activePlanID)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encode(completedDays.sorted(), forKey: .completedDays)
    }
}
