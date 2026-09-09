import Foundation
@testable import QuranData
import Testing

/// A page may only end mid-sentence when it is the last one.
private let sentenceEnders: Set<Character> = [".", ";", "?", "!", "\"", ")", "”", "'"]

private func endsCleanly(_ page: String) -> Bool {
    guard let last = page.last else { return false }
    return sentenceEnders.contains(last)
}

@Test("2:282, the longest ayah, splits into at least three pages that never cut a sentence")
func longestAyahPaginates() throws {
    let index = try TestContent.index()
    let position = try #require(index.globalIndex(of: VerseRef(surah: 2, ayah: 282)))

    for file in ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"] {
        let text = try TestContent.verses(file)[position]
        #expect(text.wordCount > 200, "\(file): 2:282 should be the long one")

        let pages = VersePaginator.pages(text: text, maxWords: 110)
        #expect(pages.count >= 3, "\(file): 2:282 made only \(pages.count) page(s)")
        for page in pages {
            #expect(page.wordCount <= 120, "\(file): a page ran to \(page.wordCount) words")
            #expect(!page.isEmpty)
        }
        for page in pages.dropLast() {
            #expect(endsCleanly(page), "\(file): a page ends mid-sentence: …\(page.suffix(40))")
        }
        #expect(pages.joined(separator: " ") == VersePaginator.normalized(text), "\(file): pagination lost words")
    }
}

@Test("4:12 and 5:3, the other long ayat, paginate within the limit and lose nothing")
func otherLongAyatPaginate() throws {
    let index = try TestContent.index()
    for key in ["4:12", "5:3"] {
        let ref = try #require(VerseRef(key: key))
        let position = try #require(index.globalIndex(of: ref))
        for file in ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"] {
            let text = try TestContent.verses(file)[position]
            let pages = VersePaginator.pages(text: text, maxWords: 110)
            #expect(!pages.isEmpty)
            #expect(pages.allSatisfy { $0.wordCount <= 120 }, "\(file) \(key): \(pages.map(\.wordCount))")
            for page in pages.dropLast() {
                #expect(endsCleanly(page), "\(file) \(key): a page ends mid-sentence")
            }
            #expect(pages.joined(separator: " ") == VersePaginator.normalized(text))
        }
    }
}

@Test("A verse that fits comes back as one page, whitespace normalised, otherwise untouched")
func shortVersesAreNotSplit() {
    let short = "God! There is no god except He, the Living, the Everlasting."
    #expect(VersePaginator.pages(text: short) == [short])
    #expect(VersePaginator.pages(text: "  spaced   out \n text  ") == ["spaced out text"])
    #expect(VersePaginator.pages(text: "   ").isEmpty)
    #expect(VersePaginator.pages(text: "").isEmpty)
}

@Test("Pages break at sentence boundaries, not at every full stop")
func pagesBreakOnSentences() {
    let text = "One two three four five. Six seven eight nine ten. Eleven twelve thirteen fourteen fifteen."
    let pages = VersePaginator.pages(text: text, maxWords: 5)
    #expect(pages == [
        "One two three four five.",
        "Six seven eight nine ten.",
        "Eleven twelve thirteen fourteen fifteen.",
    ])
    // A decimal point is not a sentence boundary: no space follows it.
    let decimals = "The share is 3.5 of the whole and the rest is 6.5 of it."
    #expect(VersePaginator.pages(text: decimals, maxWords: 100) == [decimals])
}

@Test("A sentence longer than the limit falls back to clause breaks, then to words")
func oversizedSentencesFallBack() {
    let clauses = "alpha beta gamma, delta epsilon zeta, eta theta iota, kappa lambda mu"
    let pages = VersePaginator.pages(text: clauses, maxWords: 6)
    #expect(pages.count == 2)
    #expect(pages.allSatisfy { $0.wordCount <= 6 })
    #expect(pages.joined(separator: " ") == clauses)

    let unbroken = (1 ... 30).map { "word\($0)" }.joined(separator: " ")
    let hard = VersePaginator.pages(text: unbroken, maxWords: 10)
    #expect(hard.count == 3)
    #expect(hard.allSatisfy { $0.wordCount == 10 })
    #expect(hard.joined(separator: " ") == unbroken)
}

@Test("Continuation captions count from one and stay silent for a single page")
func continuationCaptions() {
    #expect(VersePaginator.caption(page: 2, of: 3) == "(2/3)")
    #expect(VersePaginator.caption(page: 1, of: 1) == nil)
}

@Test("Size tiers switch at 40 and 90 words")
func sizeTiersHaveTheRightBoundaries() {
    #expect(VerseSizeTier(wordCount: 1) == .large)
    #expect(VerseSizeTier(wordCount: 40) == .large)
    #expect(VerseSizeTier(wordCount: 41) == .medium)
    #expect(VerseSizeTier(wordCount: 90) == .medium)
    #expect(VerseSizeTier(wordCount: 91) == .small)
    #expect(VerseSizeTier(text: "In the name of God, the Gracious, the Merciful") == .large)
    #expect(VerseSizeTier(text: (1 ... 100).map(String.init).joined(separator: " ")) == .small)
}

@Test("Every ayah of every bundled translation paginates to pages within the limit")
func everyAyahPaginatesWithinTheLimit() throws {
    for file in ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"] {
        var worst = 0
        for text in try TestContent.verses(file) {
            for page in VersePaginator.pages(text: text) {
                worst = max(worst, page.wordCount)
            }
        }
        #expect(worst <= 110, "\(file): the longest page is \(worst) words")
    }
}
