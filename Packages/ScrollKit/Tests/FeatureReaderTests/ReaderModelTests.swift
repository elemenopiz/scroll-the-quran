@testable import FeatureReader
import Foundation
import QuranData
import Testing
import UserState

@Suite("ReaderModel")
@MainActor
struct ReaderModelTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("opens on the surah's page 0")
    func opensOnPageZero() throws {
        let model = try TestContent.model(surah: 2)
        #expect(model.surah.number == 2)
        #expect(model.currentPage?.kind == .opening)
        #expect(model.currentPageID == .opening(surah: 2))
        #expect(model.railAyah == 1)
    }

    @Test("startAyah parks the reader on that ayah's first page")
    func startAyahIsHonoured() throws {
        let model = try TestContent.model(surah: 2, startAyah: 255)
        #expect(model.currentPageID?.ayah == 255)
        #expect(model.currentPageID?.part == 0)
        #expect(model.currentVerse == VerseRef(surah: 2, ayah: 255))
    }

    @Test("jumping clamps to the surah")
    func jumpClamps() throws {
        let model = try TestContent.model(surah: 112)
        model.jump(toAyah: 99)
        #expect(model.currentPageID?.ayah == 4)
        model.jump(toAyah: -3)
        #expect(model.currentPageID?.ayah == 1)
    }

    @Test("three pages forward from the opening page is ayah 3")
    func threePagesForwardIsAyahThree() throws {
        let model = try TestContent.model(surah: 2)
        let ids = model.pages.map(\.id)
        model.currentPageID = ids[3]
        #expect(model.currentPage?.id.ayah == 3)
        #expect(model.railAyah == 3)
    }

    @Test("an ayah is marked read after the 1.2 s dwell, and only then")
    func dwellMarksRead() throws {
        let model = try TestContent.model(surah: 2, startAyah: 2)
        let verse = VerseRef(surah: 2, ayah: 2)
        model.pageChanged(to: model.currentPageID, now: Self.now)
        #expect(model.settleDwell(now: Self.now.addingTimeInterval(1.0)) == nil)
        #expect(!model.user.progress.isRead(verse, in: model.span))
        #expect(model.settleDwell(now: Self.now.addingTimeInterval(1.3)) == verse)
        #expect(model.user.progress.isRead(verse, in: model.span))
    }

    @Test("the opening page and the handoff page are never marked read")
    func nonVersePagesAreNotMarked() throws {
        let model = try TestContent.model(surah: 2)
        model.pageChanged(to: model.currentPageID, now: Self.now)
        #expect(model.settleDwell(now: Self.now.addingTimeInterval(5)) == nil)
        #expect(model.user.progress.readCount == 0)

        model.currentPageID = model.pages.last?.id
        model.pageChanged(to: model.currentPageID, now: Self.now)
        #expect(model.settleDwell(now: Self.now.addingTimeInterval(5)) == nil)
        #expect(model.user.progress.readCount == 0)
    }

    @Test("paging remembers the position, and a fresh model restores it")
    func positionRoundTrips() throws {
        let model = try TestContent.model(surah: 2, startAyah: 10)
        model.pageChanged(to: model.currentPageID, now: Self.now)
        let saved = try #require(model.user.lastReaderPosition)
        #expect(saved.verse == VerseRef(surah: 2, ayah: 10))

        let restored = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: model.user,
            hints: EphemeralReaderHintStore(),
            surah: 1
        )
        restored.restoreSavedPosition()
        #expect(restored.surah.number == 2)
        #expect(restored.currentPageID?.ayah == 10)
    }

    @Test("the handoff page moves on to the next surah's opening page")
    func handoffAdvances() throws {
        let model = try TestContent.model(surah: 1)
        model.currentPageID = model.pages.last?.id
        #expect(model.currentPage?.kind == .handoff)
        model.advanceToNextSurahIfNeeded()
        #expect(model.surah.number == 2)
        #expect(model.currentPage?.kind == .opening)
    }

    @Test("the last surah has nothing to advance to")
    func lastSurahDoesNotAdvance() throws {
        let model = try TestContent.model(surah: 114)
        #expect(model.pages.last?.kind == .verse)
        model.currentPageID = model.pages.last?.id
        model.advanceToNextSurahIfNeeded()
        #expect(model.surah.number == 114)
    }

    @Test("switching translation changes the text, persists the choice and re-paginates")
    func switchingTranslation() throws {
        let model = try TestContent.model(surah: 2, startAyah: 255)
        let before = try #require(model.currentPage?.english)
        #expect(model.translationAbbreviation == "CLEAR")

        model.selectTranslation("pickthall")
        let after = try #require(model.currentPage?.english)
        #expect(after != before)
        #expect(model.translationAbbreviation == "PICKTHALL")
        #expect(model.user.translationID == "pickthall")
        // Still parked on the same ayah after the rebuild.
        #expect(model.currentPageID?.ayah == 255)

        // An unknown id is ignored rather than blanking the reader.
        model.selectTranslation("nope")
        #expect(model.translations.selectedID == "pickthall")
    }

    @Test("the heart and the bookmark toggle the current ayah")
    func likeAndSaveToggle() throws {
        let model = try TestContent.model(surah: 2, startAyah: 255)
        let verse = VerseRef(surah: 2, ayah: 255)
        #expect(!model.isCurrentVerseLiked)
        model.toggleLike()
        #expect(model.isCurrentVerseLiked)
        #expect(model.user.isLiked(verse))
        model.toggleSaved()
        #expect(model.isCurrentVerseSaved)
        #expect(model.user.isSaved(verse))
    }

    @Test("notes autosave against the verse the sheet was opened on")
    func notesAutosave() throws {
        let model = try TestContent.model(surah: 2, startAyah: 255)
        model.present(.notes)
        #expect(model.focusedVerse == VerseRef(surah: 2, ayah: 255))
        #expect(model.focusedNote.isEmpty)
        model.saveNote("Ayat al-Kursi")
        #expect(model.focusedNote == "Ayat al-Kursi")
        #expect(model.user.note(for: "2:255")?.text == "Ayat al-Kursi")
        // Clearing the field deletes the note.
        model.saveNote("   ")
        #expect(model.user.note(for: "2:255") == nil)
    }

    @Test("a rail drag tracks the finger and only commits on release")
    func railDragCommitsOnRelease() throws {
        let model = try TestContent.model(surah: 2)
        #expect(model.beginRailDrag(toAyah: 40))
        #expect(model.railAyah == 40)
        // Nothing has moved yet.
        #expect(model.currentPage?.kind == .opening)
        // The same ayah again is not a change, so no haptic tick.
        #expect(!model.beginRailDrag(toAyah: 40))
        model.endRailDrag()
        #expect(model.currentPageID?.ayah == 40)
        #expect(model.railDragAyah == nil)
    }

    @Test("the dice lands on a real ayah and opens it")
    func diceOpensARealAyah() throws {
        let model = try TestContent.model(surah: 2)
        let verse = try #require(model.openRandomVerse())
        #expect(model.index.contains(verse))
        #expect(model.surah.number == verse.surah)
        #expect(model.currentPageID?.ayah == verse.ayah)
    }

    @Test("the hint shows once and stays dismissed")
    func hintShowsOnce() throws {
        let hints = EphemeralReaderHintStore()
        let model = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: TestContent.userStore(),
            hints: hints,
            surah: 2
        )
        #expect(model.isHintVisible)
        model.dismissHint()
        #expect(!model.isHintVisible)
        #expect(hints.hasSeenRailHint)

        let second = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: TestContent.userStore(),
            hints: hints,
            surah: 2
        )
        #expect(!second.isHintVisible)
    }

    @Test("the verse text helpers apply the Basmala rule")
    func verseHelpersStripTheBasmala() throws {
        let model = try TestContent.model(surah: 2)
        let arabic = try #require(model.arabic(for: VerseRef(surah: 2, ayah: 1)))
        #expect(!ArabicText.hasBasmalaPrefix(arabic))
        #expect(model.reference(for: VerseRef(surah: 2, ayah: 255)) == "Al-Baqarah 2:255")
        #expect(!model.english(for: VerseRef(surah: 2, ayah: 255)).isEmpty)
    }
}
