import Foundation
@testable import QuranData
import Testing

@Test("The store opens on the registry's default translation")
func storeStartsOnTheDefault() throws {
    let store = try TestContent.store()
    #expect(store.selectedID == "itani")
    #expect(store.selected?.abbrev == "ITANI")
    #expect(store.translations.count == 4)
    #expect(store.translations.filter(\.isDefault).count == 1)
    #expect(store.index.count == 114)
}

@Test("Every registered translation reads 2:255 as English prose")
func everyTranslationCanBeRead() throws {
    let store = try TestContent.store()
    let ayatAlKursi = try #require(VerseRef(key: "2:255"))
    for info in store.translations {
        let text = try #require(store.text(for: ayatAlKursi, translation: info.id), "\(info.id) had no 2:255")
        #expect(text.wordCount > 30)
        #expect(!text.containsArabicScript, "\(info.id) 2:255 carries Arabic script")
        let loaded = try store.verses(of: info.id)
        #expect(loaded.count == 6236)
    }
    #expect(store.text(for: ayatAlKursi)?.hasPrefix("God! There is no god except He") == true)
    #expect(store.text(for: ayatAlKursi, translation: "pickthall")?.hasPrefix("Allah! There is no deity save Him") == true)
}

@Test("arabic(for:) returns the Uthmani line for the same reference")
func arabicLayerLinesUpWithTheEnglish() throws {
    let store = try TestContent.store()
    let ayatAlKursi = try #require(VerseRef(key: "2:255"))
    let arabic = try #require(store.arabic(for: ayatAlKursi))
    #expect(arabic.containsArabicScript)
    #expect(store.arabic(for: VerseRef(surah: 1, ayah: 1))?.containsArabicScript == true)
    #expect(store.arabic(for: VerseRef(surah: 114, ayah: 6))?.containsArabicScript == true)
    #expect(store.arabic(for: VerseRef(surah: 2, ayah: 287)) == nil)
    #expect(store.arabic(for: VerseRef(surah: 115, ayah: 1)) == nil)
    #expect(store.registry.arabicEdition.licence == "CC BY 3.0")
}

@Test("Out-of-range references read as nil rather than trapping")
func outOfRangeReferencesAreNil() throws {
    let store = try TestContent.store()
    #expect(store.text(for: VerseRef(surah: 2, ayah: 287)) == nil)
    #expect(store.text(for: VerseRef(surah: 115, ayah: 1)) == nil)
    #expect(store.text(for: VerseRef(surah: 2, ayah: 255), translation: "nope") == nil)
    #expect(throws: QuranDataError.self) { try store.verses(of: "nope") }
}

@Test("Selecting a translation switches the text; an unknown id is ignored")
func selectingATranslationSwitchesTheText() throws {
    let store = try TestContent.store()
    let opening = VerseRef(surah: 1, ayah: 1)
    let itani = store.text(for: opening)

    store.select("saheeh")
    #expect(store.selectedID == "saheeh")
    #expect(store.selected?.abbrev == "SAHEEH")
    #expect(store.text(for: opening) != itani)

    store.select("does-not-exist")
    #expect(store.selectedID == "saheeh", "an unknown id must not blank the reader")

    let restored = try TestContent.store(selecting: "ruwwad")
    #expect(restored.selectedID == "ruwwad")
    let fallback = try TestContent.store(selecting: "does-not-exist")
    #expect(fallback.selectedID == "itani")
}

@Test("A passage reads out as one string per ayah, English and Arabic alike")
func passagesReadOutAyahByAyah() throws {
    let store = try TestContent.store()
    let ikhlas = try #require(PassageRef(key: "112:1-4"))
    #expect(store.texts(for: ikhlas).count == 4)
    #expect(store.arabic(for: ikhlas).count == 4)
    #expect(store.texts(for: ikhlas).allSatisfy { !$0.containsArabicScript })
    #expect(store.arabic(for: ikhlas).allSatisfy { line in line.containsArabicScript })
    #expect(store.texts(for: ikhlas, translation: "pickthall").first?.contains("Allah") == true)
}

@Test("Registry rows carry the licence strings the Translation sheet shows verbatim")
func registryRowsCarryTheirLicences() throws {
    let store = try TestContent.store()
    #expect(store.info(for: "itani")?.copyright == "Translation by Talal Itani, ClearQuran.com")
    #expect(store.info(for: "itani")?.licence == "CC BY-ND 4.0")
    #expect(store.info(for: "pickthall")?.licence == "Public domain")
    #expect(store.info(for: "saheeh")?.attribution.hasPrefix("Saheeh International, via QuranEnc.com") == true)
    #expect(store.info(for: "ruwwad")?.attribution.hasPrefix("Ruwwad Translation Center, via QuranEnc.com") == true)
    #expect(store.info(for: "nope") == nil)
}

@Test("Loaded translations are cached until they are purged")
func loadedTranslationsAreCached() throws {
    let store = try TestContent.store()
    let first = try store.verses(of: "itani")
    let second = try store.verses(of: "itani")
    #expect(first.count == second.count)
    store.purge()
    let reloaded = try store.verses(of: "itani")
    #expect(reloaded.count == 6236)
}
