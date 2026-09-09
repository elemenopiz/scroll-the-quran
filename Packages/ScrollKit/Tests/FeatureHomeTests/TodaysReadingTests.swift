@testable import FeatureHome
import Foundation
import Testing

@Suite("Today's reading")
struct TodaysReadingTests {
    private let catalog = HomeTestContent.fixtureCatalog()
    private let calendar = HomeTestContent.calendar

    private func resolve(started: String, now: String, completed: Set<Int> = []) -> TodaysReading? {
        TodaysReading.resolve(
            catalog: catalog,
            activePlanID: "three-day",
            startedAt: HomeTestContent.date(started),
            completedDays: completed,
            now: HomeTestContent.date(now),
            calendar: calendar
        )
    }

    @Test("no active plan resolves to nothing, so Home draws the empty state")
    func noPlan() {
        let none = TodaysReading.resolve(
            catalog: catalog,
            activePlanID: nil,
            startedAt: HomeTestContent.date("2026-09-14"),
            now: HomeTestContent.date("2026-09-14"),
            calendar: calendar
        )
        #expect(none == nil)
    }

    @Test("a plan id that is not in the catalog resolves to nothing")
    func unknownPlan() {
        let none = TodaysReading.resolve(
            catalog: catalog,
            activePlanID: "deleted-plan",
            startedAt: HomeTestContent.date("2026-09-14"),
            now: HomeTestContent.date("2026-09-14"),
            calendar: calendar
        )
        #expect(none == nil)
    }

    @Test("the day it starts is day 1")
    func startDayIsOne() throws {
        let today = try #require(resolve(started: "2026-09-14 08:00", now: "2026-09-14 23:00"))
        #expect(today.dayNumber == 1)
        #expect(today.dayLabel == "Day 1 of 3")
        #expect(today.refs == ["1:1-7"])
    }

    @Test("ten minutes past midnight is the next calendar day, not 'still day 1'")
    func calendarDayNotElapsedHours() throws {
        let today = try #require(resolve(started: "2026-09-14 23:50", now: "2026-09-15 00:00"))
        #expect(today.dayNumber == 2)
        #expect(today.refs == ["2:255"])
    }

    @Test("a plan left running past its end clamps to the last day")
    func clampsToLastDay() throws {
        let today = try #require(resolve(started: "2026-09-14", now: "2026-12-25"))
        #expect(today.dayNumber == 3)
        #expect(today.dayLabel == "Day 3 of 3")
        #expect(today.refs == ["112:1-4", "113:1-5"])
    }

    @Test("a clock that moved backwards never produces day 0")
    func neverBeforeDayOne() throws {
        let today = try #require(resolve(started: "2026-09-14", now: "2026-09-01"))
        #expect(today.dayNumber == 1)
    }

    @Test("completion is day over length, so day 1 of 3 is a third of the bar")
    func completionFraction() throws {
        #expect(try #require(resolve(started: "2026-09-14", now: "2026-09-14")).completion == 1.0 / 3.0)
        #expect(try #require(resolve(started: "2026-09-14", now: "2026-09-16")).completion == 1.0)
    }

    @Test("isFinished only once every day is marked complete")
    func finishedFlag() throws {
        #expect(try #require(resolve(started: "2026-09-14", now: "2026-09-16", completed: [1, 2])).isFinished == false)
        #expect(try #require(resolve(started: "2026-09-14", now: "2026-09-16", completed: [1, 2, 3])).isFinished)
    }

    @Test("the refs line falls back to raw keys without a surah index")
    func refsLineFallback() throws {
        let today = try #require(resolve(started: "2026-09-14", now: "2026-09-16"))
        #expect(today.refsLine(using: nil) == "112:1-4 · 113:1-5")
        let index = try HomeTestContent.surahIndex()
        #expect(try today.refsLine(using: index).contains(#require(index.surah(112)?.name)))
    }
}
