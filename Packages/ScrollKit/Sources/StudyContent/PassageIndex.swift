import Foundation
import QuranData

/// `Content/study/passages.json`: the segmentation. Every one of the 6,236 ayat is mapped to the
/// key of the unit that covers it, whether or not that unit has been authored yet, so this file
/// answers "which unit does this ayah belong to?" and never "does this ayah have a study?" —
/// that one belongs to `StudyStore`, which asks the shards.
///
/// Two shapes decode: the bare `{"1:1": "1:1-7"}` map the pipeline writes, in which case shard
/// paths fall back to `study/surah_NNN.json`, and a wrapped
/// `{"shards": {"1": "study/surah_001.json"}, "units": {"1:1": "1:1"}}` used by fixtures.
public struct PassageIndex: Hashable, Sendable {
    /// Ayah key -> unit key.
    public let units: [String: String]
    /// Surah number -> shard path, relative to `Content/`.
    public let shards: [Int: String]

    public init(units: [String: String], shards: [Int: String] = [:]) {
        self.units = units
        self.shards = shards
    }

    /// The conventional shard path for a surah, used when `passages.json` lists no explicit one.
    public static func defaultShardPath(surah: Int) -> String {
        String(format: "study/surah_%03d.json", surah)
    }

    public func shardPath(surah: Int) -> String {
        shards[surah] ?? Self.defaultShardPath(surah: surah)
    }

    public func unitKey(for verse: VerseRef) -> String? {
        units[verse.key]
    }

    /// Every unit the segmentation defines — 3,293 of them for the shipped file. Most have no
    /// study yet; ask `StudyStore.containsUnit(_:)` for the ones that do.
    public var unitKeys: Set<String> {
        Set(units.values)
    }

    /// Surahs that have at least one unit — either because a shard is registered or because an
    /// ayah maps into them.
    public var coveredSurahs: Set<Int> {
        var covered = Set(shards.keys)
        for key in units.keys {
            if let ref = VerseRef(key: key) {
                covered.insert(ref.surah)
            }
        }
        return covered
    }
}

extension PassageIndex: Decodable {
    private struct Wrapped: Decodable {
        let shards: [String: String]?
        let units: [String: String]?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let wrapped = try? container.decode(Wrapped.self), let units = wrapped.units {
            var shards: [Int: String] = [:]
            for (number, path) in wrapped.shards ?? [:] {
                if let surah = Int(number) {
                    shards[surah] = path
                }
            }
            self.init(units: units, shards: shards)
            return
        }
        let flat = try container.decode([String: String].self)
        // A bare map carries bookkeeping keys like "version"/"note" only in the wrapped form,
        // so anything that is not an ayah key here is a decoding mistake worth dropping.
        self.init(units: flat.filter { VerseRef(key: $0.key) != nil })
    }
}
