import Foundation
@testable import QuranData
import Testing

@Test("SurahIndex loads all 114 surahs from Content/quran/surahs.json")
func surahIndexLoadsTheBundledSurahs() throws {
    let index = try TestContent.index()
    #expect(index.count == SurahIndex.surahCount)
    #expect(index.surahs.reduce(0) { $0 + $1.ayahCount } == SurahIndex.totalAyat)
    #expect(index[1]?.name == "Al-Fatiha")
    #expect(index[114]?.name == "An-Nas")
    #expect(index[0] == nil)
    #expect(index[115] == nil)
}

@Test("Global indices run 0...6235, and 2:255 lands on 261")
func globalIndicesCoverEveryAyahExactlyOnce() throws {
    let index = try TestContent.index()
    #expect(index.globalIndex(of: VerseRef(surah: 1, ayah: 1)) == 0)
    #expect(index.globalIndex(of: VerseRef(surah: 2, ayah: 255)) == 261)
    #expect(index.globalIndex(of: VerseRef(surah: 114, ayah: 6)) == 6235)
    #expect(index.globalIndex(of: VerseRef(surah: 2, ayah: 287)) == nil)
    #expect(index.globalIndex(of: VerseRef(surah: 115, ayah: 1)) == nil)

    var seen = 0
    for surah in index.surahs {
        for ayah in 1 ... surah.ayahCount {
            let ref = VerseRef(surah: surah.number, ayah: ayah)
            guard let position = index.globalIndex(of: ref) else {
                Issue.record("no global index for \(ref.key)")
                continue
            }
            #expect(position == seen)
            #expect(index.verse(atGlobalIndex: position) == ref)
            seen += 1
        }
    }
    #expect(seen == SurahIndex.totalAyat)
    #expect(index.verse(atGlobalIndex: -1) == nil)
    #expect(index.verse(atGlobalIndex: SurahIndex.totalAyat) == nil)
}

@Test("Surahs answer to their name, their article-less name, their meaning and their number")
func surahLookupByNameIsForgiving() throws {
    let index = try TestContent.index()
    for spelling in ["Al-Baqarah", "al-baqarah", "al baqarah", "Baqarah", "  AL-BAQARAH ", "Surah Al-Baqarah", "The Cow", "2"] {
        #expect(index.surah(named: spelling)?.number == 2, "'\(spelling)' did not resolve to Al-Baqarah")
    }
    #expect(index.surah(named: "An-Nas")?.number == 114)
    #expect(index.surah(named: "Nas")?.number == 114)
    #expect(index.surah(named: "Al-Ma'idah")?.number == 5)
    #expect(index.surah(named: "al maidah")?.number == 5)
    #expect(index.surah(named: "Ikhlas")?.number == 112)
    #expect(index.surah(named: "Definitely Not A Surah") == nil)
    #expect(index.surah(named: "0") == nil)
}

@Test("Reading order walks across surah boundaries and stops at both ends")
func readingOrderCrossesSurahs() throws {
    let index = try TestContent.index()
    #expect(index.next(after: VerseRef(surah: 1, ayah: 7)) == VerseRef(surah: 2, ayah: 1))
    #expect(index.previous(before: VerseRef(surah: 2, ayah: 1)) == VerseRef(surah: 1, ayah: 7))
    #expect(index.previous(before: VerseRef(surah: 1, ayah: 1)) == nil)
    #expect(index.next(after: VerseRef(surah: 114, ayah: 6)) == nil)
    #expect(index.surah(containingGlobalIndex: 261)?.number == 2)
    #expect(index.surah(containingGlobalIndex: 6235)?.number == 114)
}

@Test("Surah presentation helpers spell out the name, the juz span and the citation")
func surahPresentationHelpers() throws {
    let index = try TestContent.index()
    let baqarah = try #require(index[2])
    #expect(baqarah.displayName == "Surah Al-Baqarah")
    #expect(baqarah.subtitle == "The Cow · 286 verses · Medinan")
    #expect(baqarah.juzRange == 1 ... 3)
    #expect(baqarah.reference(for: 255) == "Al-Baqarah 2:255")
    #expect(baqarah.reference(for: PassageRef(surah: 2, start: 285, end: 286)) == "Al-Baqarah 2:285-286")
    #expect(baqarah.endIndex == baqarah.startIndex + 286)
    #expect(baqarah.contains(ayah: 286))
    #expect(!baqarah.contains(ayah: 287))
    let fatiha = try #require(index[1])
    #expect(fatiha.juzRange == 1 ... 1)
    let nas = try #require(index[114])
    #expect(nas.verses.count == 6)
}

@Test("A surah list that does not add up is rejected")
func malformedIndexIsRejected() throws {
    let fatiha = Surah(
        number: 1, name: "Al-Fatiha", meaning: "The Opening",
        ayahCount: 7, revelation: .meccan, startIndex: 0, juz: [1]
    )
    let misplaced = Surah(
        number: 2, name: "Al-Baqarah", meaning: "The Cow",
        ayahCount: 286, revelation: .medinan, startIndex: 99, juz: [1, 2, 3]
    )
    #expect(throws: QuranDataError.self) { try SurahIndex(surahs: [fatiha, misplaced]) }
    #expect(throws: QuranDataError.self) { try SurahIndex(surahs: [misplaced]) }
    #expect(throws: Never.self) { try SurahIndex(surahs: [fatiha]) }
}

@Test("Both revelation spellings decode, and the JSON spelling is what comes back out")
func revelationSpellingsDecode() throws {
    #expect(Surah.Revelation.parse("Meccan") == .meccan)
    #expect(Surah.Revelation.parse("makki") == .meccan)
    #expect(Surah.Revelation.parse("MADANI") == .medinan)
    #expect(Surah.Revelation.parse("Medinan") == .medinan)
    #expect(Surah.Revelation.parse("nowhere") == nil)
    #expect(Surah.Revelation.meccan.rawValue == "Meccan")

    let json = Data(#"""
    [{"number":1,"name":"Al-Fatiha","meaning":"The Opening","ayahCount":7,"revelation":"makki","startIndex":0,"juz":[1]}]
    """#.utf8)
    let decoded = try JSONDecoder().decode([Surah].self, from: json)
    #expect(decoded.first?.revelation == .meccan)
}
