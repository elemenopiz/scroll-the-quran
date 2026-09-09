import Foundation
import QuranData

/// One card of the Discover feed: a study unit plus the theme it is filed under.
public struct DiscoverItem: Codable, Hashable, Sendable, Identifiable {
    public let key: String
    public let themeId: String
    public let surah: Int
    public let weight: Int

    public var id: String {
        key
    }

    public var passage: PassageRef? {
        PassageRef(key: key)
    }

    public init(key: String, themeId: String, surah: Int? = nil, weight: Int = 50) {
        self.key = key
        self.themeId = themeId
        self.surah = surah ?? PassageRef(key: key)?.surah ?? 0
        self.weight = weight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        self.key = key
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId) ?? ""
        surah = try container.decodeIfPresent(Int.self, forKey: .surah) ?? PassageRef(key: key)?.surah ?? 0
        weight = try container.decodeIfPresent(Int.self, forKey: .weight) ?? 50
    }
}

/// The on-disk wrapper around the curated Discover list.
public struct DiscoverFile: Codable, Hashable, Sendable {
    public let version: Int?
    public let items: [DiscoverItem]

    public init(version: Int? = 1, items: [DiscoverItem]) {
        self.version = version
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

    public init(items: [DiscoverItem], resolves: (String) -> Bool = { _ in true }) {
        var seen: Set<String> = []
        self.items = items
            .filter { seen.insert($0.key).inserted && resolves($0.key) }
            .sorted { lhs, rhs in
                lhs.weight == rhs.weight ? lhs.key < rhs.key : lhs.weight > rhs.weight
            }
    }

    public init(loader: StudyContentLoading, path: String = "discover.json", resolves: (String) -> Bool) throws {
        let file = try JSONDecoder().decode(DiscoverFile.self, from: loader.data(at: path))
        self.init(items: file.items, resolves: resolves)
    }

    /// Builds the feed against a store, keeping only keys that resolve to a unit. Checked
    /// against `passages.json`, so no shard is loaded to build the feed.
    public init(loader: StudyContentLoading, path: String = "discover.json", store: StudyStore) throws {
        try self.init(loader: loader, path: path, resolves: { store.containsUnit($0) })
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
