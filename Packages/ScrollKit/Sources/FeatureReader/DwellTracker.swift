import Foundation

/// Decides when a page has been *read* rather than merely scrolled past: the reader marks an
/// ayah read once it has been on screen, still, for 1.2 s.
///
/// Deliberately clock-free — every method takes "now" — so the rule is testable without
/// timers, and the view only has to call `arrived(at:)` when the page changes and `settle(at:)`
/// when its dwell task fires.
public struct DwellTracker: Equatable, Sendable {
    /// How long a page must hold still before it counts as read.
    public static let threshold: TimeInterval = 1.2

    private let threshold: TimeInterval
    /// The page currently being timed, if any.
    public private(set) var pending: ReaderPageID?
    /// When the current page arrived.
    public private(set) var arrivedAt: Date?
    /// Pages already reported. A page is reported once per reader session; scrolling back to
    /// it does not report it again, so the store is not asked to re-mark what it already has.
    public private(set) var settled: Set<ReaderPageID> = []

    public init(threshold: TimeInterval = DwellTracker.threshold) {
        self.threshold = threshold
    }

    /// The reader landed on a page. Passing the page it is already timing is a no-op, so a
    /// redundant `onChange` does not restart the clock.
    public mutating func arrived(at page: ReaderPageID?, now: Date) {
        guard page != pending else { return }
        pending = page
        arrivedAt = page == nil ? nil : now
    }

    /// True once the pending page has been still for long enough.
    public func hasElapsed(now: Date) -> Bool {
        guard pending != nil, let arrivedAt else { return false }
        return now.timeIntervalSince(arrivedAt) >= threshold
    }

    /// How much longer the pending page needs, in seconds. Zero when it is already there.
    public func remaining(now: Date) -> TimeInterval {
        guard pending != nil, let arrivedAt else { return threshold }
        return max(0, threshold - now.timeIntervalSince(arrivedAt))
    }

    /// The page to mark read, or nil when the dwell is not up yet or has already been
    /// reported. Reporting is idempotent: the same page is only ever returned once.
    public mutating func settle(now: Date) -> ReaderPageID? {
        guard let pending, hasElapsed(now: now), !settled.contains(pending) else { return nil }
        settled.insert(pending)
        return pending
    }

    /// Forgets what has been reported — used when the reader moves to another surah.
    public mutating func reset() {
        pending = nil
        arrivedAt = nil
        settled.removeAll()
    }
}
