import DesignSystem
import QuranData
import SwiftUI
import UserState

/// The Quran tab: a vertical pager through one surah at a time.
///
/// `ScrollView` + `LazyVStack(spacing: 0)` + `.containerRelativeFrame(.vertical)` +
/// `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)`, which is the shape CLAUDE.md
/// specifies. Everything the pager does — marking read after a 1.2 s dwell, remembering the
/// position, handing over to the next surah — lives in `ReaderModel`; this file is layout.
public struct ReaderView: View {
    @State private var model: ReaderModel

    /// Wraps an existing model, which is what the screenshot routes and the previews use.
    public init(model: ReaderModel) {
        _model = State(initialValue: model)
    }

    /// The initializer `AppShell` calls: hand it the stores it already holds.
    public init(
        surah: Int = 1,
        startAyah: Int? = nil,
        index: SurahIndex,
        translations: TranslationStore,
        user: UserStore,
        hints: (any ReaderHintStore)? = nil
    ) {
        _model = State(
            initialValue: ReaderModel(
                index: index,
                translations: translations,
                user: user,
                hints: hints,
                surah: surah,
                startAyah: startAyah
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.reader")
    }

    // MARK: - Pager

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(model.pages) { page in
                    VersePageView(page: page)
                        .containerRelativeFrame(.vertical)
                        .id(page.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.currentPageID)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("reader.pager")
        .onChange(of: model.currentPageID) { _, id in
            model.pageChanged(to: id)
            model.advanceToNextSurahIfNeeded()
        }
        // One dwell task per page: it is cancelled the moment the page changes, so an ayah
        // that was only scrolled past never gets marked.
        .task(id: model.currentPageID) {
            let wait = model.dwellRemaining()
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            model.settleDwell()
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
            ayahCount: model.surah.ayahCount,
            currentAyah: model.railAyah,
            onScrub: { model.beginRailDrag(toAyah: $0) },
            onCommit: model.endRailDrag
        )
        .padding(.top, VersePageView.logoCardTop - ReaderMetrics.logoCardTopFromToolbar + ReaderMetrics.railTopFromToolbar)
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

    @ViewBuilder
    private var hint: some View {
        if model.isHintVisible {
            ToastHint(
                systemImage: "arrow.up.left",
                title: "Tap or slide",
                message: "to jump to any verse",
                onDismiss: model.dismissHint
            )
            .frame(width: ReaderMetrics.toastWidth)
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
            .presentationDragIndicator(.visible)
        case .notes:
            notesSheet
                .presentationDragIndicator(.visible)
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
            .presentationDragIndicator(.visible)
        case .share:
            shareSheet
                .presentationDragIndicator(.visible)
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
                onChange: { model.saveNote($0) },
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
    /// The three screens the snapshot harness routes to inside this feature.
    /// `AppShell` maps its own `ScreenRoute` onto these by raw value, which keeps
    /// `FeatureReader` free of a dependency on the shell that imports it.
    enum Screen: String, CaseIterable, Sendable {
        case reader
        case translationSheet = "translation-sheet"
        case notesSheet = "notes-sheet"
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
            startAyah: startAyah ?? (screen == .reader ? nil : 1)
        )
        switch screen {
        case .translationSheet: model.present(.translation)
        case .notesSheet: model.present(.notes)
        case .reader, nil: break
        }
        return ReaderView(model: model)
    }
}
