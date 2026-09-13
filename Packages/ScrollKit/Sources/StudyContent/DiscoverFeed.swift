import Foundation
import QuranData

/// One card of the Discover feed: a study unit plus the theme it is filed under.
///
/// `Tools/content-gen/assemble.mjs` writes `{key, surah, start, end, themeId, title}`. `weight`
/// is not part of that shape — the pipeline orders the feed by seed, not by weight — so it
/// defaults, and a file that does carry weights still orders by them.
public struct DiscoverItem: Codable, Hashable, Sendable, Identifiable {
    public let key: String
    public let themeId: String
    public let surah: Int
    public let start: Int
    public let end: Int
    public let title: String
    public let weight: Int

    public var id: String {
        key
    }

    public var passage: PassageRef? {
        PassageRef(key: key)
    }

    public init(
        key: String,
        themeId: String,
        surah: Int? = nil,
        weight: Int = 50,
        title: String = "",
        start: Int? = nil,
        end: Int? = nil
    ) {
        let parsed = PassageRef(key: key)
        self.key = key
        self.themeId = themeId
        self.surah = surah ?? parsed?.surah ?? 0
        self.start = start ?? parsed?.start ?? 0
        self.end = end ?? parsed?.end ?? 0
        self.title = title
        self.weight = weight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let parsed = PassageRef(key: key)
        self.key = key
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId) ?? ""
        surah = try container.decodeIfPresent(Int.self, forKey: .surah) ?? parsed?.surah ?? 0
        start = try container.decodeIfPresent(Int.self, forKey: .start) ?? parsed?.start ?? 0
        end = try container.decodeIfPresent(Int.self, forKey: .end) ?? parsed?.end ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        weight = try container.decodeIfPresent(Int.self, forKey: .weight) ?? 50
    }
}

/// The on-disk wrapper around the curated Discover list, as `assemble.mjs` writes it:
/// `{seed, promptVersion, generatedAt, count, items}`. Every field but `items` is provenance.
public struct DiscoverFile: Codable, Hashable, Sendable {
    public let version: Int?
    public let seed: String?
    public let promptVersion: String?
    public let generatedAt: String?
    public let count: Int?
    public let items: [DiscoverItem]

    public init(
        version: Int? = nil,
        seed: String? = nil,
        promptVersion: String? = nil,
        generatedAt: String? = nil,
        count: Int? = nil,
        items: [DiscoverItem]
    ) {
        self.version = version
        self.seed = seed
        self.promptVersion = promptVersion
        self.generatedAt = generatedAt
        self.count = count
        self.items = items
    }
}

/// `Content/discover.json`, ordered for the day.
///
/// The order shipped in the file is only a fallback: `items(seed:)` shuffles deterministically,
/// so every device showing the same seed (the day of the year) sees the same feed, and the same
/// seed always replays the same order. Items whose key has no study unit are dropped at init,
/// so the feed can never hand the UI a card that opens onto nothing.
public struct DiscoverFeed: Hashable, Sendable {
    /// The resolvable items, in a stable base order: heaviest first, then by key.
    public let items: [DiscoverItem]
    /// The REFLECTION cards interleaved into the same stream (Phase 4o).
    ///
    /// The feed owns them rather than the view because the two lists have to be replayed
    /// together from one seed: `feedItems(seed:)` is the single answer to "what does the
    /// reader see today", and the shell, the tests and a capture all ask it the same way.
    /// Empty by default, which is exactly the pre-4o feed.
    public let reflections: ReflectionStore

    public init(
        items: [DiscoverItem],
        reflections: ReflectionStore = .empty,
        resolves: (String) -> Bool = { _ in true }
    ) {
        var seen: Set<String> = []
        self.items = items
            .filter { seen.insert($0.key).inserted && resolves($0.key) }
            .sorted { lhs, rhs in
                // Weight first (the pipeline leaves it uniform), then mushaf order rather than
                // the string order of the key, so "10:1" does not sort before "2:1".
                (rhs.weight, lhs.surah, lhs.start, lhs.end, lhs.key)
                    < (lhs.weight, rhs.surah, rhs.start, rhs.end, rhs.key)
            }
        self.reflections = reflections
    }

    public init(
        loader: StudyContentLoading,
        path: String = "discover.json",
        reflections: ReflectionStore = .empty,
        resolves: (String) -> Bool
    ) throws {
        let file = try JSONDecoder().decode(DiscoverFile.self, from: loader.data(at: path))
        self.init(items: file.items, reflections: reflections, resolves: resolves)
    }

    /// Builds the feed against a store, keeping only keys the store can actually open. That is
    /// a question only the shards can answer (`passages.json` maps every ayah in the Quran,
    /// authored or not), so building the feed does load the shards of the surahs it names.
    public init(
        loader: StudyContentLoading,
        path: String = "discover.json",
        reflections: ReflectionStore = .empty,
        store: StudyStore
    ) throws {
        try self.init(loader: loader, path: path, reflections: reflections, resolves: { store.containsUnit($0) })
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public var count: Int {
        items.count
    }

    /// The feed for a seed — in practice `Calendar.dayOfYear`. Same seed, same order, always.
    public func items(seed: Int) -> [DiscoverItem] {
        var generator = SeededGenerator(seed: seed)
        var shuffled = items
        // Fisher-Yates spelled out rather than `shuffled(using:)`: the stdlib is free to change
        // how it consumes the generator, and this order has to stay identical forever.
        guard shuffled.count > 1 else { return shuffled }
        for index in stride(from: shuffled.count - 1, to: 0, by: -1) {
            let pick = Int(generator.next() % UInt64(index + 1))
            shuffled.swapAt(index, pick)
        }
        return shuffled
    }

    public func keys(seed: Int) -> [String] {
        items(seed: seed).map(\.key)
    }

    /// Today's feed in the given calendar. Kept separate from `items(seed:)` so tests never
    /// depend on the clock.
    public func items(on date: Date, calendar: Calendar = .current) -> [DiscoverItem] {
        items(seed: calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
    }

    // MARK: - The combined stream

    /// How many study cards sit between two REFLECTION cards.
    public static let studyCardsPerReflection = 4

    /// **The list the Discover tab actually pages through** (Phase 4o): the day's study
    /// cards with the day's reflections interleaved.
    ///
    /// The rule, in full:
    /// * both lists are replayed from the *same* seed, so a device, a test and a capture
    ///   on the same day see the same stream;
    /// * position 0 is always a study card — the first card of the day is what
    ///   `discover-dark` is scored against, and it must not move;
    /// * a reflection lands after every `studyCardsPerReflection` study cards, so the
    ///   combined positions are 4, 9, 14 …, and the study at index `s` moves to combined
    ///   index `s + s / 4`;
    /// * reflections are drawn from `ReflectionStore.items(seed:)` in order and never
    ///   repeat inside a day. 167 ship against 326 study units, which needs 81, so the
    ///   pool cannot run dry — and if a content change ever made it, the stream simply
    ///   carries on with study cards rather than showing one twice.
    public func feedItems(seed: Int) -> [DiscoverFeedItem] {
        let studies = items(seed: seed)
        guard !reflections.isEmpty else {
            return studies.map(DiscoverFeedItem.study)
        }
        var pool = reflections.items(seed: seed)[...]
        var stream: [DiscoverFeedItem] = []
        stream.reserveCapacity(studies.count + studies.count / DiscoverFeed.studyCardsPerReflection)
        var sinceReflection = 0
        for study in studies {
            stream.append(.study(study))
            sinceReflection += 1
            guard sinceReflection == DiscoverFeed.studyCardsPerReflection,
                  let next = pool.popFirst()
            else { continue }
            stream.append(.reflection(next))
            sinceReflection = 0
        }
        return stream
    }

    /// Today's combined stream. The clock-free half is `feedItems(seed:)`.
    public func feedItems(on date: Date, calendar: Calendar = .current) -> [DiscoverFeedItem] {
        feedItems(seed: calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
    }
}

/// One page of the Discover tab: a study card, or a REFLECTION card.
///
/// `id` is prefixed by kind rather than being the bare key: the pager keys its pages on it
/// and a reflection id and a passage key come from different namespaces, so a collision
/// would be silent. It is also what the free-tier gate counts — see `meteredKey`.
public enum DiscoverFeedItem: Identifiable, Hashable, Sendable {
    case study(DiscoverItem)
    case reflection(Reflection)

    /// The two id namespaces, spelled once so `meteredKey(forID:)` can read an id back.
    public enum Kind: String, CaseIterable, Sendable {
        case study
        case reflection

        var prefix: String {
            "\(rawValue):"
        }
    }

    public var id: String {
        switch self {
        case let .study(item): Kind.study.prefix + item.key
        case let .reflection(reflection): Kind.reflection.prefix + reflection.id
        }
    }

    public var study: DiscoverItem? {
        guard case let .study(item) = self else { return nil }
        return item
    }

    public var reflection: Reflection? {
        guard case let .reflection(reflection) = self else { return nil }
        return reflection
    }

    public var isReflection: Bool {
        reflection != nil
    }

    /// What `DiscoverGate` counts this page as, or `nil` when the page is free.
    ///
    /// Reflections are free and unmetered (owner, Phase 4o): they do not consume one of
    /// `DiscoverGate.freeCardsPerDay` and the paywall never replaces one. Putting the
    /// decision here rather than in the view is what lets `DiscoverGateTests` assert it
    /// against the real gate.
    public var meteredKey: String? {
        study?.key
    }

    /// The same answer from an id alone, so the pager can meter the page it just landed on
    /// without walking the day's list again on every scroll event.
    public static func meteredKey(forID id: String) -> String? {
        guard id.hasPrefix(Kind.study.prefix) else { return nil }
        return String(id.dropFirst(Kind.study.prefix.count))
    }
}

/// SplitMix64 — small, fast, and identical on every platform, which is what "deterministic
/// shuffle" has to mean when the widget, the app and the tests all compute it separately.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        // Offset so seed 0 does not degenerate, and bit-pattern conversion so negative
        // seeds are still well defined.
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
