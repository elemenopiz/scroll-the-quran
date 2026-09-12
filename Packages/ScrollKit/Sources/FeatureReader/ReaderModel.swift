import Foundation
import Observation
import QuranData
import UserState

/// Which sheet the reader is showing, if any.
public enum ReaderSheet: String, Identifiable, Hashable, Sendable {
    case translation
    case notes
    case surahPicker
    case share

    public var id: String {
        rawValue
    }
}

/// The reader's state machine: which surah is open, the pages it is made of, where the reader
/// is inside it, and every side effect that paging causes (marking read, remembering the
/// position, handing over to the next surah).
///
/// Views own none of this. Everything here is exercised by `FeatureReaderTests` against a
/// `MemoryUserStateFileStore`, with no view and no simulator.
@MainActor
@Observable
public final class ReaderModel {
    // MARK: Dependencies

    public let index: SurahIndex
    public let translations: TranslationStore
    public let user: UserStore
    @ObservationIgnored public let hints: any ReaderHintStore

    // MARK: State

    public private(set) var surah: Surah
    public private(set) var pages: [ReaderPage] = []
    /// The page the pager is showing. Bound to `.scrollPosition(id:)`.
    public var currentPageID: ReaderPageID?
    public var sheet: ReaderSheet?
    /// The verse the notes and share sheets are about; the current ayah when they opened.
    public private(set) var focusedVerse: VerseRef?
    public private(set) var isHintVisible: Bool
    /// Set while a rail drag is in flight, so the indicator follows the finger without the
    /// pager's own animation fighting it.
    public private(set) var railDragAyah: Int?

    @ObservationIgnored private var dwell = DwellTracker()
    /// `pages` by id. The chrome asks for `currentPage` several times per render and the rail
    /// asks once per drag tick, so the lookup must not be a scan of 287 pages.
    @ObservationIgnored private var pageIndex: [ReaderPageID: Int] = [:]

    // MARK: Init

    public init(
        index: SurahIndex,
        translations: TranslationStore,
        user: UserStore,
        hints: (any ReaderHintStore)? = nil,
        surah: Int = 1,
        startAyah: Int? = nil,
        restoringSavedPosition: Bool = false
    ) {
        self.index = index
        self.translations = translations
        self.user = user
        let hints = hints ?? UserDefaultsReaderHintStore()
        self.hints = hints
        let resolved = index.surah(surah) ?? index.surahs.first ?? Surah(
            number: 1, name: "Al-Fatiha", meaning: "The Opening",
            ayahCount: 7, revelation: .meccan, startIndex: 0
        )
        self.surah = resolved
        isHintVisible = !hints.hasSeenRailHint
        rebuildPages(startAyah: startAyah)
        if restoringSavedPosition, startAyah == nil {
            restoreSavedPosition()
        }
    }

    // MARK: Pages

    /// Rebuilds the page list for the open surah and parks the reader on `startAyah`.
    /// A nil ayah means the surah's opening page — what opening a surah normally shows.
    public func rebuildPages(startAyah: Int?) {
        pages = ReaderPagination.pages(
            for: surah,
            source: .store(translations),
            hasFollowingSurah: surah.number < index.count
        )
        pageIndex = Dictionary(uniqueKeysWithValues: pages.enumerated().map { ($1.id, $0) })
        currentPageID = pageID(forAyah: startAyah) ?? pages.first?.id
    }

    /// Re-paginates without moving: used when the translation changes under the reader.
    ///
    /// Only a real ayah is worth returning to. The opening card and the handoff sentinel both
    /// resolve to no verse page, and following them through `pageID(forAyah:)` would land the
    /// reader back on page 0 — so they stay where they are instead.
    public func rebuildPagesInPlace() {
        let previous = currentPageID
        let ayah = previous.flatMap { id in
            (1 ... surah.ayahCount).contains(id.ayah) ? id.ayah : nil
        }
        rebuildPages(startAyah: ayah)
        // The opening card and the handoff sentinel keep their ids across a re-pagination,
        // so land back on whichever of them was showing rather than snapping to page 0. A
        // split ayah does restart at its first slice: another translation splits differently.
        if ayah == nil, let previous, pageIndex[previous] != nil {
            currentPageID = previous
        }
    }

    /// The page currently on screen.
    public var currentPage: ReaderPage? {
        guard let currentPageID, let offset = pageIndex[currentPageID] else { return pages.first }
        return pages[offset]
    }

    /// The ayah the chrome acts on. On a verse page it is that ayah; on the opening card it is
    /// ayah 1, which is the segment the rail lights and the ayah the reference app's chrome
    /// acts on there. On the handoff sentinel there is nothing to act on — it is on screen for
    /// one frame before the next surah opens.
    public var currentVerse: VerseRef? {
        switch currentPage?.kind {
        case .verse: currentPage?.actionableVerse
        case .opening: VerseRef(surah: surah.number, ayah: 1)
        case .handoff, nil: nil
        }
    }

    /// Which rail segment is lit.
    public var railAyah: Int {
        railDragAyah ?? currentPage?.railAyah ?? 1
    }

    /// The first page of an ayah, which is where a jump always lands.
    public func pageID(forAyah ayah: Int?) -> ReaderPageID? {
        guard let ayah else { return nil }
        if ayah <= 0 {
            return pages.first?.id
        }
        return pages.first { $0.kind == .verse && $0.id.ayah == ayah }?.id
    }

    // MARK: Navigation

    /// Jumps to an ayah of the open surah — the rail's tap and drag, and the surah picker.
    public func jump(toAyah ayah: Int) {
        guard let id = pageID(forAyah: min(max(ayah, 1), surah.ayahCount)) else { return }
        currentPageID = id
    }

    /// Opens another surah at `ayah`. Resets the dwell bookkeeping: a new surah is a new
    /// reading session as far as "have I already marked this?" is concerned.
    public func open(surah number: Int, ayah: Int? = nil) {
        guard let next = index.surah(number) else { return }
        surah = next
        dwell.reset()
        railDragAyah = nil
        rebuildPages(startAyah: ayah)
        rememberPosition()
    }

    public func open(verse: VerseRef) {
        open(surah: verse.surah, ayah: verse.ayah)
    }

    /// Scrolling onto the handoff page moves to the next surah's opening page.
    public func advanceToNextSurahIfNeeded() {
        guard currentPage?.kind == .handoff, surah.number < index.count else { return }
        open(surah: surah.number + 1)
    }

    /// Restores `Prefs.lastReaderPosition`, when it points inside a surah we know.
    public func restoreSavedPosition() {
        guard let saved = user.lastReaderPosition, index.contains(saved.verse) else { return }
        open(verse: saved.verse)
    }

    /// The dice: a uniformly random ayah out of all 6,236.
    @discardableResult
    public func openRandomVerse() -> VerseRef? {
        guard let verse = RandomVerse.pick(in: index) else { return nil }
        open(verse: verse)
        return verse
    }

    // MARK: Paging side effects

    /// Called when the pager settles on a page: starts the dwell clock and records the
    /// position so a relaunch comes back here.
    public func pageChanged(to id: ReaderPageID?, now: Date = Date()) {
        dwell.arrived(at: id, now: now)
        rememberPosition()
    }

    /// How long the current page still needs before it counts as read.
    public func dwellRemaining(now: Date = Date()) -> TimeInterval {
        dwell.remaining(now: now)
    }

    /// Marks the current page's ayah read if it has been still long enough. Returns the ayah
    /// that was marked, so tests and the UI can assert on it.
    @discardableResult
    public func settleDwell(now: Date = Date()) -> VerseRef? {
        guard let settled = dwell.settle(now: now) else { return nil }
        // Only a real ayah counts: the opening card and the handoff sentinel are not reading.
        guard let offset = pageIndex[settled], let verse = pages[offset].actionableVerse else { return nil }
        user.markRead(verse, in: span)
        return verse
    }

    private func rememberPosition() {
        guard let page = currentPage else { return }
        let verse = page.actionableVerse ?? VerseRef(surah: surah.number, ayah: 1)
        user.setReaderPosition(verse, page: page.id.part)
    }

    /// The open surah's slice of the flat 6,236-verse index.
    public var span: SurahSpan {
        SurahSpan(number: surah.number, startIndex: surah.startIndex, ayahCount: surah.ayahCount)
    }

    // MARK: Rail interaction

    public func beginRailDrag(toAyah ayah: Int) -> Bool {
        let clamped = min(max(ayah, 1), surah.ayahCount)
        guard clamped != railDragAyah else { return false }
        railDragAyah = clamped
        return true
    }

    public func endRailDrag() {
        if let ayah = railDragAyah {
            jump(toAyah: ayah)
            // The toast asked the reader to tap or slide; they have, so it has done its job.
            dismissHint()
        }
        railDragAyah = nil
    }

    // MARK: Chrome actions

    public var isCurrentVerseLiked: Bool {
        currentVerse.map { user.isLiked($0) } ?? false
    }

    public var isCurrentVerseSaved: Bool {
        currentVerse.map { user.isSaved($0) } ?? false
    }

    public func toggleLike() {
        guard let verse = currentVerse else { return }
        user.toggleLiked(verse)
    }

    public func toggleSaved() {
        guard let verse = currentVerse else { return }
        user.toggleSaved(verse)
    }

    /// The abbreviation on the translation pill, e.g. `"ITANI"`.
    public var translationAbbreviation: String {
        translations.selected?.abbrev ?? translations.selectedID.uppercased()
    }

    /// Switches translation, persists the choice and re-paginates: a different translation is
    /// a different word count, so the tiers and the continuation splits both change.
    public func selectTranslation(_ id: String) {
        guard translations.registry[id] != nil, id != translations.selectedID else { return }
        translations.select(id)
        user.setTranslation(id)
        rebuildPagesInPlace()
    }

    // MARK: Sheets

    public func present(_ sheet: ReaderSheet) {
        focusedVerse = currentVerse
        self.sheet = sheet
    }

    public func dismissSheet() {
        sheet = nil
    }

    /// The note text for the focused verse.
    public var focusedNote: String {
        guard let focusedVerse else { return "" }
        return user.notes.text(for: focusedVerse.key)
    }

    /// The notes sheet autosaves on every keystroke.
    public func saveNote(_ text: String) {
        guard let focusedVerse else { return }
        user.setNote(text, for: focusedVerse)
    }

    /// The English of a verse in the selected translation, for the notes and share sheets.
    public func english(for verse: VerseRef) -> String {
        translations.text(for: verse) ?? ""
    }

    /// The muted Arabic line for a verse, with the Basmala rule applied.
    public func arabic(for verse: VerseRef) -> String? {
        translations.arabic(for: verse).map { ArabicText.stripBasmala($0, verse: verse) }
    }

    public func reference(for verse: VerseRef) -> String {
        index.surah(verse.surah)?.reference(for: verse.ayah) ?? verse.key
    }

    // MARK: Hint

    public func dismissHint() {
        isHintVisible = false
        hints.markRailHintSeen()
    }
}
