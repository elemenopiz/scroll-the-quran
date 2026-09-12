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
        #expect(model.translationAbbreviation == "ITANI")

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
        // Using the rail is what the toast was asking for, so it retires itself.
        #expect(!model.isHintVisible)
    }

    @Test("the handoff page has nothing for the chrome to act on")
    func handoffHasNoActionableVerse() throws {
        let model = try TestContent.model(surah: 1)
        model.currentPageID = model.pages.last?.id
        #expect(model.currentPage?.kind == .handoff)
        #expect(model.currentVerse == nil)
        #expect(!model.isCurrentVerseLiked)
        #expect(!model.isCurrentVerseSaved)
    }

    @Test("switching translation on the handoff page does not throw the reader back to page 0")
    func translationSwitchKeepsTheHandoffPage() throws {
        let model = try TestContent.model(surah: 1)
        model.currentPageID = model.pages.last?.id
        model.selectTranslation("pickthall")
        #expect(model.currentPage?.kind == .handoff)
    }

    @Test("restoringSavedPosition resumes where the reader left off, and only when asked")
    func restoreIsOptIn() throws {
        let user = TestContent.userStore()
        user.setReaderPosition(VerseRef(surah: 18, ayah: 60), page: 0)

        let resuming = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: user,
            hints: EphemeralReaderHintStore(),
            surah: 1,
            restoringSavedPosition: true
        )
        #expect(resuming.surah.number == 18)
        #expect(resuming.currentPageID?.ayah == 60)

        let deterministic = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: user,
            hints: EphemeralReaderHintStore(),
            surah: 1
        )
        #expect(deterministic.surah.number == 1)

        // An explicit ayah always wins over the saved position.
        let explicit = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: user,
            hints: EphemeralReaderHintStore(),
            surah: 1,
            startAyah: 3,
            restoringSavedPosition: true
        )
        #expect(explicit.surah.number == 1)
        #expect(explicit.currentPageID?.ayah == 3)
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

/// Phase 4j. The reader used to be dropped between two pages by a rail scrub: the drag wrote
/// `currentPageID` on every tick, and a paging scroll view fed dozens of programmatic positions
/// a second settles wherever it happens to be when the writes stop.
///
/// The fix has two halves. The model's half is here: a scrub moves nothing until it is
/// released, and every programmatic move — the release, the picker, a deep link, the dice, the
/// surah handoff — goes through `move(to:)`, which publishes a `ReaderJump` for the view to
/// re-assert. The view's half (the double commit through `ScrollViewProxy`) is covered by
/// `ReaderTests.testRailScrubAlwaysLandsOnAPageBoundary` on the simulator.
@Suite("Reader jumps")
@MainActor
struct ReaderJumpTests {
    @Test("a scrub moves nothing until the finger lifts, then jumps exactly once")
    func scrubCommitsOnceOnRelease() throws {
        let model = try TestContent.model(surah: 2)
        let before = model.jumpRequest
        for ayah in [12, 40, 41, 120] {
            #expect(model.beginRailDrag(toAyah: ayah))
            #expect(model.railAyah == ayah)
            // Not one of those ticks may touch the pager.
            #expect(model.currentPageID == .opening(surah: 2))
            #expect(model.jumpRequest == before)
        }
        model.endRailDrag()
        let jump = try #require(model.jumpRequest)
        #expect(jump.id == ReaderPageID(surah: 2, ayah: 120, part: 0))
        #expect(model.currentPageID == jump.id)
        #expect(jump.token == (before?.token ?? 0) + 1)
    }

    @Test("a swipe is not a jump: the pager's own writes publish nothing to re-assert")
    func swipingPublishesNoJump() throws {
        let model = try TestContent.model(surah: 2)
        let before = model.jumpRequest
        model.currentPageID = model.pages[3].id
        #expect(model.jumpRequest == before)
    }

    @Test("two jumps to the same page are two requests")
    func repeatedJumpIsANewRequest() throws {
        let model = try TestContent.model(surah: 2)
        model.jump(toAyah: 255)
        let first = try #require(model.jumpRequest)
        model.jump(toAyah: 255)
        let second = try #require(model.jumpRequest)
        #expect(first.id == second.id)
        #expect(second.token == first.token + 1)
        #expect(first != second)
    }

    @Test("every programmatic move publishes a jump to a page that exists")
    func everyMovePublishesAJump() throws {
        let model = try TestContent.model(surah: 2)

        func assertJumped(_ label: String) throws {
            let jump = try #require(model.jumpRequest, "\(label) published no jump")
            #expect(model.currentPageID == jump.id, "\(label) moved somewhere else")
            #expect(model.pages.contains { $0.id == jump.id }, "\(label) named a page that is not in the surah")
        }

        // Opening the surah at all is a jump: the first page has to land on the boundary too.
        try assertJumped("init")

        model.jump(toAyah: 255)
        try assertJumped("the rail")

        model.open(surah: 18, ayah: 60)
        try assertJumped("the surah picker")

        model.open(verse: VerseRef(surah: 94, ayah: 5))
        try assertJumped("a deep link")

        _ = model.openRandomVerse()
        try assertJumped("the dice")

        model.selectTranslation("pickthall")
        try assertJumped("a translation change")

        model.open(surah: 1)
        model.currentPageID = model.pages.last?.id
        model.advanceToNextSurahIfNeeded()
        #expect(model.surah.number == 2)
        try assertJumped("the surah handoff")
    }

    @Test("id -> ayah -> id round trips through every page of a surah", arguments: [1, 2, 18, 112])
    func idRoundTrips(_ number: Int) throws {
        let model = try TestContent.model(surah: number)
        for page in model.pages where page.kind == .verse {
            let ayah = page.id.ayah
            model.jump(toAyah: ayah)
            let landed = try #require(model.currentPageID)
            // Always the *first* slice of the ayah, whatever slice we asked about.
            #expect(landed == ReaderPageID(surah: number, ayah: ayah, part: 0))
            #expect(model.currentPage?.railAyah == ayah)
            #expect(model.currentVerse == VerseRef(surah: number, ayah: ayah))
        }
    }

    /// 2:282, the longest ayah in the Quran, is several pages long in every translation the
    /// app ships. A scrub to it has to land on the first of them.
    @Test("a scrub to a split ayah lands on its '(1/n)' page")
    func splitAyahLandsOnItsFirstPage() throws {
        let model = try TestContent.model(surah: 2)
        let slices = model.pages.filter { $0.kind == .verse && $0.id.ayah == 282 }
        #expect(slices.count > 1, "2:282 should be split into continuation pages")

        // From above it and from below it: a scrub arrives from either direction.
        for from in [1, 286] {
            model.jump(toAyah: from)
            #expect(model.beginRailDrag(toAyah: 282))
            model.endRailDrag()
            #expect(model.currentPageID == ReaderPageID(surah: 2, ayah: 282, part: 0))
            #expect(model.currentPage?.caption == "(1/\(slices.count))")
            #expect(model.currentPage?.arabic != nil, "only the first slice carries the Arabic")
        }
    }
}
