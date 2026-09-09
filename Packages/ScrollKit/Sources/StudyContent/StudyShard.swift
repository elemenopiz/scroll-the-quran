import Foundation

/// One `Content/study/surah_NNN.json` file. Decodes both the wrapped shape the app ships
/// (`{"surah": 1, "units": [...]}`) and a bare array of units.
public struct StudyShard: Hashable, Sendable {
    public let surah: Int
    public let units: [Study]

    public init(surah: Int, units: [Study]) {
        self.surah = surah
        self.units = units
    }

    /// Units keyed by their passage key, ready for lookup.
    public var byKey: [String: Study] {
        Dictionary(units.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

extension StudyShard: Decodable {
    private struct Wrapped: Decodable {
        let surah: Int?
        let units: [Study]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let wrapped = try? container.decode(Wrapped.self) {
            self.init(surah: wrapped.surah ?? wrapped.units.first?.surah ?? 0, units: wrapped.units)
            return
        }
        let units = try container.decode([Study].self)
        self.init(surah: units.first?.surah ?? 0, units: units)
    }
}
