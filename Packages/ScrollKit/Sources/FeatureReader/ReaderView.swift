import DesignSystem
import QuranData
import StudyContent
import SwiftUI
import UserState

/// The Quran tab: a vertical pager through one surah at a time.
///
/// `ScrollView` + `LazyVStack(spacing: 0)` + `.containerRelativeFrame(.vertical)` + paging +
/// `.scrollPosition(id:)`, which is the shape CLAUDE.md specifies. The paging is
/// `ReaderPagingBehavior` rather than the stock `.paging` — see the note on it. Everything
/// the pager does — marking read after a 1.2 s dwell, remembering the position, handing over
/// to the next surah — lives in `ReaderModel`; this file is layout.
public struct ReaderView: View {
    @State private var model: ReaderModel

    /// The commentary the verse menu's four study rows are made of. Read out of the
    /// environment — `AppShell.appStores` already injects it for the Discover tab — rather
    /// than held by `ReaderModel`, so the reader keeps no reference to a store it needs on
    /// exactly one surface and `AppEnvironment` needs no new wiring to build the model.
    @Environment(StudyStore.self) private var studies: StudyStore?
    /// The verse menu's four study rows are Deep Study's content, so they are gated exactly
    /// as Deep Study is. Nothing injected means the free tier — see `ReaderSeams`.
    @Environment(\.readerPremium) private var premium
    @Environment(\.requestReaderPremium) private var requestPremium
    @Environment(\.openDeepStudy) private var openDeepStudy

    /// Wraps an existing model, which is what the screenshot routes and the previews use.
    public init(model: ReaderModel) {
        _model = State(initialValue: model)
    }

    /// The initializer `AppShell` calls: hand it the stores it already holds.
    ///
    /// With no explicit `startAyah` the reader resumes from `Prefs.lastReaderPosition`, which
    /// is what opening the Quran tab should do. Pass `restoringSavedPosition: false` for a
    /// deterministic entry point (a deep link, a screenshot route).
    ///
    /// `AppShell` may also build the `ReaderModel` itself and use ``init(model:)``: SwiftUI
    /// re-runs a view's `init` on every parent update and discards the extra `State` value, so
    /// a parent-owned model paginates the surah once rather than once per parent render.
    public init(
        surah: Int = 1,
        startAyah: Int? = nil,
        index: SurahIndex,
        translations: TranslationStore,
        user: UserStore,
        hints: (any ReaderHintStore)? = nil,
        restoringSavedPosition: Bool = true
    ) {
        _model = State(
            initialValue: ReaderModel(
                index: index,
                translations: translations,
                user: user,
                hints: hints,
                surah: surah,
                startAyah: startAyah,
                restoringSavedPosition: restoringSavedPosition
            )
        )
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            pager
        }
        .overlay(alignment: .topLeading) { rail }
        .overlay(alignment: .top) { toolbar }
        .overlay(alignment: .bottomTrailing) { actions }
        .overlay(alignment: .bottomLeading) { hint }
        .sheet(item: $model.sheet) { sheet in
            sheetContent(sheet)
                .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.reader")
    }

    // MARK: - Pager

    /// One `GeometryReader` for the whole pager, not one per page: a lazy stack of 287 pages
    /// each opening its own would pay a two-pass layout per realised row for a size that is the
    /// same on every page and already known here.
    private var pager: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroller in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.pages) { page in
                            VersePageView(
                                page: page,
                                pageSize: proxy.size,
                                onLogoTap: { model.present(.verseMenu) }
                            )
                            .containerRelativeFrame(.vertical)
                            .id(page.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(ReaderPagingBehavior())
                .scrollPosition(id: $model.currentPageID)
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("reader.pager")
                .onChange(of: model.currentPageID) { _, _ in
                    model.advanceToNextSurahIfNeeded()
                }
                // Every programmatic move — the rail's release, the surah picker, a deep
                // link, the dice, the handoff to the next surah — arrives here as a
                // `ReaderJump` and is committed twice. See `commit(_:with:)`.
                .onChange(of: model.jumpRequest) { _, request in
                    commit(request, with: scroller)
                }
                // The first page is a jump too: a route that opens on an ayah (a deep link,
                // a restored position) has to land on a boundary as much as a scrub does.
                .task { commit(model.jumpRequest, with: scroller) }
                // One dwell task per page, and the arrival is recorded inside it rather than in an
                // `onChange`: `task(id:)` runs for the *first* page too (an `onChange` does not),
                // and doing both here means the clock can never be read before it has been set.
                // The task is cancelled the moment the page changes, so an ayah that was only
                // scrolled past is never marked read.
                .task(id: model.currentPageID) {
                    model.pageChanged(to: model.currentPageID)
                    try? await Task.sleep(for: .seconds(model.dwellRemaining()))
                    guard !Task.isCancelled else { return }
                    model.settleDwell()
                }
            }
        }
    }

    /// Commits a programmatic page change so the pager can never stop between two pages.
    ///
    /// Phase 4j. `.scrollPosition(id:)` is a binding, not a command. A single write into a
    /// paging scroll view lands *near* the target and stops short of it: measured on the
    /// simulator, a rail tap to 2:86 parked 283 pt into the previous page, and a three-page
    /// nudge still parked 159 pt short — one ayah in the top half of the screen and the next
    /// rising from the bottom, which is the picture the owner sent.
    ///
    /// Two things hold it on the boundary. `ReaderPagingBehavior` rounds every scroll target
    /// onto the absolute page grid, which is what actually lands the jump; and the move is
    /// asserted twice, once now and once on the next run loop, so a jump issued while the
    /// pager was still settling is re-stated after that settle. Both with animations off: a
    /// jump is a cut, not a scroll. A newer jump (the dice pressed twice) abandons the older
    /// one's second round.
    private func commit(_ request: ReaderJump?, with scroller: ScrollViewProxy) {
        guard let request else { return }
        reassert(request, with: scroller)
        Task { @MainActor in
            // A newer jump owns the pager now; its own second round is already queued.
            guard model.jumpRequest == request else { return }
            reassert(request, with: scroller)
        }
    }

    /// One round of the commit: the binding, because it is what the chrome and the rail read,
    /// and `scrollTo(_:anchor: .top)`, which addresses the row by its `.id` and puts its top
    /// edge on the container's — exactly a page boundary.
    private func reassert(_ request: ReaderJump, with scroller: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.currentPageID = request.id
            scroller.scrollTo(request.id, anchor: .top)
        }
    }

    // MARK: - Chrome

    private var toolbar: some View {
        ReaderToolbar(
            surahName: model.surah.name,
            translationAbbreviation: model.translationAbbreviation,
            isLiked: model.isCurrentVerseLiked,
            isSaved: model.isCurrentVerseSaved,
            onRandomVerse: { model.openRandomVerse() },
            onToggleLike: model.toggleLike,
            onTranslation: { model.present(.translation) },
            onToggleSaved: model.toggleSaved,
            onSurahPicker: { model.present(.surahPicker) }
        )
        .padding(.top, ReaderMetrics.toolbarTopInset)
    }

    private var rail: some View {
        VerseRail(
            surah: model.surah.number,
            ayahCount: model.surah.ayahCount,
            currentAyah: model.railAyah,
            onScrub: { model.beginRailDrag(toAyah: $0) },
            onCommit: model.endRailDrag
        )
        .padding(.top, ReaderMetrics.railTopInset)
        .padding(.bottom, ReaderMetrics.railBottomInset)
    }

    private var actions: some View {
        ReaderActionStack(
            isLiked: model.isCurrentVerseLiked,
            onLike: model.toggleLike,
            onNotes: { model.present(.notes) },
            onShare: { model.present(.share) }
        )
        .padding(.trailing, ReaderMetrics.actionTrailingInset)
        .padding(.bottom, ReaderMetrics.actionBottomInset)
    }

    /// The bottom-left toast slot. A confirmation ("Widget verse set") takes it while it is
    /// up; otherwise the coaching hint has it. One slot, so the two can never overlap.
    @ViewBuilder
    private var hint: some View {
        if let toast = model.toast {
            ToastHint(systemImage: "checkmark.circle", title: toast.title, message: toast.message)
                .padding(.leading, ReaderMetrics.toastLeadingInset)
                .padding(.bottom, ReaderMetrics.toastBottomInset)
                .transition(.opacity)
                .accessibilityIdentifier("reader.toast")
                // Keyed on the toast's id, so setting the same widget verse twice restarts
                // the clock rather than letting the first one's task dismiss the second.
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(ReaderMetrics.toastDuration))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) { model.dismissToast() }
                }
        } else if model.isHintVisible {
            ToastHint(
                systemImage: "arrow.up.left",
                title: "Tap or slide",
                message: "to jump to any verse",
                onDismiss: { withAnimation(.easeOut(duration: 0.2)) { model.dismissHint() } }
            )
            // `ToastHint` is now pinned to its measured 214 pt; `.fixedSize()` here used
            // to be what stopped it from stretching, and it fought the fixed frame.
            .padding(.leading, ReaderMetrics.toastLeadingInset)
            .padding(.bottom, ReaderMetrics.toastBottomInset)
            .transition(.opacity)
            .accessibilityIdentifier("reader.hint")
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ReaderSheet) -> some View {
        switch sheet {
        case .translation:
            TranslationSheet(
                translations: model.translations.translations,
                arabicEdition: model.translations.registry.arabicEdition,
                selectedID: model.translations.selectedID,
                onSelect: { model.selectTranslation($0) },
                onDone: model.dismissSheet
            )
        case .notes:
            notesSheet
        case .surahPicker:
            SurahPicker(
                index: model.index,
                currentSurah: model.surah.number,
                onSelect: { number in
                    model.open(surah: number)
                    model.dismissSheet()
                },
                onDone: model.dismissSheet
            )
        case .share:
            shareSheet
        case .verseMenu:
            verseMenu
        }
    }

    /// The menu the logo card raises. Everything it needs is a value: the ayah, the study
    /// unit covering it, and five closures. It presents its own destinations by *pushing*
    /// them, so this is still one sheet.
    @ViewBuilder
    private var verseMenu: some View {
        if let verse = model.focusedVerse {
            VerseMenuSheet(
                reference: model.reference(for: verse),
                arabic: model.arabic(for: verse),
                english: model.english(for: verse),
                study: studies?.study(for: verse),
                attribution: model.translations.selected?.attribution ?? "",
                isSubscribed: premium.isSubscribed,
                text: { passage in
                    model.english(for: VerseRef(surah: passage.surah, ayah: passage.start))
                },
                onCancel: model.dismissSheet,
                onLocked: {
                    // The paywall is the shell's sheet over the tab bar, and iOS presents one
                    // sheet at a time: this one has to be gone before it is asked for.
                    model.dismissSheet()
                    requestPremium(.verseMenuStudy)
                },
                onDeeperStudy: { key in
                    model.dismissSheet()
                    openDeepStudy(key)
                },
                onSetWidgetVerse: {
                    model.setWidgetVerse()
                    model.dismissSheet()
                },
                onOpenVerse: { verse in
                    model.open(verse: verse)
                    model.dismissSheet()
                }
            )
        }
    }

    @ViewBuilder
    private var notesSheet: some View {
        if let verse = model.focusedVerse {
            NotesSheet(
                reference: model.reference(for: verse),
                arabic: model.arabic(for: verse),
                english: model.english(for: verse),
                note: model.focusedNote,
                onTextChange: { model.saveNote($0) },
                onDone: model.dismissSheet
            )
        }
    }

    @ViewBuilder
    private var shareSheet: some View {
        if let verse = model.focusedVerse {
            ShareSheetView(
                reference: model.reference(for: verse),
                arabic: model.arabic(for: verse),
                english: model.english(for: verse),
                attribution: model.translations.selected?.attribution ?? "",
                onDone: model.dismissSheet
            )
        }
    }
}

// MARK: - Screenshot routes

public extension ReaderView {
    /// The screens the snapshot harness routes to inside this feature.
    /// `AppShell` maps its own `ScreenRoute` onto these by raw value, which keeps
    /// `FeatureReader` free of a dependency on the shell that imports it.
    enum Screen: String, CaseIterable, Sendable {
        case reader
        case translationSheet = "translation-sheet"
        case notesSheet = "notes-sheet"
        case verseMenu = "reader-verse-menu"

        /// Which ayah of the fixture surah the route opens on.
        ///
        /// `reader` is the reference capture and stays on page 0. The sheet routes want a
        /// real ayah under the sheet, and the verse menu wants the one with a study unit the
        /// rest of the app is captured against — Ayat al-Kursi.
        var startAyah: Int? {
            switch self {
            case .reader: nil
            case .translationSheet, .notesSheet: 1
            case .verseMenu: 255
            }
        }
    }

    /// The fixture the reference captures were taken against: Al-Baqarah, page 0.
    nonisolated static let screenshotSurah = 2

    /// Builds the reader for a `--screenshot` route, with the matching sheet already up.
    ///
    /// The route string is `ScreenRoute.rawValue` (so `"reader"`, `"translation-sheet"`,
    /// `"notes-sheet"`, optionally with an `#anchor`); anything else renders the plain reader.
    @MainActor
    static func screen(
        for route: String,
        index: SurahIndex,
        translations: TranslationStore,
        user: UserStore,
        surah: Int = ReaderView.screenshotSurah,
        startAyah: Int? = nil
    ) -> some View {
        let screen = Screen(rawValue: route.split(separator: "#", maxSplits: 1).first.map(String.init) ?? route)
        let model = ReaderModel(
            index: index,
            translations: translations,
            user: user,
            // The captures all show the coaching toast, so a screenshot run never
            // remembers having dismissed it.
            hints: EphemeralReaderHintStore(),
            surah: surah,
            startAyah: startAyah ?? screen?.startAyah
            // Deliberately not restoring the saved position: a screenshot has to be the same
            // picture every time it is taken.
        )
        switch screen {
        case .translationSheet: model.present(.translation)
        case .notesSheet: model.present(.notes)
        case .verseMenu: model.present(.verseMenu)
        case .reader, nil: break
        }
        return ReaderView(model: model)
    }
}

/// Paging that snaps to the reader's **absolute** page grid.
///
/// Phase 4j. The stock `.scrollTargetBehavior(.paging)` moves by one container height *from
/// wherever the content happens to be*: it preserves whatever phase it is given. Land the pager 283 pt into
/// a page — which is what a programmatic jump into a 287-row `LazyVStack` does, measured on the
/// simulator with `onScrollGeometryChange`: a rail tap to 2:86 stopped at content offset
/// 62348.7 where the page starts at 62632 — and `.paging` keeps those 283 pt for every swipe
/// afterwards, one ayah in the top half of the screen and the next rising from the bottom.
///
/// Every page is exactly one container tall (`containerRelativeFrame(.vertical)`), so page *k*
/// starts at `k x containerHeight` and the grid is absolute. Rounding the scroll target onto it
/// lands a jump on a boundary, is consulted for programmatic scrolls as well as gestures, and
/// heals a pager that was somehow left between two pages on the reader's next swipe.
struct ReaderPagingBehavior: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = Self.snapped(target.rect.minY, pageHeight: context.containerSize.height)
    }

    /// The nearest page boundary to `y`. A zero or negative container leaves `y` alone rather
    /// than dividing by it; the reader has no page to snap to in that state anyway.
    static func snapped(_ y: CGFloat, pageHeight: CGFloat) -> CGFloat {
        guard pageHeight > 0 else { return y }
        return (y / pageHeight).rounded() * pageHeight
    }
}
