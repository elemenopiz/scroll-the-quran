import Foundation
@testable import QuranData
import Testing

/// The Basmala rule (CLAUDE.md): the stored Uthmani text stays verbatim, and the prefix on
/// ayah 1 of surahs 2–114 except 9 is removed at render time.
@Suite("ArabicText.stripBasmala")
struct ArabicTextTests {
    /// The three spellings the Uthmani editions in the wild use.
    static let spellings = [
        "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", // sukun form (the canonical constant)
        "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ", // small-high-sukun form (what Content/ ships as 1:1)
        "بسم الله الرحمن الرحيم", // undecorated
    ]

    @Test("every spelling of the Bismillah is recognised", arguments: spellings)
    func recognisesEverySpelling(_ spelling: String) {
        #expect(ArabicText.hasBasmalaPrefix(spelling))
        #expect(ArabicText.stripBasmala(spelling).isEmpty)
    }

    @Test("a prefixed verse loses the prefix and keeps the rest", arguments: spellings)
    func stripsThePrefixOnly(_ spelling: String) {
        let verse = "الٓمٓ"
        #expect(ArabicText.stripBasmala("\(spelling) \(verse)") == verse)
    }

    @Test("text that is not the Bismillah is returned untouched")
    func leavesOtherTextAlone() {
        let ayah = "قُلْ هُوَ ٱللَّهُ أَحَدٌ"
        #expect(!ArabicText.hasBasmalaPrefix(ayah))
        #expect(ArabicText.stripBasmala(ayah) == ayah)
    }

    @Test("a partial match is not a prefix")
    func partialMatchIsNotAPrefix() {
        // "In the name of God" on its own — the skeleton stops short of the full Bismillah.
        #expect(!ArabicText.hasBasmalaPrefix("بِسْمِ ٱللَّهِ"))
        #expect(ArabicText.stripBasmala("بِسْمِ ٱللَّهِ") == "بِسْمِ ٱللَّهِ")
    }

    @Test("only ayah 1 of surahs 2–114 except 9 is ever stripped")
    func onlyTheExpectedAyahIsStripped() {
        let prefixed = "\(ArabicText.basmala) الٓمٓ"
        #expect(ArabicText.stripBasmala(prefixed, surah: 2, ayah: 1) == "الٓمٓ")
        #expect(ArabicText.stripBasmala(prefixed, surah: 114, ayah: 1) == "الٓمٓ")
        // Surah 1: the Bismillah *is* ayah 1, so it must survive.
        #expect(ArabicText.stripBasmala(ArabicText.basmala, surah: 1, ayah: 1) == ArabicText.basmala)
        // Surah 9 has no Bismillah at all.
        #expect(ArabicText.stripBasmala(prefixed, surah: 9, ayah: 1) == prefixed)
        // Any other ayah is left alone even if it somehow opens with the words.
        #expect(ArabicText.stripBasmala(prefixed, surah: 2, ayah: 2) == prefixed)
    }

    @Test("expectsBasmalaPrefix covers exactly surahs 2–114 minus 9")
    func expectationMatchesTheRule() {
        let expecting = (1 ... SurahIndex.surahCount).filter { ArabicText.expectsBasmalaPrefix(surah: $0, ayah: 1) }
        #expect(expecting.count == 112)
        #expect(!expecting.contains(1))
        #expect(!expecting.contains(9))
        #expect(expecting.first == 2)
        #expect(expecting.last == 114)
    }

    @Test("the VerseRef overload agrees with the numeric one")
    func verseRefOverloadAgrees() {
        #expect(ArabicText.expectsBasmalaPrefix(VerseRef(surah: 2, ayah: 1)))
        #expect(!ArabicText.expectsBasmalaPrefix(VerseRef(surah: 9, ayah: 1)))
        let prefixed = "\(ArabicText.basmala) الٓمٓ"
        #expect(ArabicText.stripBasmala(prefixed, verse: VerseRef(surah: 2, ayah: 1)) == "الٓمٓ")
    }

    @Test("the bundled Arabic never leaves a Bismillah inside a verse-1 line")
    func bundledTextRendersClean() throws {
        let store = try TestContent.store()
        for surah in store.index.surahs {
            let verse = VerseRef(surah: surah.number, ayah: 1)
            let arabic = try #require(store.arabic(for: verse))
            let rendered = ArabicText.stripBasmala(arabic, verse: verse)
            #expect(!rendered.isEmpty, "surah \(surah.number) ayah 1 rendered empty")
            if surah.number != 1 {
                #expect(!ArabicText.hasBasmalaPrefix(rendered), "surah \(surah.number) still carries the prefix")
            }
        }
    }

    @Test("the canonical constant matches the bundled ayah 1:1")
    func constantMatchesBundledText() throws {
        let store = try TestContent.store()
        let bundled = try #require(store.arabic(for: VerseRef(surah: 1, ayah: 1)))
        #expect(ArabicText.skeleton(bundled) == ArabicText.skeleton(ArabicText.basmala))
    }
}
