@testable import FeatureDiscover
import Foundation
import Testing
import UserState

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: text)!
}

@Suite("Discover free-tier gate")
struct DiscoverGateTests {
    @Test("Three distinct cards are free, the fourth is not")
    func threeFreeCards() {
        let now = date("2026-09-14 09:00")
        var gate = DiscoverGate(day: DayKey(now, in: utc))

        let first = gate.record("112:1-4", on: now, calendar: utc)
        let second = gate.record("103:1-3", on: now, calendar: utc)
        let third = gate.record("1:5-7", on: now, calendar: utc)
        #expect(first && second && third)
        #expect(gate.used == 3)
        #expect(gate.remaining == 0)
        let fourth = gate.record("1:1", on: now, calendar: utc)
        #expect(fourth == false)
        #expect(gate.used == 3, "a blocked card must not consume a slot")
    }

    @Test("Re-reading a card already counted today is free")
    func revisitIsFree() {
        let now = date("2026-09-14 09:00")
        var gate = DiscoverGate(day: DayKey(now, in: utc))
        gate.record("112:1-4", on: now, calendar: utc)
        gate.record("103:1-3", on: now, calendar: utc)
        gate.record("1:5-7", on: now, calendar: utc)

        let revisit = gate.record("103:1-3", on: now, calendar: utc)
        #expect(revisit)
        #expect(gate.used == 3)
        #expect(gate.allows("103:1-3", on: now, calendar: utc))
        #expect(gate.allows("2:255", on: now, calendar: utc) == false)
    }

    @Test("The count resets at midnight, not 24 hours after the first card")
    func resetsAtMidnight() {
        let evening = date("2026-09-14 23:50")
        var gate = DiscoverGate(day: DayKey(evening, in: utc))
        gate.record("112:1-4", on: evening, calendar: utc)
        gate.record("103:1-3", on: evening, calendar: utc)
        gate.record("1:5-7", on: evening, calendar: utc)
        let blocked = gate.record("1:1", on: evening, calendar: utc)
        #expect(blocked == false)

        // Twenty minutes later, but a new calendar day.
        let afterMidnight = date("2026-09-15 00:10")
        let allowedTomorrow = gate.record("1:1", on: afterMidnight, calendar: utc)
        #expect(allowedTomorrow)
        #expect(gate.used == 1)
        #expect(gate.remaining == DiscoverGate.freeCardsPerDay - 1)
        #expect(gate.day == DayKey(afterMidnight, in: utc))
    }

    @Test("allows() never mutates the gate")
    func allowsIsPure() {
        let now = date("2026-09-14 09:00")
        let tomorrow = date("2026-09-15 09:00")
        var gate = DiscoverGate(day: DayKey(now, in: utc))
        gate.record("112:1-4", on: now, calendar: utc)
        let before = gate

        _ = gate.allows("2:255", on: tomorrow, calendar: utc)
        #expect(gate == before)
    }

    @Test("A gate survives a round trip through JSON")
    func codableRoundTrip() throws {
        let now = date("2026-09-14 09:00")
        var gate = DiscoverGate(day: DayKey(now, in: utc))
        gate.record("112:1-4", on: now, calendar: utc)

        let data = try JSONEncoder().encode(gate)
        let decoded = try JSONDecoder().decode(DiscoverGate.self, from: data)
        #expect(decoded == gate)
    }
}

@Suite("Discover gate store", .serialized)
@MainActor
struct DiscoverGateStoreTests {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("A free reader is stopped after three cards; a subscriber is not")
    func subscriberBypassesTheGate() {
        let now = date("2026-09-14 09:00")
        let store = DiscoverGateStore(
            defaults: freshDefaults("gate.free"),
            calendar: utc,
            now: now
        )
        #expect([store.record("a", on: now), store.record("b", on: now), store.record("c", on: now)]
            .allSatisfy { $0 })
        #expect(store.record("d", on: now) == false)

        store.isSubscribed = true
        #expect(store.record("d", on: now))
        #expect(store.remaining == Int.max)
    }

    @Test("The count persists across launches and still rolls over at midnight")
    func persistsAndRolls() {
        let defaults = freshDefaults("gate.persist")
        let now = date("2026-09-14 09:00")
        let first = DiscoverGateStore(defaults: defaults, calendar: utc, now: now)
        first.record("a", on: now)
        first.record("b", on: now)

        let relaunchSameDay = DiscoverGateStore(defaults: defaults, calendar: utc, now: now)
        #expect(relaunchSameDay.used == 2)
        #expect(relaunchSameDay.record("c", on: now))
        #expect(relaunchSameDay.record("d", on: now) == false)

        let tomorrow = date("2026-09-15 07:00")
        let relaunchNextDay = DiscoverGateStore(defaults: defaults, calendar: utc, now: tomorrow)
        #expect(relaunchNextDay.used == 0)
        #expect(relaunchNextDay.record("d", on: tomorrow))
    }
}
