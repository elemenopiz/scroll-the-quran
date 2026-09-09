import Foundation
import Testing
@testable import UserState

@Suite("DayKey")
struct DayKeyTests {
    @Test("Round-trips through its yyyy-MM-dd text and JSON form")
    func roundTripsThroughText() throws {
        let day = DayKey(year: 2026, month: 9, day: 14)
        #expect(day.text == "2026-09-14")
        #expect(DayKey(text: "2026-09-14") == day)

        let data = try JSONEncoder().encode([day])
        #expect(data.utf8Text == "[\"2026-09-14\"]")
        #expect(try JSONDecoder().decode([DayKey].self, from: data) == [day])
    }

    @Test("Rejects text that is not a day key, and fails to decode it")
    func rejectsMalformedText() {
        #expect(DayKey(text: "2026-9-14") == nil)
        #expect(DayKey(text: "14/09/2026") == nil)
        #expect(DayKey(text: "2026-13-01") == nil)
        #expect(DayKey(text: "") == nil)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(DayKey.self, from: Data("\"yesterday\"".utf8))
        }
    }

    @Test("Orders and counts days across a month boundary")
    func ordersAcrossMonthBoundary() {
        let calendar = Fixture.utc
        let last = DayKey(year: 2026, month: 8, day: 31)
        let first = DayKey(year: 2026, month: 9, day: 1)
        #expect(last < first)
        #expect(first.isDayAfter(last, in: calendar))
        #expect(first.days(since: last, in: calendar) == 1)
        #expect(last.days(since: first, in: calendar) == -1)
        #expect(last.adding(1, in: calendar) == first)
        #expect(first.adding(-1, in: calendar) == last)
    }

    @Test("Adds whole days, not 86,400 seconds, across a spring-forward night")
    func addsDaysAcrossDaylightSavingGap() {
        // 2026-03-08 loses an hour in New York at 02:00.
        let calendar = Fixture.newYork
        let before = DayKey(year: 2026, month: 3, day: 8)
        let after = before.adding(1, in: calendar)
        #expect(after == DayKey(year: 2026, month: 3, day: 9))
        #expect(after.days(since: before, in: calendar) == 1)

        let elapsed = after.date(in: calendar).timeIntervalSince(before.date(in: calendar))
        #expect(elapsed == 23 * 3600, "8 March is a 23-hour day in New York, which is why day maths cannot use seconds")
    }

    @Test("The same instant is a different day in different timezones")
    func sameInstantDiffersByTimeZone() {
        let instant = Fixture.date(2026, 9, 14, 22, 0, in: Fixture.utc)
        #expect(DayKey(instant, in: Fixture.tokyo) == DayKey(year: 2026, month: 9, day: 15))
        #expect(DayKey(instant, in: Fixture.losAngeles) == DayKey(year: 2026, month: 9, day: 14))
    }
}
