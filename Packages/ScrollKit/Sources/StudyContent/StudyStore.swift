import Foundation
import Observation
import QuranData

/// Reads Deep Study commentary out of `Content/study`.
///
/// `passages.json` is the segmentation, not the content: it maps all 6,236 ayat onto 3,293 unit
/// keys, while only the units actually authored appear in a shard. So "which unit covers this
/// ayah?" (`unitKey(for:)`) is answered from `passages.json`, and "does this ayah have a study?"
/// (`hasStudy(for:)`) is answered from the shard.
///
/// `passages.json` loads once at init; the per-surah shards are large and load lazily, with at
/// most `shardCacheLimit` of them resident at a time (least-recently-used first out). Each load
/// also records that surah's unit keys in a permanent, lightweight index, so the existence
/// questions stay cheap after the shard itself is evicted. A surah with no shard on disk
/// resolves to `nil` and is remembered so the miss is not re-read on every scroll tick.
@Observable
public final class StudyStore {
    /// How many surah shards stay resident. Four covers a reader paging between neighbours
    /// plus a Deep Study cross-reference jump without thrashing.
    public static let shardCacheLimit = 4

    @ObservationIgnored private let loader: StudyContentLoading
    @ObservationIgnored private let shardCacheLimit: Int
    @ObservationIgnored public let index: PassageIndex

    /// Loaded shards, keyed by surah.
    @ObservationIgnored private var shards: [Int: [String: Study]] = [:]
    /// The unit keys each surah's shard carries. Filled when a shard is read (empty when there
    /// is none) and never evicted: a `Set<String>` per surah is a few kilobytes at full content,
    /// and it is what `hasStudy(for:)` consults on every scroll tick.
    @ObservationIgnored private var keyIndex: [Int: Set<String>] = [:]
    /// Surah numbers, least recently used first.
    @ObservationIgnored private var recency: [Int] = []
    /// Surahs whose shard is missing or unreadable — never retried.
    @ObservationIgnored private var unavailable: Set<Int> = []
    /// How many times a shard was actually read off the loader. Diagnostics and tests.
    @ObservationIgnored public private(set) var shardLoadCount = 0

    public init(
        loader: StudyContentLoading,
        passagesPath: String = "study/passages.json",
        shardCacheLimit: Int = StudyStore.shardCacheLimit
    ) throws {
        self.loader = loader
        self.shardCacheLimit = max(1, shardCacheLimit)
        index = try JSONDecoder().decode(PassageIndex.self, from: loader.data(at: passagesPath))
    }

    /// An empty store, for previews and for the "Study coming soon" path.
    public static func empty() -> StudyStore {
        // swiftlint:disable:next force_try
        try! StudyStore(loader: InMemoryContentLoader(json: ["study/passages.json": #"{"units":{}}"#]))
    }

    // MARK: - Lookup

    /// The key of the unit covering an ayah — the reader's lookup, answered from the
    /// segmentation, without touching a shard. Every ayah in the Quran has one; most of those
    /// units have no study yet, so this is not the question to ask before offering Deep Study.
    public func unitKey(for verse: VerseRef) -> String? {
        index.unitKey(for: verse)
    }

    /// Whether an ayah has commentary that can actually be opened. The unit must exist in the
    /// segmentation *and* be present in its surah's shard, so the first call for a surah reads
    /// that shard (and caches its key set for every later call, eviction or not).
    public func hasStudy(for verse: VerseRef) -> Bool {
        guard let key = index.unitKey(for: verse) else { return false }
        return studyKeys(inSurah: verse.surah).contains(key)
    }

    /// Whether a unit key resolves to an authored study. Same rule as `hasStudy(for:)`.
    public func containsUnit(_ key: String) -> Bool {
        guard let passage = PassageRef(key: key) else { return false }
        return studyKeys(inSurah: passage.surah).contains(key)
    }

    /// The keys of every authored unit in a surah. Empty when the surah has no shard yet.
    public func studyKeys(inSurah surah: Int) -> Set<String> {
        if let known = keyIndex[surah] {
            return known
        }
        _ = shard(surah: surah)
        return keyIndex[surah] ?? []
    }

    /// Every unit the segmentation defines, authored or not. `containsUnit(_:)` is the test for
    /// "is there a study", not membership of this set.
    public var unitKeys: Set<String> {
        index.unitKeys
    }

    /// The study covering an ayah, loading its shard if needed. `nil` when the surah has no
    /// shard yet — the app shows "Study coming soon" rather than failing.
    public func study(for verse: VerseRef) -> Study? {
        guard let key = index.unitKey(for: verse) else { return nil }
        return unit(key: key, surah: verse.surah)
    }

    /// The study for a unit key such as `"1:5-7"`. A single-ayah key that is not itself a unit
    /// is resolved through `passages.json` first.
    public func study(forKey key: String) -> Study? {
        guard let passage = PassageRef(key: key) else { return nil }
        if let found = unit(key: key, surah: passage.surah) {
            return found
        }
        guard passage.start == passage.end else { return nil }
        return study(for: VerseRef(surah: passage.surah, ayah: passage.start))
    }

    public func study(for passage: PassageRef) -> Study? {
        study(forKey: passage.key)
    }

    /// Every unit in a surah, in key order. Loads the shard.
    public func studies(inSurah surah: Int) -> [Study] {
        guard let shard = shard(surah: surah) else { return [] }
        return shard.values.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }

    // MARK: - Cache

    /// Resident surahs, least recently used first.
    public var cachedSurahs: [Int] {
        recency
    }

    public func preload(surah: Int) {
        _ = shard(surah: surah)
    }

    public func evictAll() {
        shards.removeAll()
        recency.removeAll()
    }

    // MARK: - Internals

    private func unit(key: String, surah: Int) -> Study? {
        shard(surah: surah)?[key]
    }

    private func shard(surah: Int) -> [String: Study]? {
        if let cached = shards[surah] {
            touch(surah)
            return cached
        }
        guard !unavailable.contains(surah) else { return nil }
        let path = index.shardPath(surah: surah)
        guard let data = try? loader.data(at: path),
              let decoded = try? JSONDecoder().decode(StudyShard.self, from: data)
        else {
            unavailable.insert(surah)
            keyIndex[surah] = []
            return nil
        }
        shardLoadCount += 1
        let byKey = decoded.byKey
        shards[surah] = byKey
        keyIndex[surah] = decoded.keys
        touch(surah)
        evictIfNeeded()
        return byKey
    }

    private func touch(_ surah: Int) {
        recency.removeAll { $0 == surah }
        recency.append(surah)
    }

    private func evictIfNeeded() {
        while recency.count > shardCacheLimit {
            let oldest = recency.removeFirst()
            shards[oldest] = nil
        }
    }
}
