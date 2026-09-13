import Foundation
@testable import StudyContent
import Testing

/// The Phase 4o interleave: study cards with a REFLECTION card after every four of them.
///
/// Everything here is a property of `DiscoverFeed.feedItems(seed:)` alone — no view, no
/// clock — because the rule has to replay identically in the app, in a capture and in the
/// UI tests, and those three ask it in three different places.
@Suite("Discover feed interleave")
struct DiscoverInterleaveTests {
    // MARK: - Fixtures

    private static func studies(_ count: Int) -> [DiscoverItem] {
        (1 ... count).map { DiscoverItem(key: "\($0):1", themeId: "t\($0)", weight: 100 - $0) }
    }

    private static func reflections(_ count: Int) -> ReflectionStore {
        ReflectionStore(items: (1 ... count).map { index in
            Reflection(
                id: String(format: "r%03d", index),
                text: "Saying number \(index).",
                attribution: "Speaker \(index)",
                source: Reflection.Source(work: "Work", locator: "\(index)")
            )
        })
    }

    private static func feed(studies studyCount: Int, reflections reflectionCount: Int) -> DiscoverFeed {
        DiscoverFeed(items: studies(studyCount), reflections: reflections(reflectionCount))
    }

    /// The real `Content/` feed and catalogue, so the ratio is asserted against what ships
    /// rather than against a fixture that happens to divide nicely.
    private static func bundledFeed() throws -> DiscoverFeed {
        let file = try bundledDiscoverFile()
        return try DiscoverFeed(items: file.items, reflections: ReflectionStore(loader: bundledContent))
    }

    // MARK: - The rule

    @Test("The same seed always replays the same stream")
    func deterministic() {
        let feed = Self.feed(studies: 40, reflections: 20)
        #expect(feed.feedItems(seed: 257).map(\.id) == feed.feedItems(seed: 257).map(\.id))
        // And it is genuinely seeded, not a constant.
        #expect(feed.feedItems(seed: 257).map(\.id) != feed.feedItems(seed: 258).map(\.id))
    }

    @Test("Position 0 is a study card, so discover-dark's capture card does not move")
    func positionZeroIsAStudyCard() throws {
        let feed = try Self.bundledFeed()
        for seed in 1 ... 366 {
            let stream = feed.feedItems(seed: seed)
            #expect(stream.first?.isReflection == false, "seed \(seed) opens on a reflection")
            #expect(stream.first?.study?.key == feed.items(seed: seed).first?.key)
        }
    }

    @Test("A reflection lands at 4, 9, 14 … and nowhere else")
    func reflectionPositions() {
        let stream = Self.feed(studies: 40, reflections: 20).feedItems(seed: 257)
        let positions = stream.indices.filter { stream[$0].isReflection }
        #expect(positions == Array(stride(from: 4, to: stream.count, by: 5)))
        // Which is the same statement from the study side: study `s` moves to `s + s / 4`.
        let studyPositions = stream.indices.filter { !stream[$0].isReflection }
        for (studyIndex, position) in studyPositions.enumerated() {
            #expect(position == studyIndex + studyIndex / DiscoverFeed.studyCardsPerReflection)
        }
    }

    @Test("The 4:1 ratio holds over a full day of the shipped feed")
    func ratioOverAFullDay() throws {
        let feed = try Self.bundledFeed()
        let stream = feed.feedItems(seed: 257)
        let studies = stream.filter { !$0.isReflection }.count
        let reflections = stream.filter(\.isReflection).count
        #expect(studies == feed.items.count, "no study card was dropped")
        #expect(reflections == studies / DiscoverFeed.studyCardsPerReflection)
        #expect(stream.count == studies + reflections)
    }

    @Test("No reflection repeats within a day")
    func noRepeatsWithinADay() throws {
        let feed = try Self.bundledFeed()
        for seed in [1, 100, 257, 366] {
            let ids = feed.feedItems(seed: seed).compactMap { $0.reflection?.id }
            #expect(Set(ids).count == ids.count, "seed \(seed) repeats a reflection")
            #expect(ids == Array(feed.reflections.ids(seed: seed).prefix(ids.count)),
                    "reflections are not drawn in the day's own order")
        }
    }

    @Test("The catalogue is deep enough that a day can never run dry")
    func catalogueIsDeepEnough() throws {
        let feed = try Self.bundledFeed()
        let needed = feed.items.count / DiscoverFeed.studyCardsPerReflection
        #expect(feed.reflections.count >= needed,
                "\(feed.reflections.count) reflections against the \(needed) a day needs")
    }

    @Test("A shallow catalogue runs out rather than repeating")
    func shallowCatalogueStopsRatherThanRepeating() {
        let stream = Self.feed(studies: 40, reflections: 3).feedItems(seed: 7)
        let ids = stream.compactMap { $0.reflection?.id }
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3)
        #expect(stream.count == 43, "every study card is still in the stream")
    }

    @Test("No reflections at all is exactly the pre-4o feed")
    func emptyCatalogueIsThePreviousFeed() {
        let feed = DiscoverFeed(items: Self.studies(10))
        #expect(feed.feedItems(seed: 257).map(\.study?.key) == feed.items(seed: 257).map(\.key))
        #expect(feed.feedItems(seed: 257).allSatisfy { !$0.isReflection })
    }

    // MARK: - Identity and metering

    @Test("Ids are namespaced by kind and a reflection carries no metered key")
    func identityAndMetering() {
        let stream = Self.feed(studies: 8, reflections: 4).feedItems(seed: 3)
        for item in stream {
            switch item {
            case let .study(study):
                #expect(item.id == "study:\(study.key)")
                #expect(item.meteredKey == study.key)
            case let .reflection(reflection):
                #expect(item.id == "reflection:\(reflection.id)")
                #expect(item.meteredKey == nil, "a reflection must never be metered")
            }
        }
        #expect(Set(stream.map(\.id)).count == stream.count, "two pages share an id")

        // The pager only has the id when it lands on a page, so the id has to answer the
        // metering question on its own.
        for item in stream {
            #expect(DiscoverFeedItem.meteredKey(forID: item.id) == item.meteredKey)
        }
        #expect(DiscoverFeedItem.meteredKey(forID: "reflection:rumi-1") == nil)
        #expect(DiscoverFeedItem.meteredKey(forID: "study:2:255") == "2:255")
    }

    @Test("Today's stream is the day-of-year seed's stream")
    func todayIsTheDayOfYearSeed() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = try #require(formatter.date(from: "2026-09-14"))

        let feed = Self.feed(studies: 20, reflections: 10)
        #expect(calendar.ordinality(of: .day, in: .year, for: today) == 257)
        #expect(feed.feedItems(on: today, calendar: calendar).map(\.id) == feed.feedItems(seed: 257).map(\.id))
    }
}
