import Foundation

/// A single ayah, addressed the way the app addresses everything: `"2:255"`.
public struct VerseRef: Hashable, Codable, Sendable, CustomStringConvertible {
    public let surah: Int
    public let ayah: Int

    public init(surah: Int, ayah: Int) {
        self.surah = surah
        self.ayah = ayah
    }

    /// Parses `"2:255"`. Returns nil for anything else.
    public init?(key: String) {
        let parts = key.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let surah = Int(parts[0]), let ayah = Int(parts[1]),
              surah >= 1, ayah >= 1
        else { return nil }
        self.init(surah: surah, ayah: ayah)
    }

    public var key: String {
        "\(surah):\(ayah)"
    }

    public var description: String {
        key
    }
}

/// A contiguous run of ayat inside one surah, keyed `"94:5-6"` (or `"2:255"` when it is one ayah).
public struct PassageRef: Hashable, Codable, Sendable, CustomStringConvertible {
    public let surah: Int
    public let start: Int
    public let end: Int

    public init(surah: Int, start: Int, end: Int) {
        self.surah = surah
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public init(verse: VerseRef) {
        self.init(surah: verse.surah, start: verse.ayah, end: verse.ayah)
    }

    /// Parses `"94:5-6"` and `"2:255"`. Returns nil for anything else.
    public init?(key: String) {
        let parts = key.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let surah = Int(parts[0]), surah >= 1 else { return nil }
        let range = parts[1].split(separator: "-", omittingEmptySubsequences: false)
        switch range.count {
        case 1:
            guard let only = Int(range[0]), only >= 1 else { return nil }
            self.init(surah: surah, start: only, end: only)
        case 2:
            guard let start = Int(range[0]), let end = Int(range[1]), start >= 1, end >= start else { return nil }
            self.init(surah: surah, start: start, end: end)
        default:
            return nil
        }
    }

    public var key: String {
        start == end ? "\(surah):\(start)" : "\(surah):\(start)-\(end)"
    }

    public var description: String {
        key
    }

    public var verses: [VerseRef] {
        (start ... end).map { VerseRef(surah: surah, ayah: $0) }
    }
}
