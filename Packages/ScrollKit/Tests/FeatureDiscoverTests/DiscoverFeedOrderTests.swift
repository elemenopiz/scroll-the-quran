@testable import FeatureDiscover
import Foundation
import QuranData
import StudyContent
import Testing

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func day(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: text)!
}

private let feed = DiscoverFeed(items: [
    DiscoverItem(key: "112:1-4", themeId: "tawhid", weight: 100),
    DiscoverItem(key: "103:1-3", themeId: "time", weight: 98),
    DiscoverItem(key: "1:5-7", themeId: "guidance", weight: 95),
    DiscoverItem(key: "1:1", themeId: "names-of-god", weight: 90),
    DiscoverItem(key: "1:2-4", themeId: "praise", weight: 85),
])

@Suite("Discover feed order")
struct DiscoverFeedOrderTests {
    @Test("The same seed always replays the same order")
    func sameSeedSameOrder() {
        let first = feed.keys(seed: 257)
        let second = feed.keys(seed: 257)
        #expect(first == second)
        #expect(Set(first) == Set(feed.items.map(\.key)), "the shuffle is a permutation, not a filter")
    }

    @Test("The seed is the day of the year, so the order changes between days")
    func seedIsDayOfYear() {
        let today = day("2026-09-14")
        let tomorrow = day("2026-09-15")
        let seedToday = utc.ordinality(of: .day, in: .year, for: today)
        #expect(seedToday == 257)
        #expect(feed.items(on: today, calendar: utc).map(\.key) == feed.keys(seed: 257))
        #expect(feed.items(on: tomorrow, calendar: utc).map(\.key) == feed.keys(seed: 258))
    }

    @Test("The pinned snapshot date always produces the same first card")
    func snapshotDateIsStable() {
        // SCROLL_FIXED_DATE in Tools/snapshot/capture.sh. If this ever changes, every
        // `discover-*` capture changes with it, so it is pinned here on purpose.
        let keys = feed.items(on: day("2026-09-14"), calendar: utc).map(\.key)
        #expect(keys == feed.keys(seed: 257))
        #expect(keys.first != nil)
    }

    @Test("Different days do not all collapse onto one order")
    func daysDiffer() {
        let orders = Set((1 ... 60).map { feed.keys(seed: $0) })
        #expect(orders.count > 1)
    }

    @Test("The default Deep Study key is the first card of the day")
    func defaultStudyKey() {
        let expected = feed.items(on: day("2026-09-14"), calendar: utc).first?.key
        let resolved = DiscoverScreens.defaultStudyKey(
            feed: feed,
            studies: nil,
            today: day("2026-09-14")
        )
        // `items(on:)` uses `Calendar.current`; both sides use the same one, so the
        // assertion holds whatever zone the test host is in.
        #expect(resolved == feed.items(on: day("2026-09-14")).first?.key)
        #expect(expected != nil)
    }

    @Test("An empty feed hands the view nothing rather than crashing")
    func emptyFeed() {
        let empty = DiscoverFeed(items: [])
        #expect(empty.isEmpty)
        #expect(empty.items(on: day("2026-09-14"), calendar: utc).isEmpty)
        #expect(DiscoverScreens.defaultStudyKey(feed: empty, studies: nil, today: day("2026-09-14")) == nil)
    }
}

@Suite("Passage presentation")
struct PassagePresentationTests {
    @Test("Without a translation store the presentation degrades to the bare key")
    func noStore() throws {
        let presentation = try PassagePresentation.make(
            for: #require(PassageRef(key: "1:5-7")),
            translations: nil
        )
        #expect(presentation.reference == "1:5-7")
        #expect(presentation.english.isEmpty)
        #expect(presentation.arabic == nil)
        #expect(presentation.quoted.isEmpty, "an empty verse must not render a pair of bare quotes")
    }

    @Test("The quoted form wraps the English the way the reference draws it")
    func quoting() throws {
        let presentation = try PassagePresentation(
            passage: #require(PassageRef(key: "94:5-6")),
            reference: "Ash-Sharh 94:5-6",
            arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
            english: "With hardship comes ease.",
            translationTag: "ITANI"
        )
        #expect(presentation.quoted == "\"With hardship comes ease.\"")
    }

    @Test("An unparseable key yields no presentation")
    func badKey() {
        #expect(PassagePresentation.make(forKey: "not-a-key", translations: nil) == nil)
    }
}
