import Foundation
@testable import QuranData
import Testing

/// Repo root, walked up from this file: Tests/QuranDataTests -> Tests -> ScrollKit -> Packages -> root.
private let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

private func contentData(_ path: String) throws -> Data {
    try Data(contentsOf: repoRoot.appendingPathComponent("Content").appendingPathComponent(path))
}

private struct Surah: Decodable {
    let number: Int
    let name: String
    let meaning: String
    let ayahCount: Int
    let revelation: String
    let startIndex: Int
    let juz: [Int]
}

/// The blocks `.claude/hooks/no-arabic.sh` greps for. v1 ships English only.
private let arabicBlocks: [ClosedRange<UInt32>] = [
    0x0600 ... 0x06FF, 0x0750 ... 0x077F, 0xFB50 ... 0xFDFF, 0xFE70 ... 0xFEFF,
]

private extension String {
    var containsArabicScript: Bool {
        unicodeScalars.contains { scalar in arabicBlocks.contains { $0.contains(scalar.value) } }
    }
}

@Test("surahs.json describes all 114 surahs with contiguous, monotone start indices")
func surahsAreContiguous() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
    #expect(surahs.count == 114)

    var running = 0
    for (offset, surah) in surahs.enumerated() {
        #expect(surah.number == offset + 1)
        #expect(surah.ayahCount > 0)
        #expect(["Meccan", "Medinan"].contains(surah.revelation))
        #expect(!surah.juz.isEmpty)
        #expect(surah.juz == surah.juz.sorted())
        #expect(surah.juz.allSatisfy { (1 ... 30).contains($0) })
        #expect(surah.startIndex == running, "surah \(surah.number) startIndex is not contiguous")
        running += surah.ayahCount
    }
    #expect(running == 6236)
    #expect(surahs.first?.name == "Al-Fatiha")
    #expect(surahs.last?.name == "An-Nas")
}

@Test("Global index is startIndex + ayah - 1, so 2:255 is 261")
func globalIndexMatchesTheKeyFormula() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
    let ayatAlKursi = try #require(VerseRef(key: "2:255"))
    let index = surahs[ayatAlKursi.surah - 1].startIndex + ayatAlKursi.ayah - 1
    #expect(index == 261)
}

@Test("itani.json holds 6,236 non-empty English verses and no Arabic script")
func translationIsCompleteAndEnglishOnly() throws {
    let verses = try JSONDecoder().decode([String].self, from: contentData("quran/itani.json"))
    #expect(verses.count == 6236)
    #expect(verses.allSatisfy { !$0.isEmpty })
    #expect(verses.first == "In the name of God, the Gracious, the Merciful")
    #expect(verses[261].hasPrefix("God! There is no god except He"))
    let offenders = verses.enumerated().filter(\.element.containsArabicScript).map(\.offset)
    #expect(offenders.isEmpty, "Arabic script at flat indices \(offenders.prefix(5))")
}

@Test("translations.json registers exactly one default and carries its copyright verbatim")
func translationRegistryHasOneDefault() throws {
    struct Registry: Decodable {
        struct Entry: Decodable {
            let id: String
            let abbrev: String
            let copyright: String
            let isDefault: Bool
            let bundled: Bool
        }

        let defaultID: String
        let translations: [Entry]
    }
    let registry = try JSONDecoder().decode(Registry.self, from: contentData("quran/translations.json"))
    let defaults = registry.translations.filter(\.isDefault)
    #expect(defaults.count == 1)
    #expect(defaults.first?.id == registry.defaultID)
    #expect(defaults.first?.id == "itani")
    #expect(defaults.first?.copyright == "Translation by Talal Itani, ClearQuran.com")
    #expect(registry.translations.filter(\.bundled).map(\.id) == ["itani"])
    #expect(Set(registry.translations.map(\.abbrev)).count == registry.translations.count)
}
