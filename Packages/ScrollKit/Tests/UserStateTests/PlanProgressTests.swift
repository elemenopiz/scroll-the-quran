import Foundation
import Testing
@testable import UserState

@Suite("PlanProgress")
struct PlanProgressTests {
    @Test("There is no current day until a plan is started")
    func noPlanNoDay() {
        let plan = PlanProgress()
        #expect(plan.isActive == false)
        #expect(plan.currentDay(now: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc), calendar: Fixture.utc) == nil)
    }

    @Test("Day 1 is the day the plan started, day 3 is two calendar days later")
    func currentDayCountsCalendarDays() {
        var plan = PlanProgress()
        let calendar = Fixture.utc
        plan.start(planID: "juz-a-day", at: Fixture.date(2026, 9, 14, 23, 50, in: calendar))

        #expect(plan.currentDay(now: Fixture.date(2026, 9, 14, 23, 55, in: calendar), calendar: calendar) == 1)
        // Ten minutes later, but a new calendar day: a daily plan moves on.
        #expect(plan.currentDay(now: Fixture.date(2026, 9, 15, 0, 0, in: calendar), calendar: calendar) == 2)
        #expect(plan.currentDay(now: Fixture.date(2026, 9, 16, 12, 0, in: calendar), calendar: calendar) == 3)
    }

    @Test("A clock that moved backwards never produces day zero")
    func currentDayNeverGoesBelowOne() {
        var plan = PlanProgress()
        let calendar = Fixture.utc
        plan.start(planID: "patience", at: Fixture.date(2026, 9, 14, 9, 0, in: calendar))
        #expect(plan.currentDay(now: Fixture.date(2026, 9, 10, 9, 0, in: calendar), calendar: calendar) == 1)
    }

    @Test("Running over the end of a plan clamps to its last day")
    func currentDayClampsToPlanLength() {
        var plan = PlanProgress()
        let calendar = Fixture.utc
        plan.start(planID: "juz-amma", at: Fixture.date(2026, 9, 1, 9, 0, in: calendar))
        let now = Fixture.date(2026, 10, 20, 9, 0, in: calendar)
        #expect(plan.currentDay(now: now, calendar: calendar) == 50)
        #expect(plan.currentDay(now: now, calendar: calendar, lengthDays: 30) == 30)
    }

    @Test("Completing days tracks the next one to read and the plan's progress")
    func completedDaysDriveTheNextDay() {
        var plan = PlanProgress()
        plan.start(planID: "mercy", at: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        #expect(plan.nextIncompleteDay(lengthDays: 3) == 1)
        let completedDayOne = plan.complete(day: 1)
        let completedDayOneAgain = plan.complete(day: 1)
        #expect(completedDayOne)
        #expect(completedDayOneAgain == false)
        #expect(plan.nextIncompleteDay(lengthDays: 3) == 2)
        plan.complete(day: 2)
        plan.complete(day: 3)
        #expect(plan.nextIncompleteDay(lengthDays: 3) == nil)
        #expect(plan.isFinished(lengthDays: 3))
        #expect(plan.completion(lengthDays: 3) == 1)
        let completedDayZero = plan.complete(day: 0)
        #expect(completedDayZero == false)
    }

    @Test("Starting another plan clears the old plan's progress")
    func startingAnotherPlanResetsProgress() {
        var plan = PlanProgress()
        plan.start(planID: "gratitude", at: Fixture.date(2026, 9, 1, 9, 0, in: Fixture.utc))
        plan.complete(day: 1)
        plan.start(planID: "patience", at: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        #expect(plan.activePlanID == "patience")
        #expect(plan.completedDays.isEmpty)

        plan.stop()
        #expect(plan.isActive == false)
        #expect(plan.startedAt == nil)
    }

    @Test("PlanProgress round-trips, and an empty file decodes to no plan")
    func roundTripsThroughJSON() throws {
        var plan = PlanProgress()
        plan.start(planID: "al-kahf-fridays", at: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        plan.complete(day: 2)
        plan.complete(day: 1)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(plan)
        #expect(data.utf8Text.contains(#""completedDays":[1,2]"#))
        #expect(data.utf8Text.contains(#""activePlanId":"al-kahf-fridays""#))
        #expect(try decoder.decode(PlanProgress.self, from: data) == plan)
        #expect(try decoder.decode(PlanProgress.self, from: Data("{}".utf8)) == PlanProgress())
    }
}
