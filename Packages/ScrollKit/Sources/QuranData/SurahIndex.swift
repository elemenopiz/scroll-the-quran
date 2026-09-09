import Foundation

/// Anything that can go wrong while loading `Content/quran`.
public enum QuranDataError: Error, CustomStringConvertible, Equatable {
    case malformedIndex(String)
    case unknownTranslation(String)
    case wrongVerseCount(id: String, expected: Int, actual: Int)

    public var description: String {
        switch self {
        case let .malformedIndex(reason): "quran/surahs.json is malformed: \(reason)"
        case let .unknownTranslation(id): "no translation with id '\(id)' in quran/translations.json"
        case let .wrongVerseCount(id, expected, actual): "\(id) has \(actual) verses, expected \(expected)"
        }
    }
}

/// The 114 surahs, and the arithmetic that turns a `VerseRef` into an offset into the flat
/// 6,236-entry text arrays: `globalIndex = surah.startIndex + ayah - 1`, so `2:255` is 261.
public struct SurahIndex: Sendable {
    public static let totalAyat = 6236
    public static let surahCount = 114

    public let surahs: [Surah]
    private let byNumber: [Int: Surah]
    /// Normalised name, article-stripped name and English meaning, all pointing at a number.
    private let byName: [String: Int]

    /// Validates that the surahs are numbered `1...n` and that `startIndex` is contiguous.
    public init(surahs: [Surah]) throws {
        var running = 0
        for (offset, surah) in surahs.enumerated() {
            guard surah.number == offset + 1 else {
                throw QuranDataError.malformedIndex("surah at position \(offset) is numbered \(surah.number)")
            }
            guard surah.ayahCount > 0 else {
                throw QuranDataError.malformedIndex("surah \(surah.number) has no ayat")
            }
            guard surah.startIndex == running else {
                throw QuranDataError.malformedIndex(
                    "surah \(surah.number) startIndex \(surah.startIndex) should be \(running)"
                )
            }
            running += surah.ayahCount
        }
        if surahs.count == Self.surahCount, running != Self.totalAyat {
            throw QuranDataError.malformedIndex("ayah total \(running) should be \(Self.totalAyat)")
        }

        self.surahs = surahs
        byNumber = Dictionary(uniqueKeysWithValues: surahs.map { ($0.number, $0) })

        var names: [String: Int] = [:]
        for surah in surahs {
            for alias in Self.aliases(for: surah) where !alias.isEmpty {
                // First surah to claim an alias keeps it; "The Cow" is unambiguous, some meanings are not.
                if names[alias] == nil {
                    names[alias] = surah.number
                }
            }
        }
        byName = names
    }

    /// Loads `Content/quran/surahs.json`.
    public init(locator: ContentLocator = .shared) throws {
        try self.init(surahs: locator.decode([Surah].self, from: "quran/surahs.json"))
    }

    public var count: Int {
        surahs.count
    }

    public subscript(number: Int) -> Surah? {
        byNumber[number]
    }

    public func surah(_ number: Int) -> Surah? {
        byNumber[number]
    }

    /// Matches `"Al-Baqarah"`, `"al baqarah"`, `"Baqarah"`, `"Surah Al-Baqarah"`, `"The Cow"`, `"2"`.
    public func surah(named name: String) -> Surah? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed) {
            return byNumber[number]
        }

        var query = Self.normalize(trimmed)
        for prefix in ["surahs", "surah", "surat", "sura", "chapter"] where query.hasPrefix(prefix) {
            query = String(query.dropFirst(prefix.count))
            break
        }
        if let number = byName[query] {
            return byNumber[number]
        }
        for article in Self.articles where query.hasPrefix(article) {
            if let number = byName[String(query.dropFirst(article.count))] {
                return byNumber[number]
            }
        }
        return nil
    }

    public func contains(_ verse: VerseRef) -> Bool {
        byNumber[verse.surah]?.contains(ayah: verse.ayah) ?? false
    }

    public func contains(_ passage: PassageRef) -> Bool {
        guard let surah = byNumber[passage.surah] else { return false }
        return surah.contains(ayah: passage.start) && surah.contains(ayah: passage.end)
    }

    /// `surah.startIndex + ayah - 1`, or nil when the ayah is out of range.
    public func globalIndex(of verse: VerseRef) -> Int? {
        guard let surah = byNumber[verse.surah], surah.contains(ayah: verse.ayah) else { return nil }
        return surah.startIndex + verse.ayah - 1
    }

    /// The offset of the first ayah of a passage.
    public func globalIndex(of passage: PassageRef) -> Int? {
        globalIndex(of: VerseRef(surah: passage.surah, ayah: passage.start))
    }

    public func verse(atGlobalIndex index: Int) -> VerseRef? {
        guard let surah = surah(containingGlobalIndex: index) else { return nil }
        return VerseRef(surah: surah.number, ayah: index - surah.startIndex + 1)
    }

    public func surah(containingGlobalIndex index: Int) -> Surah? {
        guard index >= 0 else { return nil }
        var low = 0
        var high = surahs.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let surah = surahs[mid]
            if index < surah.startIndex {
                high = mid - 1
            } else if index >= surah.endIndex {
                low = mid + 1
            } else {
                return surah
            }
        }
        return nil
    }

    /// The next ayah in reading order, crossing into the next surah. Nil after 114:6.
    public func next(after verse: VerseRef) -> VerseRef? {
        guard let index = globalIndex(of: verse) else { return nil }
        return self.verse(atGlobalIndex: index + 1)
    }

    /// The previous ayah in reading order. Nil before 1:1.
    public func previous(before verse: VerseRef) -> VerseRef? {
        guard let index = globalIndex(of: verse) else { return nil }
        return self.verse(atGlobalIndex: index - 1)
    }

    // MARK: - Name matching

    /// Transliteration prefixes that stand in for the Arabic definite article.
    static let articles = ["ash", "adh", "ath", "al", "an", "ar", "as", "at", "az", "ad"]

    /// Lowercased, diacritic-folded, punctuation-free: `"Al-Ma'idah"` -> `"almaidah"`.
    static func normalize(_ value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    /// Every spelling a surah answers to.
    static func aliases(for surah: Surah) -> [String] {
        var aliases = [normalize(surah.name), normalize(surah.meaning)]
        if let dash = surah.name.firstIndex(where: { $0 == "-" || $0 == " " }) {
            let article = normalize(String(surah.name[surah.name.startIndex ..< dash]))
            if articles.contains(article) {
                aliases.append(normalize(String(surah.name[surah.name.index(after: dash)...])))
            }
        }
        return aliases
    }
}
