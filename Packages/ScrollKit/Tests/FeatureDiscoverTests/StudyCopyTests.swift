@testable import FeatureDiscover
import Foundation
import StudyContent
import Testing

private let sample = Study(
    key: "1:5-7",
    theme: "Guidance",
    themeId: "guidance",
    title: "The straight path",
    meaning: "The surah turns from praise to petition.",
    historicalContext: "Revealed early in Mecca.",
    keyTerms: [
        Study.KeyTerm(arabic: "ٱلصِّرَٰط", gloss: "the path", note: "A wide road, not a track."),
        Study.KeyTerm(arabic: "ٱهْدِنَا", gloss: "guide us", note: ""),
    ],
    lifeInProphetsTime: "Meccan caravans knew the word for a paved road.",
    didYouKnow: "The surah is recited in every unit of prayer.",
    theologicalSignificance: "Guidance is asked for, not assumed.",
    crossReferences: [
        Study.CrossRef(ref: "2:2", why: "The book is guidance for the mindful."),
        Study.CrossRef(ref: "6:153", why: ""),
    ],
    applyIt: "Ask for the path before asking for the destination.",
    exploreFurther: ["2:185", "17:9"]
)

@Suite("Deep Study copy formatting")
struct StudyCopyTests {
    @Test("A prose section copies as its caps title, a blank line, then the body")
    func proseSection() {
        #expect(StudyCopy.section(.meaning, of: sample) == """
        MEANING

        The surah turns from praise to petition.
        """)
        #expect(StudyCopy.section(.applyIt, of: sample) == """
        APPLY IT

        Ask for the path before asking for the destination.
        """)
    }

    @Test("Key terms copy as Arabic, gloss, then the note — never transliterated")
    func keyTerms() {
        #expect(StudyCopy.section(.keyTerms, of: sample) == """
        KEY ARABIC TERMS

        ٱلصِّرَٰط — the path
        A wide road, not a track.

        ٱهْدِنَا — guide us
        """)
    }

    @Test("Cross references copy one per line, dropping an empty reason")
    func crossReferences() {
        #expect(StudyCopy.section(.crossReferences, of: sample) == """
        RELATED VERSES

        2:2 — The book is guidance for the mindful.
        6:153
        """)
    }

    @Test("Explore further copies the bare references")
    func exploreFurther() {
        #expect(StudyCopy.section(.exploreFurther, of: sample) == """
        EXPLORE FURTHER

        2:185
        17:9
        """)
    }

    @Test("An empty section copies as just its title")
    func emptySection() {
        let bare = Study(key: "2:255", title: "Ayat al-Kursi")
        #expect(StudyCopy.section(.meaning, of: bare) == "MEANING")
        #expect(StudyCopy.body(.meaning, of: bare).isEmpty)
    }

    @Test("Copying the whole study leads with the citation and skips empty sections")
    func wholeStudy() {
        let text = StudyCopy.all(
            sample,
            reference: "Al-Fatihah 1:5-7",
            quote: "\"Guide us to the straight path.\"",
            attribution: "Translation by Talal Itani, ClearQuran.com"
        )
        let blocks = text.components(separatedBy: StudyCopy.paragraphBreak)
        #expect(blocks.first == "Al-Fatihah 1:5-7")
        #expect(blocks[1] == "\"Guide us to the straight path.\"")
        #expect(text.hasSuffix("Translation by Talal Itani, ClearQuran.com"))
        // Nine sections are populated, and the key-terms block itself contains a blank
        // line, so count the titles instead of the blocks.
        for section in StudySection.displayOrder {
            #expect(text.contains(section.displayTitle))
        }
    }

    @Test("A study with holes only copies the sections it has")
    func partialStudy() {
        let partial = Study(key: "112:1-4", title: "Say: He is God, One", meaning: "Four lines that define God.")
        let text = StudyCopy.all(partial, reference: "Al-Ikhlas 112:1-4", quote: "\"Say, He is God, One.\"")
        #expect(text == """
        Al-Ikhlas 112:1-4

        "Say, He is God, One."

        MEANING

        Four lines that define God.
        """)
    }

    @Test("The Discover card share text is citation, ayah, credit")
    func cardCopy() {
        #expect(StudyCopy.card(
            reference: "Al-Ikhlas 112:1-4",
            quote: "\"Say, He is God, One.\"",
            attribution: "ClearQuran"
        ) == """
        Al-Ikhlas 112:1-4

        "Say, He is God, One."

        ClearQuran
        """)
        #expect(StudyCopy.card(reference: "Al-Ikhlas 112:1-4", quote: "") == "Al-Ikhlas 112:1-4")
    }
}
