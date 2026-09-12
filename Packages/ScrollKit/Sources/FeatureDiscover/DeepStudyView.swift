import DesignSystem
import QuranData
import StudyContent
import SwiftUI
import UserState

/// The full-screen Deep Study page: the passage, its quoted ayah, and the nine sections
/// in `StudySection.displayOrder`.
///
/// It is presented as a `fullScreenCover` from the Discover card. Everything scrolls
/// under the two pinned circular buttons — mark-done on the left, close on the right —
/// which is why they are an overlay rather than a header row: in `deepstudy-mid.png`
/// the body text is visible *through* the gap beside them.
@MainActor
public struct DeepStudyView: View {
    /// The licence and provenance line under the action row. Verbatim per the brief.
    public static let disclaimer = """
    You're reading the Clear Quran. Word studies and insights are AI-assisted summaries \
    of classical commentary and are not tied to any specific translation or a religious ruling.
    """

    private let study: Study
    private let themeTitle: String?
    private let anchor: StudySection?
    private let onClose: (() -> Void)?

    @Environment(TranslationStore.self) private var translations: TranslationStore?
    @Environment(UserStore.self) private var user: UserStore?
    @Environment(\.openPassage) private var openPassage
    @Environment(\.openNote) private var openNote
    @Environment(\.dismiss) private var dismiss

    public init(
        study: Study,
        themeTitle: String? = nil,
        anchor: StudySection? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.study = study
        self.themeTitle = themeTitle
        self.anchor = anchor
        self.onClose = onClose
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    quoteBox
                    Rectangle()
                        .fill(Color.divider)
                        .frame(height: Stroke.hairline)
                        .padding(.horizontal, DeepStudyMetrics.inset)
                        .padding(.top, Spacing.xxl)
                    sections
                    actions
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .contentMargins(.top, DeepStudyMetrics.scrollTopInset, for: .scrollContent)
            .background(Color.appBackgroundFlat)
            .task {
                if let anchor {
                    proxy.scrollTo(StudyAnchor.id(for: anchor), anchor: .top)
                }
            }
        }
        // Deep Study is full-bleed, so its body text scrolls up under the clock and the
        // battery. The reference fades the content out toward the top rather than
        // insetting it; this is that fade. Below the pinned buttons, which stay crisp.
        .statusBarScrim()
        .overlay(alignment: .top) { pinnedButtons }
        // Same reason as `DiscoverCard`: without the container element, the identifier
        // below overwrites the two pinned buttons' own ids (the scroll view's contents keep
        // theirs, because a scroll view is already a container).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deepstudy")
    }

    // MARK: - Pieces

    private var presentation: PassagePresentation {
        PassagePresentation.make(for: study.passage, translations: translations)
    }

    private var pinnedButtons: some View {
        HStack {
            CircleIconButton(
                systemImage: isDone ? "checkmark.circle.fill" : "checkmark.circle",
                label: "Mark as read"
            ) {
                markRead()
            }
            .accessibilityIdentifier("deepstudy.markDone")
            Spacer()
            CircleIconButton(systemImage: "xmark", label: "Close") {
                onClose?()
                dismiss()
            }
            .accessibilityIdentifier("deepstudy.close")
        }
        .padding(.horizontal, Spacing.pageMargin)
    }

    private var header: some View {
        VStack(spacing: 0) {
            if let title = themeTitle ?? (study.theme.isEmpty ? nil : study.theme) {
                Chip(title)
                    .accessibilityIdentifier("deepstudy.themeChip")
            }
            Text(presentation.reference)
                .font(.serifDisplay(44))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, Spacing.sm)
                .accessibilityIdentifier("deepstudy.reference")
            Text(presentation.translationTag)
                .font(.body(13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Spacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.top, DeepStudyMetrics.headerTopPadding)
    }

    private var quoteBox: some View {
        TintedSectionBox(kind: .quote) {
            VerseText(
                arabic: presentation.arabic,
                segments: presentation.segments,
                size: .deepStudy,
                style: .italic,
                quoted: true
            )
        }
        .padding(.horizontal, DeepStudyMetrics.inset)
        .padding(.top, Spacing.xl)
        .accessibilityIdentifier("deepstudy.quote")
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: DeepStudyMetrics.sectionGap) {
            ForEach(study.populatedSections) { section in
                StudySectionBox(
                    section: section,
                    onCopy: { copy(section) },
                    content: { body(for: section) }
                )
                .id(StudyAnchor.id(for: section))
            }
        }
        .padding(.horizontal, DeepStudyMetrics.inset)
        .padding(.top, DeepStudyMetrics.sectionGap)
    }

    @ViewBuilder
    private func body(for section: StudySection) -> some View {
        switch section {
        case .keyTerms:
            KeyTermsList(terms: study.keyTerms)
        case .crossReferences:
            VStack(spacing: DeepStudyMetrics.rowGap) {
                ForEach(study.crossReferences) { ref in
                    let resolved = PassagePresentation.make(forKey: ref.ref, translations: translations)
                    CrossReferenceRow(
                        title: resolved?.reference ?? ref.ref,
                        text: resolved?.english ?? ref.why,
                        identifier: "deepstudy.crossRef.\(ref.ref)"
                    ) {
                        open(key: ref.ref)
                    }
                }
            }
        case .exploreFurther:
            VStack(spacing: DeepStudyMetrics.rowGap) {
                ForEach(study.exploreFurther, id: \.self) { key in
                    let resolved = PassagePresentation.make(forKey: key, translations: translations)
                    ExploreRow(title: resolved?.reference ?? key, identifier: "deepstudy.explore.\(key)") {
                        open(key: key)
                    }
                }
            }
        default:
            StudyProse(text: study.prose(for: section) ?? "")
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            LabeledAction(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                title: "Save",
                identifier: "deepstudy.save",
                isOn: isSaved
            ) {
                user?.toggleSaved(study.passage)
            }
            LabeledAction(systemImage: "bubble.left", title: "Note", identifier: "deepstudy.note") {
                openNote(study.key)
            }
            LabeledAction(systemImage: "doc.on.doc", title: "Copy", identifier: "deepstudy.copyAll") {
                Pasteboard.copy(copyAllText)
            }
            ShareLink(item: copyAllText) {
                LabeledActionLabel(systemImage: "square.and.arrow.up", title: "Share", isOn: false)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("deepstudy.share")
        }
        .padding(.horizontal, DeepStudyMetrics.inset)
        .padding(.top, Spacing.huge)
    }

    private var footer: some View {
        Text(DeepStudyView.disclaimer)
            .font(.body(12))
            .foregroundStyle(Color.textTertiaryReadable)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DeepStudyMetrics.inset)
            .padding(.top, Spacing.xxxl)
            .padding(.bottom, Spacing.huge)
            .accessibilityIdentifier("deepstudy.disclaimer")
    }

    // MARK: - Behaviour

    private var isSaved: Bool {
        user?.isSaved(study.passage) ?? false
    }

    /// Done once every ayah of the passage is marked read; the button is the mark, not
    /// a toggle, because `UserState` records progress and never un-records it.
    private var isDone: Bool {
        guard let user, let translations else { return false }
        return study.verses.allSatisfy { verse in
            guard let index = translations.index.globalIndex(of: verse) else { return false }
            return user.progress.isRead(globalIndex: index)
        }
    }

    private var copyAllText: String {
        let presentation = presentation
        return StudyCopy.all(
            study,
            reference: presentation.reference,
            quote: presentation.quoted,
            attribution: presentation.attribution
        )
    }

    private func copy(_ section: StudySection) {
        Pasteboard.copy(StudyCopy.section(section, of: study))
    }

    private func open(key: String) {
        guard let passage = PassageRef(key: key) else { return }
        openPassage(passage)
    }

    private func markRead() {
        guard let user, let translations else { return }
        for verse in study.verses {
            if let index = translations.index.globalIndex(of: verse) {
                user.markRead(globalIndex: index)
            }
        }
    }
}

/// One of the four labelled actions at the foot of Deep Study.
struct LabeledAction: View {
    let systemImage: String
    let title: String
    let identifier: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LabeledActionLabel(systemImage: systemImage, title: title, isOn: isOn)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

struct LabeledActionLabel: View {
    let systemImage: String
    let title: String
    let isOn: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.actionIcon, weight: .regular))
            Text(title)
                .font(.body(13, weight: .medium))
        }
        .foregroundStyle(isOn ? Color.textPrimary : Color.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 60)
        .contentShape(.rect)
    }
}

/// Shown instead of the page when a passage has no unit in `StudyStore`.
public struct StudyComingSoonCard: View {
    private let reference: String
    private let onClose: (() -> Void)?

    public init(reference: String = "", onClose: (() -> Void)? = nil) {
        self.reference = reference
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: 0)
            CardContainer(radius: Radius.cardLarge, padding: Spacing.xxxl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                    Text("Study coming soon")
                        .font(.serifDisplay(24, relativeTo: .title2))
                        .foregroundStyle(Color.textPrimary)
                    if !reference.isEmpty {
                        Text(reference)
                            .font(.body(13, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("Deep Study notes for this passage are still being written.")
                        .font(.serifBody(15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Metrics.cardInset)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackgroundFlat)
        .overlay(alignment: .topTrailing) {
            if let onClose {
                CircleIconButton(systemImage: "xmark", label: "Close", action: onClose)
                    .padding(.horizontal, Spacing.pageMargin)
                    .accessibilityIdentifier("deepstudy.close")
            }
        }
        .accessibilityIdentifier("deepstudy.comingSoon")
    }
}
