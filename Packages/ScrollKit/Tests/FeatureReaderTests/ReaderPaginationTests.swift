@testable import FeatureReader
import Foundation
import QuranData
import Testing

@Suite("Reader pagination")
struct ReaderPaginationTests {
    static func surah(_ number: Int, ayahCount: Int) -> Surah {
        Surah(
            number: number, name: "Test\(number)", meaning: "Test",
            ayahCount: ayahCount, revelation: .meccan, startIndex: 0
        )
    }

    @Test("the first page is the opening card, then one page per ayah, then the handoff")
    func pageShape() {
        let pages = ReaderPagination.pages(
            for: Self.surah(2, ayahCount: 3),
            source: .fixture { "Ayah \($0.ayah)." }
        )
        #expect(pages.count == 5)
        #expect(pages[0].kind == .opening)
        #expect(pages[0].showsLogoCard)
        #expect(pages[1 ... 3].allSatisfy { $0.kind == .verse })
        #expect(pages.map(\.id.ayah) == [0, 1, 2, 3, 4])
        #expect(pages.last?.kind == .handoff)
    }

    /// Phase 4n: the logo card is the verse menu's tap target, so it is on every page the
    /// reader can act from — the opening card and every slice of every ayah — and on none of
    /// the handoff sentinel, which is on screen for one frame and has no ayah.
    @Test("every verse page carries the logo card, and the handoff sentinel does not")
    func logoCardOnEveryPage() {
        let pages = ReaderPagination.pages(
            for: Self.surah(2, ayahCount: 3),
            // 12 words at a 5-word limit, so ayah 1 splits into three continuation pages.
            source: .fixture { verse in
                verse.ayah == 1 ? String(repeating: "word ", count: 12) : "Ayah \(verse.ayah)."
            },
            maxWords: 5
        )
        let split = pages.filter { $0.kind == .verse && $0.id.ayah == 1 }
        #expect(split.count > 1, "the fixture must split ayah 1 for this test to mean anything")
        #expect(pages.filter { $0.kind != .handoff }.allSatisfy { $0.showsLogoCard })
        #expect(pages.filter { $0.kind == .handoff }.allSatisfy { !$0.showsLogoCard })
    }

    @Test("the last surah has no handoff page")
    func lastSurahHasNoHandoff() {
        let pages = ReaderPagination.pages(
            for: Self.surah(114, ayahCount: 2),
            source: .fixture { "Ayah \($0.ayah)." },
            hasFollowingSurah: false
        )
        #expect(pages.count == 3)
        #expect(pages.last?.kind == .verse)
    }

    @Test("the opening page carries the Bismillah for surahs 2-114 except 9")
    func openingCarriesBasmala() {
        let source = ReaderPagination.Source.fixture { _ in "Some ayah." }
        let baqarah = ReaderPagination.opening(for: Self.surah(2, ayahCount: 286), source: source)
        #expect(baqarah.arabic == ArabicText.basmala)
        #expect(!baqarah.english.isEmpty)

        for number in [1, 9] {
            let page = ReaderPagination.opening(for: Self.surah(number, ayahCount: 7), source: source)
            #expect(page.arabic == nil, "surah \(number) must not open with a Bismillah")
            #expect(page.english.isEmpty)
            #expect(page.showsLogoCard)
        }
    }

    @Test("the opening page's English comes from the selected translation's 1:1")
    func openingEnglishFollowsTheTranslation() {
        let source = ReaderPagination.Source.fixture { verse in
            verse == VerseRef(surah: 1, ayah: 1) ? "In the name of Allah, Most Gracious" : "Body"
        }
        let page = ReaderPagination.opening(for: Self.surah(2, ayahCount: 5), source: source)
        #expect(page.english == "In the name of Allah, Most Gracious")
    }

    @Test("a leading Bismillah never survives into the verse-1 line")
    func verseOneIsStripped() throws {
        let source = ReaderPagination.Source(
            arabic: { _ in "\(ArabicText.basmala) الٓمٓ" },
            english: { "Ayah \($0.ayah)." }
        )
        let pages = ReaderPagination.pages(for: Self.surah(2, ayahCount: 2), source: source)
        let first = try #require(pages.first { $0.kind == .verse })
        #expect(first.arabic == "الٓمٓ")
    }

    @Test("a long ayah splits into captioned continuation pages, Arabic on the first only")
    func longAyahSplits() throws {
        let long = (1 ... 12).map { _ in "Some words that keep on going for a while." }.joined(separator: " ")
        let source = ReaderPagination.Source.fixture { $0.ayah == 1 ? long : "Short." }
        let pages = ReaderPagination.pages(
            for: Self.surah(2, ayahCount: 2),
            source: source,
            maxWords: 20
        )
        let slices = pages.filter { $0.id.ayah == 1 }
        #expect(slices.count > 1)
        #expect(slices[0].caption == "(1/\(slices.count))")
        #expect(slices[0].arabic != nil)
        #expect(slices.dropFirst().allSatisfy { $0.arabic == nil })
        #expect(slices.allSatisfy { $0.tier == .small })
        // Every slice keeps the ayah's own reference line.
        #expect(Set(slices.map(\.reference)).count == 1)

        // A short ayah gets no caption.
        let short = try #require(pages.first { $0.id.ayah == 2 })
        #expect(short.caption == nil)
    }

    @Test("the opening page's rail segment is ayah 1, as in reader-dark.png")
    func openingLightsTheFirstSegment() {
        let pages = ReaderPagination.pages(for: Self.surah(2, ayahCount: 5), source: .fixture { _ in "Ayah." })
        #expect(pages[0].railAyah == 1)
        #expect(pages[0].actionableVerse == nil)
        #expect(pages[1].actionableVerse == VerseRef(surah: 2, ayah: 1))
        #expect(pages.last?.railAyah == 5)
    }

    @Test("the bundled surahs all paginate", arguments: [1, 2, 9, 18, 108, 114])
    func bundledSurahsPaginate(_ number: Int) throws {
        let index = try TestContent.index()
        let store = try TestContent.translations()
        let surah = try #require(index.surah(number))
        let pages = ReaderPagination.pages(
            for: surah,
            source: .store(store),
            hasFollowingSurah: number < index.count
        )
        // Opening page + at least one page per ayah (+ handoff where there is one).
        #expect(pages.count >= surah.ayahCount + 1)
        #expect(pages.filter { $0.kind == .verse }.count >= surah.ayahCount)
        #expect(pages.allSatisfy { $0.kind != .verse || !$0.english.isEmpty })
        // No verse page opens with the Bismillah — except surah 1, where it *is* ayah 1.
        if number != 1 {
            #expect(pages.allSatisfy { page in
                page.kind != .verse || !(page.arabic.map(ArabicText.hasBasmalaPrefix) ?? false)
            })
        }
    }
}

@Suite("Size tiers and the type ramp")
struct ReaderTypeRampTests {
    @Test(
        "word count picks the tier",
        arguments: [(1, VerseSizeTier.large), (40, .large), (41, .medium), (90, .medium), (91, .small), (300, .small)]
    )
    func tierByWordCount(_ words: Int, _ expected: VerseSizeTier) {
        let text = Array(repeating: "word", count: words).joined(separator: " ")
        #expect(VerseSizeTier(text: text) == expected)
        #expect(VerseSizeTier(wordCount: words) == expected)
    }

    @Test("each tier maps to a measured VerseText size, and the ramp only ever steps down")
    func rampStepsDown() {
        #expect(ReaderTypeRamp.size(for: .large) == .reader)
        #expect(ReaderTypeRamp.size(for: .medium) == .deepStudy)
        #expect(ReaderTypeRamp.size(for: .small) == .discover)
        let sizes = [VerseSizeTier.large, .medium, .small].map(ReaderTypeRamp.englishPointSize(for:))
        #expect(sizes == [23, 20, 16])
        #expect(sizes == sizes.sorted(by: >))
    }

    @Test("the bundled Al-Baqarah uses every tier")
    func bundledSurahUsesTheWholeRamp() throws {
        let index = try TestContent.index()
        let store = try TestContent.translations()
        let surah = try #require(index.surah(2))
        let pages = ReaderPagination.pages(for: surah, source: .store(store))
        let tiers = Set(pages.filter { $0.kind == .verse }.map(\.tier))
        #expect(tiers == Set(VerseSizeTier.allCases))
    }
}
