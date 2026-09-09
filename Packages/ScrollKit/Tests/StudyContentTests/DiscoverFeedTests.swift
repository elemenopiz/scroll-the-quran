import Foundation
import QuranData
@testable import StudyContent
import Testing

private func bundledFeed() throws -> (DiscoverFeed, StudyStore) {
    let store = try bundledStore()
    return try (DiscoverFeed(loader: bundledContent, store: store), store)
}

@Test("The bundled Discover feed only carries keys that resolve to a study")
func feedOnlyCarriesResolvableKeys() throws {
    let (feed, store) = try bundledFeed()
    #expect(!feed.isEmpty)
    for item in feed.items {
        #expect(store.containsUnit(item.key), "\(item.key) is not a unit")
        let study = try #require(store.study(forKey: item.key), "\(item.key) resolves to nothing")
        #expect(study.surah == item.surah)
    }
    #expect(feed.count == 5)
    #expect(Set(feed.items.map(\.key)).count == feed.count, "the feed repeats a key")
}

@Test("Every Discover item names a theme that themes.json defines")
func feedThemesExist() throws {
    let (feed, _) = try bundledFeed()
    let themes = try ThemeIndex(loader: bundledContent)
    for item in feed.items {
        #expect(themes.theme(id: item.themeId) != nil, "\(item.key) points at unknown theme \(item.themeId)")
    }
}

@Test("Keys with no study unit are dropped when the feed is built")
func unresolvableKeysAreDropped() throws {
    let loader = InMemoryContentLoader(json: [
        "discover.json": """
        { "items": [
            { "key": "1:1", "themeId": "a", "surah": 1, "weight": 10 },
            { "key": "2:255", "themeId": "b", "surah": 2, "weight": 99 },
            { "key": "1:1", "themeId": "a", "surah": 1, "weight": 10 }
        ] }
        """,
    ])
    let feed = try DiscoverFeed(loader: loader, resolves: { $0 == "1:1" })
    #expect(feed.items.map(\.key) == ["1:1"], "the heavy but unresolvable key survived")
    for seed in 0 ..< 10 {
        #expect(feed.keys(seed: seed) == ["1:1"])
    }
}

@Test("The same seed always produces the same order")
func feedIsDeterministicForASeed() throws {
    let (feed, _) = try bundledFeed()
    let first = feed.keys(seed: 258)
    for _ in 0 ..< 20 {
        #expect(feed.keys(seed: 258) == first)
    }
    // A freshly built feed agrees with the first one: nothing depends on instance state.
    let (rebuilt, _) = try bundledFeed()
    #expect(rebuilt.keys(seed: 258) == first)
    #expect(rebuilt.keys(seed: 1) == feed.keys(seed: 1))
}

@Test("Shuffling is a permutation: every seed shows every card exactly once")
func everySeedIsAPermutation() throws {
    let (feed, _) = try bundledFeed()
    let expected = Set(feed.items.map(\.key))
    for seed in 0 ..< 400 {
        let keys = feed.keys(seed: seed)
        #expect(keys.count == expected.count, "seed \(seed) changed the card count")
        #expect(Set(keys) == expected, "seed \(seed) dropped or repeated a card")
    }
}

@Test("Different seeds really do reorder the feed")
func differentSeedsReorder() throws {
    let (feed, _) = try bundledFeed()
    let orders = Set((0 ..< 50).map { feed.keys(seed: $0).joined(separator: "|") })
    #expect(orders.count > 1, "the shuffle ignores its seed")
    #expect(orders.count >= 5, "the shuffle is far too clumpy: \(orders.count) distinct orders in 50 seeds")
}

@Test("The base order is the file's weighting, not the file's line order")
func baseOrderIsByWeight() throws {
    let loader = InMemoryContentLoader(json: [
        "discover.json": """
        { "items": [
            { "key": "3:1", "themeId": "c", "weight": 10 },
            { "key": "2:1", "themeId": "b", "weight": 90 },
            { "key": "1:1", "themeId": "a", "weight": 90 }
        ] }
        """,
    ])
    let feed = try DiscoverFeed(loader: loader, resolves: { _ in true })
    #expect(feed.items.map(\.key) == ["1:1", "2:1", "3:1"])
    // surah is derived from the key when the file omits it.
    #expect(feed.items.map(\.surah) == [1, 2, 3])
    #expect(feed.items[0].passage == PassageRef(surah: 1, start: 1, end: 1))
}

@Test("Today's feed is just the day-of-year seed")
func feedForADateUsesTheDayOfYear() throws {
    let (feed, _) = try bundledFeed()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
    var components = DateComponents()
    components.year = 2026
    components.month = 9
    components.day = 14
    let date = try #require(calendar.date(from: components))
    let dayOfYear = try #require(calendar.ordinality(of: .day, in: .year, for: date))
    #expect(feed.items(on: date, calendar: calendar).map(\.key) == feed.keys(seed: dayOfYear))
}
