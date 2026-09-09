@testable import FeatureReader
import Foundation
import Testing

@Suite("Dwell: an ayah is read after 1.2 s on screen")
struct DwellTrackerTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let page = ReaderPageID(surah: 2, ayah: 5)

    @Test("the threshold is the specified 1.2 s")
    func thresholdIsSpecified() {
        #expect(DwellTracker.threshold == 1.2)
    }

    @Test("a page settles only once it has been still for the whole threshold")
    func settlesAfterTheThreshold() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        #expect(!tracker.hasElapsed(now: Self.start.addingTimeInterval(1.19)))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(1.19)) == nil)
        #expect(tracker.hasElapsed(now: Self.start.addingTimeInterval(1.2)))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(1.2)) == Self.page)
    }

    @Test("scrolling past a page before the threshold never marks it")
    func scrollingPastDoesNotMark() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        tracker.arrived(at: ReaderPageID(surah: 2, ayah: 6), now: Self.start.addingTimeInterval(0.3))
        // The clock restarted, so 1.0 s after arriving at ayah 5 nothing has settled.
        #expect(tracker.settle(now: Self.start.addingTimeInterval(1.0)) == nil)
        #expect(tracker.settle(now: Self.start.addingTimeInterval(1.6)) == ReaderPageID(surah: 2, ayah: 6))
    }

    @Test("a page is reported once, however often the dwell task fires")
    func reportsOnce() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        #expect(tracker.settle(now: Self.start.addingTimeInterval(2)) == Self.page)
        #expect(tracker.settle(now: Self.start.addingTimeInterval(3)) == nil)
        // Scrolling away and back does not re-report it either.
        tracker.arrived(at: ReaderPageID(surah: 2, ayah: 6), now: Self.start.addingTimeInterval(4))
        tracker.arrived(at: Self.page, now: Self.start.addingTimeInterval(5))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(9)) == nil)
    }

    @Test("re-arriving at the page already being timed does not restart the clock")
    func redundantArrivalIsIgnored() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        tracker.arrived(at: Self.page, now: Self.start.addingTimeInterval(1.0))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(1.2)) == Self.page)
    }

    @Test("remaining counts down and floors at zero")
    func remainingCountsDown() {
        var tracker = DwellTracker()
        #expect(tracker.remaining(now: Self.start) == DwellTracker.threshold)
        tracker.arrived(at: Self.page, now: Self.start)
        #expect(abs(tracker.remaining(now: Self.start.addingTimeInterval(0.2)) - 1.0) < 0.0001)
        #expect(tracker.remaining(now: Self.start.addingTimeInterval(5)) == 0)
    }

    @Test("reset forgets both the pending page and everything reported")
    func resetClearsEverything() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        _ = tracker.settle(now: Self.start.addingTimeInterval(2))
        tracker.reset()
        #expect(tracker.pending == nil)
        tracker.arrived(at: Self.page, now: Self.start.addingTimeInterval(3))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(5)) == Self.page)
    }

    @Test("moving to no page stops the clock")
    func nilPageStopsTheClock() {
        var tracker = DwellTracker()
        tracker.arrived(at: Self.page, now: Self.start)
        tracker.arrived(at: nil, now: Self.start.addingTimeInterval(0.1))
        #expect(!tracker.hasElapsed(now: Self.start.addingTimeInterval(10)))
        #expect(tracker.settle(now: Self.start.addingTimeInterval(10)) == nil)
    }
}
