import Foundation
import Testing
@testable import UserState

@Suite("StreakState")
struct StreakStateTests {
    @Test("The first open of all starts a streak of one")
    func firstOpenStartsStreak() {
        var streak = StreakState()
        let calendar = Fixture.utc
        let isFirstOpenOfTheDay = streak.recordOpen(now: Fixture.date(2026, 9, 14, 9, 0, in: calendar), calendar: calendar)
        #expect(isFirstOpenOfTheDay)
        #expect(streak.current == 1)
        #expect(streak.longest == 1)
        #expect(streak.lastOpenedDay == DayKey(year: 2026, month: 9, day: 14))
    }

    @Test("Opening twice in one day does not increment anything")
    func sameDayDoubleOpenIsANoOp() {
        var streak = StreakState()
        let calendar = Fixture.utc
        streak.recordOpen(now: Fixture.date(2026, 9, 14, 0, 1, in: calendar), calendar: calendar)
        let secondOpenIsNewDay = streak.recordOpen(now: Fixture.date(2026, 9, 14, 23, 59, in: calendar), calendar: calendar)
        #expect(secondOpenIsNewDay == false)
        #expect(streak.current == 1)
        #expect(streak.openedDays.count == 1)
    }

    @Test("Crossing midnight extends the streak")
    func crossingMidnightExtendsTheStreak() {
        var streak = StreakState()
        let calendar = Fixture.utc
        streak.recordOpen(now: Fixture.date(2026, 9, 14, 23, 58, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2026, 9, 15, 0, 3, in: calendar), calendar: calendar)
        #expect(streak.current == 2)
        #expect(streak.longest == 2)
    }

    @Test("A missed day resets the current streak but keeps the longest")
    func missedDayResetsCurrentAndKeepsLongest() {
        var streak = StreakState()
        let calendar = Fixture.utc
        for day in 10 ... 13 {
            streak.recordOpen(now: Fixture.date(2026, 9, day, 8, 0, in: calendar), calendar: calendar)
        }
        #expect(streak.current == 4)
        // Nothing on the 14th.
        streak.recordOpen(now: Fixture.date(2026, 9, 15, 8, 0, in: calendar), calendar: calendar)
        #expect(streak.current == 1)
        #expect(streak.longest == 4)
    }

    @Test("currentStreak(asOf:) survives today, holds yesterday, and drops after that")
    func currentStreakDecaysWithoutRecording() {
        var streak = StreakState()
        let calendar = Fixture.utc
        streak.recordOpen(now: Fixture.date(2026, 9, 13, 8, 0, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: calendar), calendar: calendar)

        #expect(streak.currentStreak(asOf: Fixture.date(2026, 9, 14, 22, 0, in: calendar), calendar: calendar) == 2)
        #expect(streak.currentStreak(asOf: Fixture.date(2026, 9, 15, 9, 0, in: calendar), calendar: calendar) == 2)
        #expect(streak.currentStreak(asOf: Fixture.date(2026, 9, 16, 9, 0, in: calendar), calendar: calendar) == 0)
    }

    @Test("A clock that falls back an hour still counts one day, then the next")
    func daylightSavingFallBackKeepsDaysDistinct() {
        // New York gains an hour on 2025-11-02: 01:30 happens twice.
        var streak = StreakState()
        let calendar = Fixture.newYork
        streak.recordOpen(now: Fixture.date(2025, 11, 1, 23, 30, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2025, 11, 2, 1, 30, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2025, 11, 2, 23, 30, in: calendar), calendar: calendar)
        #expect(streak.openedDays.count == 2)
        #expect(streak.current == 2)
    }

    @Test("A clock that springs forward an hour still counts consecutive days")
    func daylightSavingSpringForwardKeepsTheStreak() {
        // New York loses an hour on 2026-03-08 at 02:00.
        var streak = StreakState()
        let calendar = Fixture.newYork
        streak.recordOpen(now: Fixture.date(2026, 3, 7, 23, 0, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2026, 3, 8, 3, 30, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2026, 3, 9, 0, 30, in: calendar), calendar: calendar)
        #expect(streak.openedDays.sorted().map(\.text) == ["2026-03-07", "2026-03-08", "2026-03-09"])
        #expect(streak.current == 3)
    }

    @Test("Flying east and opening the app the same local day does not double-count")
    func timeZoneChangeOnTheSameLocalDay() {
        var streak = StreakState()
        // 08:00 in Tokyo on the 15th.
        streak.recordOpen(now: Fixture.date(2026, 9, 15, 8, 0, in: Fixture.tokyo), calendar: Fixture.tokyo)
        // The same calendar day in Los Angeles, sixteen hours behind.
        streak.recordOpen(now: Fixture.date(2026, 9, 15, 9, 0, in: Fixture.losAngeles), calendar: Fixture.losAngeles)
        #expect(streak.openedDays.count == 1)
        #expect(streak.current == 1)
    }

    @Test("Flying east and opening the app the next local day extends the streak")
    func timeZoneChangeOnTheNextLocalDay() {
        var streak = StreakState()
        streak.recordOpen(now: Fixture.date(2026, 9, 15, 8, 0, in: Fixture.tokyo), calendar: Fixture.tokyo)
        streak.recordOpen(now: Fixture.date(2026, 9, 16, 9, 0, in: Fixture.losAngeles), calendar: Fixture.losAngeles)
        #expect(streak.openedDays.count == 2)
        #expect(streak.current == 2)
    }

    @Test("The week row is seven dots, Monday to Sunday, with today marked")
    func weekRowIsSevenDotsMondayFirst() {
        var streak = StreakState()
        let calendar = Fixture.utc
        // 2026-09-14 is a Monday.
        streak.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: calendar), calendar: calendar)
        streak.recordOpen(now: Fixture.date(2026, 9, 16, 8, 0, in: calendar), calendar: calendar)

        let row = streak.weekRow(now: Fixture.date(2026, 9, 16, 20, 0, in: calendar), calendar: calendar)
        #expect(row.count == 7)
        #expect(row.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(row.first?.day == DayKey(year: 2026, month: 9, day: 14))
        #expect(row.last?.day == DayKey(year: 2026, month: 9, day: 20))
        #expect(row.map(\.isOpened) == [true, false, true, false, false, false, false])
        #expect(row.map(\.isToday) == [false, false, true, false, false, false, false])
        #expect(row.map(\.isFuture) == [false, false, false, true, true, true, true])
    }

    @Test("The week row is the week around today, not the last seven days")
    func weekRowOnlyShowsTheCurrentWeek() {
        var streak = StreakState()
        let calendar = Fixture.utc
        // The Sunday before the week under test.
        streak.recordOpen(now: Fixture.date(2026, 9, 13, 8, 0, in: calendar), calendar: calendar)
        let row = streak.weekRow(now: Fixture.date(2026, 9, 14, 8, 0, in: calendar), calendar: calendar)
        #expect(row.allSatisfy { $0.isOpened == false })
        #expect(row[0].isToday)
    }

    @Test("Decoding a file written before current/longest existed recomputes them")
    func decodingWithMissingCountsRecomputesThem() throws {
        let json = Data(#"{"openedDays":["2026-09-12","2026-09-13","2026-09-14"]}"#.utf8)
        let streak = try JSONDecoder().decode(StreakState.self, from: json)
        #expect(streak.openedDays.count == 3)
        #expect(streak.current == 3)
        #expect(streak.longest == 3)
    }

    @Test("StreakState round-trips through JSON with its days sorted")
    func roundTripsThroughJSON() throws {
        var streak = StreakState()
        let calendar = Fixture.utc
        for day in [14, 12, 13] {
            streak.recordOpen(now: Fixture.date(2026, 9, day, 8, 0, in: calendar), calendar: calendar)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(streak)
        #expect(data.utf8Text
            .contains(#""openedDays":["2026-09-12","2026-09-13","2026-09-14"]"#))
        #expect(try JSONDecoder().decode(StreakState.self, from: data) == streak)
    }

    @Test("Deleting the user's data clears every recorded day")
    func resetClearsEverything() {
        var streak = StreakState()
        let calendar = Fixture.utc
        streak.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: calendar), calendar: calendar)
        streak.reset()
        #expect(streak.openedDays.isEmpty)
        #expect(streak.current == 0)
        #expect(streak.longest == 0)
    }
}
