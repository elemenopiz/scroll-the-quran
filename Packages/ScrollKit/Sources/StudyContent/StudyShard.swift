import Foundation

/// One `Content/study/surah_NNN.json`.
///
/// The shape the pipeline writes (`Tools/content-gen/assemble.mjs`) is
/// `{"surah": 2, "promptVersion": "p1", "generatedAt": "…", "studies": [...]}`, sorted by start
/// ayah. A bare array of units also decodes, and so does `"units"` in place of `"studies"`, which
/// keeps small in-memory fixtures readable.
///
/// A shard holds only the units that have actually been authored: outside surahs 1-3 there is no
/// shard at all yet, and inside them most ayat are still uncovered. `StudyStore` treats a shard
/// as the authority on which studies exist.
public struct StudyShard: Hashable, Sendable {
    public let surah: Int
    public let units: [Study]
    /// The prompt revision the units were generated under, e.g. `"p1"`. Empty for fixtures.
    public let promptVersion: String
    /// ISO-8601 stamp written by `assemble.mjs`. Empty for fixtures.
    public let generatedAt: String

    public init(surah: Int, units: [Study], promptVersion: String = "", generatedAt: String = "") {
        self.surah = surah
        self.units = units
        self.promptVersion = promptVersion
        self.generatedAt = generatedAt
    }

    /// Units keyed by their passage key, ready for lookup.
    public var byKey: [String: Study] {
        Dictionary(units.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The keys of the units this shard actually carries — the lightweight index `StudyStore`
    /// keeps so "does this ayah have a study?" survives shard eviction.
    public var keys: Set<String> {
        Set(units.map(\.key))
    }
}

extension StudyShard: Decodable {
    private struct Wrapped: Decodable {
        let surah: Int?
        let promptVersion: String?
        let generatedAt: String?
        let studies: [Study]?
        let units: [Study]?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let wrapped = try? container.decode(Wrapped.self), let units = wrapped.studies ?? wrapped.units {
            self.init(
                surah: wrapped.surah ?? units.first?.surah ?? 0,
                units: units,
                promptVersion: wrapped.promptVersion ?? "",
                generatedAt: wrapped.generatedAt ?? ""
            )
            return
        }
        let units = try container.decode([Study].self)
        self.init(surah: units.first?.surah ?? 0, units: units)
    }
}
