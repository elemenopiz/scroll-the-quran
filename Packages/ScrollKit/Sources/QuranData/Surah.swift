import Foundation

/// One of the 114 surahs, as described by `Content/quran/surahs.json`.
public struct Surah: Hashable, Codable, Sendable, Identifiable {
    /// Where a surah was revealed. `surahs.json` writes Tanzil's `"Meccan"` / `"Medinan"`;
    /// ``Revelation/parse(_:)`` also accepts the `"makki"` / `"madani"` spelling.
    public enum Revelation: String, Codable, Sendable, CaseIterable {
        case meccan = "Meccan"
        case medinan = "Medinan"

        public static func parse(_ raw: String) -> Revelation? {
            switch raw.lowercased() {
            case "meccan", "makki", "mecca", "makkah": .meccan
            case "medinan", "madani", "medina", "madinah": .medinan
            default: nil
            }
        }
    }

    public let number: Int
    /// Transliterated name, e.g. `"Al-Baqarah"`. Never Arabic script.
    public let name: String
    /// English sense of the name, e.g. `"The Cow"`.
    public let meaning: String
    public let ayahCount: Int
    public let revelation: Revelation
    /// Zero-based offset of ayah 1 into the flat 6,236-verse arrays.
    public let startIndex: Int
    public let revelationOrder: Int?
    public let rukus: Int?
    /// Every juz this surah touches, ascending.
    public let juz: [Int]

    public init(
        number: Int,
        name: String,
        meaning: String,
        ayahCount: Int,
        revelation: Revelation,
        startIndex: Int,
        revelationOrder: Int? = nil,
        rukus: Int? = nil,
        juz: [Int] = []
    ) {
        self.number = number
        self.name = name
        self.meaning = meaning
        self.ayahCount = ayahCount
        self.revelation = revelation
        self.startIndex = startIndex
        self.revelationOrder = revelationOrder
        self.rukus = rukus
        self.juz = juz
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawRevelation = try container.decode(String.self, forKey: .revelation)
        guard let revelation = Revelation.parse(rawRevelation) else {
            throw DecodingError.dataCorruptedError(
                forKey: .revelation, in: container, debugDescription: "unknown revelation '\(rawRevelation)'"
            )
        }
        try self.init(
            number: container.decode(Int.self, forKey: .number),
            name: container.decode(String.self, forKey: .name),
            meaning: container.decode(String.self, forKey: .meaning),
            ayahCount: container.decode(Int.self, forKey: .ayahCount),
            revelation: revelation,
            startIndex: container.decode(Int.self, forKey: .startIndex),
            revelationOrder: container.decodeIfPresent(Int.self, forKey: .revelationOrder),
            rukus: container.decodeIfPresent(Int.self, forKey: .rukus),
            juz: container.decodeIfPresent([Int].self, forKey: .juz) ?? []
        )
    }

    public var id: Int {
        number
    }

    /// Title for surah headers and the surah list: `"Surah Al-Baqarah"`.
    /// Next to a verse number use ``name`` or ``reference(for:)-2v6qk`` (`"Al-Baqarah 2:255"`).
    public var displayName: String {
        "Surah \(name)"
    }

    /// The line under the title in the surah list: `"The Cow · 286 verses · Medinan"`.
    public var subtitle: String {
        "\(meaning) · \(ayahCount) verses · \(revelation.rawValue)"
    }

    /// The juz this surah spans, e.g. `1 ... 3` for Al-Baqarah. Nil only when `juz` is empty.
    public var juzRange: ClosedRange<Int>? {
        guard let first = juz.min(), let last = juz.max() else { return nil }
        return first ... last
    }

    /// Zero-based offset past the last ayah, so `startIndex ..< endIndex` is the whole surah.
    public var endIndex: Int {
        startIndex + ayahCount
    }

    public var verses: [VerseRef] {
        guard ayahCount >= 1 else { return [] }
        return (1 ... ayahCount).map { VerseRef(surah: number, ayah: $0) }
    }

    public func contains(ayah: Int) -> Bool {
        ayah >= 1 && ayah <= ayahCount
    }

    /// `"Al-Baqarah 2:255"` — the citation under a verse, in the widget and on share cards.
    public func reference(for ayah: Int) -> String {
        "\(name) \(number):\(ayah)"
    }

    public func reference(for passage: PassageRef) -> String {
        "\(name) \(passage.key)"
    }
}
