@testable import FeatureReader
import DesignSystem
import Foundation
import QuranData
import StudyContent
import Testing
import UserState

@Suite("Verse menu")
@MainActor
struct VerseMenuTests {
    // MARK: - Rows

    @Test("a verse with a study unit gets all six rows, in the original's order")
    func sixRowsWithAStudy() {
        let rows = VerseMenu.rows(study: TestStudy.ayatAlKursi)
        #expect(rows.map(\.action) == [.explain, .original, .deeper, .related, .widget, .snapshot])
        #expect(rows.map(\.title) == [
            "Explain Easier", "Original Language", "Deeper Study",
            "Related Verses", "Set as Widget Verse", "Snapshot Verse",
        ])
        #expect(rows.map(\.systemImage) == [
            "lightbulb", "character.book.closed", "book", "link", "iphone", "camera.viewfinder",
        ])
    }

    @Test("the four study rows are premium and the two utilities are free")
    func gating() {
        let rows = VerseMenu.rows(study: TestStudy.ayatAlKursi)
        let locked = rows.filter(\.isPremium).map(\.action)
        #expect(locked == [.explain, .original, .deeper, .related])
        let free = rows.filter { !$0.isPremium }.map(\.action)
        #expect(free == [.widget, .snapshot])
    }

    @Test("with no study unit only the two free rows are shown")
    func noStudyHidesTheStudyRows() {
        let rows = VerseMenu.rows(study: nil)
        #expect(rows.map(\.action) == [.widget, .snapshot])
        #expect(rows.allSatisfy { !$0.isPremium })
    }

    @Test("only the snapshot row carries a subtitle")
    func subtitles() {
        let rows = VerseMenu.rows(study: TestStudy.ayatAlKursi)
        let withSubtitles = rows.filter { $0.subtitle != nil }
        #expect(withSubtitles.map(\.action) == [.snapshot])
        #expect(withSubtitles.first?.subtitle == "Share as an image anywhere")
    }

    @Test("every row carries the accessibility identifier the brief names")
    func identifiers() {
        let identifiers = VerseMenu.rows(study: TestStudy.ayatAlKursi).map(\.identifier)
        #expect(identifiers == [
            "reader.verseMenu.explain",
            "reader.verseMenu.original",
            "reader.verseMenu.deeper",
            "reader.verseMenu.related",
            "reader.verseMenu.widget",
            "reader.verseMenu.snapshot",
        ])
    }

    // MARK: - Explain Easier

    @Test("Explain Easier prefers the simplified line and falls back to the meaning")
    func explainEasierFallsBackToMeaning() {
        #expect(VerseMenu.explainEasierText(for: TestStudy.ayatAlKursi) == TestStudy.meaning)
        let simplified = TestStudy.make(explainEasier: "God never sleeps, and nothing is outside His care.")
        #expect(
            VerseMenu.explainEasierText(for: simplified)
                == "God never sleeps, and nothing is outside His care."
        )
        #expect(VerseMenu.explainEasierText(for: nil).isEmpty)
    }

    // MARK: - Content coverage

    /// The brief's assertion: the corpus is complete, so the four study rows are never hidden
    /// in the shipped app. This walks **all 6,236 ayat** — `hasStudy(for:)` answers from the
    /// permanent per-surah key index, so it is 114 shard reads, not 6,236.
    @Test("every one of the 6,236 ayat is covered by an authored study unit")
    func everyAyahHasAStudyUnit() throws {
        let index = try TestContent.index()
        let studies = try TestContent.studies()

        var checked = 0
        var uncovered: [String] = []
        for surah in index.surahs {
            for ayah in 1 ... surah.ayahCount {
                let verse = VerseRef(surah: surah.number, ayah: ayah)
                checked += 1
                if !studies.hasStudy(for: verse) {
                    uncovered.append(verse.key)
                }
            }
        }
        #expect(checked == 6236)
        #expect(uncovered.isEmpty, "\(uncovered.count) ayat have no authored study, e.g. \(uncovered.prefix(5))")
    }

    @Test("the study unit covering Ayat al-Kursi produces the full six-row menu")
    func ayatAlKursiGetsTheStudyRows() throws {
        let studies = try TestContent.studies()
        let study = studies.study(for: VerseRef(surah: 2, ayah: 255))
        #expect(study != nil)
        #expect(VerseMenu.rows(study: study).count == 6)
    }

    // MARK: - Geometry

    /// The numbers the brief measured off the owner's screenshot, checked as the layout
    /// actually resolves them — a row pitch that drifts is a spec failure, not a look.
    @Test("the rows land on the measured grid")
    func rowGeometry() {
        #expect(VerseMenuMetrics.rowHeight == 54)
        // Icon centred on x 39: 24 pt inset plus half of a 30 pt column.
        #expect(VerseMenuMetrics.rowLeading + VerseMenuMetrics.rowIconColumn / 2 == 39)
        // Label — and the separator under it — starts at x 68.
        #expect(VerseMenuMetrics.rowLabelLeading == 68)
        #expect(VerseMenuMetrics.separatorLeading == VerseMenuMetrics.rowLabelLeading)
        // Cancel pill: x 24..115, y 266..306 on a sheet whose top edge is 249.
        #expect(VerseMenuMetrics.cancelLeading + VerseMenuMetrics.cancelWidth == 115)
        #expect(VerseMenuMetrics.cancelTop + VerseMenuMetrics.cancelHeight == 57)
    }

    /// `presentationDetents(.fraction:)` measures against the sheet's own container, not the
    /// screen, so the constant handed to it is *not* the 71.5 % the brief measured. This is
    /// the conversion, and it is asserted because getting it wrong is invisible in a unit
    /// test and 42 pt out on the simulator — which is exactly what the first capture showed.
    @Test("the detent puts the sheet's top edge on the measured 249 pt")
    func detentMatchesTheMeasurement() {
        let screen = VerseMenuMetrics.referenceSize.height
        let measuredTop = screen * (1 - VerseMenuMetrics.screenCoverage)
        #expect(abs(measuredTop - 249) < 1, "71.5 % of the screen is the brief's own 249 pt")

        let sheet = VerseMenuMetrics.detentFraction * VerseMenuMetrics.sheetContainerRatio * screen
        let top = screen - sheet
        #expect(abs(top - 249) < 1, "the detent puts the sheet's top edge at \(top), not 249")
        #expect(abs(VerseMenuMetrics.detentFraction - 0.766) < 0.002)
    }

    /// Rule 5 on a verse surface: the accent is 55-60 % of the English, never below the
    /// legibility floor the rest of the app uses.
    @Test("the verse preview's Arabic keeps the muted layer's ratio and floor")
    func versePreviewArabicSize() {
        #expect(VerseMenuMetrics.versePreviewArabic >= VerseText.arabicFloor)
        let ratio = VerseMenuMetrics.versePreviewEnglish * VerseText.arabicRatio
        #expect(VerseMenuMetrics.versePreviewArabic == max(ratio, VerseText.arabicFloor))
    }
}

// MARK: - Fixtures

enum TestStudy {
    static let meaning = "The verse states that God alone sustains all that exists."

    static func make(explainEasier: String? = nil) -> Study {
        Study(
            key: "2:255",
            title: "The Throne Verse",
            meaning: meaning,
            keyTerms: [Study.KeyTerm(arabic: "ٱلْقَيُّوم", gloss: "the Sustainer", note: "The one who upholds all things.")],
            crossReferences: [Study.CrossRef(ref: "3:2", why: "Opens with the same two names.")],
            explainEasier: explainEasier
        )
    }

    static let ayatAlKursi = make()
}
