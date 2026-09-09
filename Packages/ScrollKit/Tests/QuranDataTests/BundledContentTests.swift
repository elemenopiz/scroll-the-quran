import Foundation
@testable import QuranData
import Testing

@Test("surahs.json describes all 114 surahs with contiguous, monotone start indices")
func surahsAreContiguous() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: TestContent.data("quran/surahs.json"))
    #expect(surahs.count == 114)

    var running = 0
    for (offset, surah) in surahs.enumerated() {
        #expect(surah.number == offset + 1)
        #expect(surah.ayahCount > 0)
        #expect(!surah.juz.isEmpty)
        #expect(surah.juz == surah.juz.sorted())
        #expect(surah.juz.allSatisfy { (1 ... 30).contains($0) })
        #expect(surah.startIndex == running, "surah \(surah.number) startIndex is not contiguous")
        running += surah.ayahCount
    }
    #expect(running == 6236)
    #expect(surahs.first?.name == "Al-Fatiha")
    #expect(surahs.last?.name == "An-Nas")
    #expect(surahs.first?.revelation == .meccan)
    #expect(surahs[1].revelation == .medinan)
}

@Test("Global index is startIndex + ayah - 1, so 2:255 is 261")
func globalIndexMatchesTheKeyFormula() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: TestContent.data("quran/surahs.json"))
    let ayatAlKursi = try #require(VerseRef(key: "2:255"))
    let index = surahs[ayatAlKursi.surah - 1].startIndex + ayatAlKursi.ayah - 1
    #expect(index == 261)
}

@Test("itani.json holds 6,236 non-empty English verses and no Arabic script")
func translationIsCompleteAndEnglishOnly() throws {
    let verses = try TestContent.verses("itani.json")
    #expect(verses.count == 6236)
    #expect(verses.allSatisfy { !$0.isEmpty })
    #expect(verses.first == "In the name of God, the Gracious, the Merciful")
    #expect(verses[261].hasPrefix("God! There is no god except He"))
    let offenders = verses.enumerated().filter(\.element.containsArabicScript).map(\.offset)
    #expect(offenders.isEmpty, "Arabic script at flat indices \(offenders.prefix(5))")
}

@Test(
    "Every bundled translation has 6,236 non-empty entries and never any Arabic script",
    arguments: ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"]
)
func everyTranslationIsEnglishOnly(file: String) throws {
    let verses = try TestContent.verses(file)
    #expect(verses.count == 6236)
    let empty = verses.enumerated().filter { $0.element.trimmingCharacters(in: .whitespaces).isEmpty }.map(\.offset)
    #expect(empty.isEmpty, "\(file): empty entries at \(empty.prefix(5))")
    let offenders = verses.enumerated().filter(\.element.containsArabicScript).map(\.offset)
    #expect(offenders.isEmpty, "\(file): Arabic script at flat indices \(offenders.prefix(5))")
}

@Test("arabic-uthmani.json holds 6,236 entries and every one of them is Arabic script")
func arabicEditionIsComplete() throws {
    let verses = try TestContent.verses("arabic-uthmani.json")
    #expect(verses.count == 6236)
    let plain = verses.enumerated().filter { !$0.element.containsArabicScript }.map(\.offset)
    #expect(plain.isEmpty, "no Arabic script at flat indices \(plain.prefix(5))")
    // Al-Fatiha 1:1 and the opening of Ayat al-Kursi, verbatim from Tanzil.
    #expect(verses[0] == "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ")
    #expect(verses[261].hasPrefix("ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ"))
}

@Test("The Arabic file and the translations agree on length, so one global index addresses both")
func arabicAndTranslationsAreTheSameLength() throws {
    let arabic = try TestContent.verses("arabic-uthmani.json")
    for file in ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"] {
        let count = try TestContent.verses(file).count
        #expect(count == arabic.count, "\(file) has \(count) entries")
    }
}

@Test("translations.json registers exactly one default and carries its copyright verbatim")
func translationRegistryHasOneDefault() throws {
    let registry = try JSONDecoder().decode(TranslationRegistry.self, from: TestContent.data("quran/translations.json"))
    let defaults = registry.translations.filter(\.isDefault)
    #expect(defaults.count == 1)
    #expect(defaults.first?.id == registry.defaultID)
    #expect(defaults.first?.id == "itani")
    #expect(defaults.first?.copyright == "Translation by Talal Itani, ClearQuran.com")
    #expect(registry.translations.map(\.id) == ["itani", "saheeh", "ruwwad", "pickthall"])
    #expect(registry.translations.map(\.abbrev) == ["CLEAR", "SAHEEH", "RUWWAD", "PICKTHALL"])
    #expect(registry.translations.allSatisfy { info in info.bundled })
    #expect(registry.translations.allSatisfy { info in info.offline })
    #expect(Set(registry.translations.map(\.abbrev)).count == registry.translations.count)
    #expect(registry.translations.allSatisfy { !$0.attribution.isEmpty && !$0.licence.isEmpty })
    #expect(registry.arabicEdition.attribution == "Quran text (Uthmani) from Tanzil.net, licensed CC BY 3.0.")
}

@Test("Every file named by the registry is on disk")
func registryFilesExist() throws {
    let registry = try JSONDecoder().decode(TranslationRegistry.self, from: TestContent.data("quran/translations.json"))
    for info in registry.translations {
        #expect(TestContent.locator.url(for: info.file) != nil, "missing \(info.file)")
    }
    #expect(TestContent.locator.url(for: registry.arabicEdition.file) != nil)
}
