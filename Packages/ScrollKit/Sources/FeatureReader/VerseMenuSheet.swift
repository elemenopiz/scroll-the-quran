import DesignSystem
import QuranData
import StudyContent
import SwiftUI

// MARK: - The row model

/// One row of the verse menu, as a value. Pure, so "which rows does this verse get, and which
/// of them are locked?" is answered — and tested — without a view.
public struct VerseMenuRow: Identifiable, Hashable, Sendable {
    /// What the row does. The raw value is the tail of its accessibility identifier
    /// (`reader.verseMenu.explain`), which is what the UI tests tap.
    public enum Action: String, Hashable, Sendable, CaseIterable {
        case explain
        case original
        case deeper
        case related
        case widget
        case snapshot
    }

    public let action: Action
    public let systemImage: String
    public let title: String
    public let subtitle: String?
    /// Study content. A free reader gets the paywall instead, exactly as Deep Study does.
    public let isPremium: Bool

    public var id: Action {
        action
    }

    public var identifier: String {
        "reader.verseMenu.\(action.rawValue)"
    }
}

/// The menu's contents.
public enum VerseMenu {
    /// The four rows that are Deep Study's content under another name. They are shown only
    /// when a study unit actually covers the ayah, and gated exactly as Deep Study is.
    public static let studyRows: [VerseMenuRow] = [
        VerseMenuRow(
            action: .explain,
            systemImage: "lightbulb",
            title: "Explain Easier",
            subtitle: nil,
            isPremium: true
        ),
        VerseMenuRow(
            action: .original,
            systemImage: "character.book.closed",
            title: "Original Language",
            subtitle: nil,
            isPremium: true
        ),
        VerseMenuRow(
            action: .deeper,
            systemImage: "book",
            title: "Deeper Study",
            subtitle: nil,
            isPremium: true
        ),
        VerseMenuRow(
            action: .related,
            systemImage: "link",
            title: "Related Verses",
            subtitle: nil,
            isPremium: true
        ),
    ]

    /// The two free rows. Neither needs a study unit: any ayah can be put on the Lock Screen
    /// or shared as an image.
    public static let freeRows: [VerseMenuRow] = [
        VerseMenuRow(
            action: .widget,
            // `lock.iphone` does not exist in the iOS 17 SF Symbols set the app builds
            // against; `iphone` does, and is what the brief falls back to.
            systemImage: "iphone",
            title: "Set as Widget Verse",
            subtitle: nil,
            isPremium: false
        ),
        VerseMenuRow(
            action: .snapshot,
            systemImage: "camera.viewfinder",
            title: "Snapshot Verse",
            subtitle: "Share as an image anywhere",
            isPremium: false
        ),
    ]

    /// The rows for a verse.
    ///
    /// The corpus is complete — every one of the 6,236 ayat maps to an authored unit, which
    /// `VerseMenuTests.everyAyahHasAStudyUnit` asserts — so `study == nil` should never
    /// happen in the app. It is still answered rather than trapped: a shard that fails to
    /// read degrades to the two free rows instead of an empty sheet.
    public static func rows(study: Study?) -> [VerseMenuRow] {
        (study == nil ? [] : studyRows) + freeRows
    }

    /// Which of the four study rows a related-verses list can actually be built from.
    /// A unit with no cross references still shows the row; the sheet says so itself.
    public static func relatedReferences(in study: Study?) -> [Study.CrossRef] {
        study?.crossReferences ?? []
    }

    /// "Explain Easier" copy: the simplified line when the unit has been through the
    /// simplify pass (`Tools/content-gen/author.mjs rewrite`), the section it simplifies
    /// otherwise. No unit carries `explainEasier` yet, so today this is always `meaning`.
    public static func explainEasierText(for study: Study?) -> String {
        guard let study else { return "" }
        return study.explainEasier ?? study.meaning
    }
}

// MARK: - The sheet

/// What the verse menu can push onto its own stack. Deeper Study is not here: it leaves the
/// sheet entirely and opens the one Deep Study screen `FeatureDiscover` owns.
enum VerseMenuDestination: String, Hashable, Identifiable {
    case explain
    case original
    case related
    case snapshot

    var id: String {
        rawValue
    }
}

/// The sheet the logo card raises: the ayah, then six things to do with it.
///
/// Geometry is `VerseMenuMetrics`, measured off the owner's screenshot of the original. The
/// four destinations that stay inside the reader are *pushed* rather than presented: iOS
/// supports one sheet at a time, and swapping the item under a live `.sheet(item:)` is how a
/// menu ends up dismissing itself without presenting anything. The two that leave — Deeper
/// Study and the paywall — dismiss first and hand over to the shell.
struct VerseMenuSheet: View {
    let reference: String
    let arabic: String?
    let english: String
    let study: Study?
    let attribution: String
    let isSubscribed: Bool
    /// The English of a cross-referenced passage, for the Related Verses list.
    let text: (PassageRef) -> String
    let onCancel: () -> Void
    /// A locked row was tapped: dismiss and raise the paywall.
    let onLocked: () -> Void
    /// "Deeper Study": dismiss and open Deep Study on this unit.
    let onDeeperStudy: (String) -> Void
    let onSetWidgetVerse: () -> Void
    let onOpenVerse: (VerseRef) -> Void

    @State private var path: [VerseMenuDestination] = []

    private var rows: [VerseMenuRow] {
        VerseMenu.rows(study: study)
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: VerseMenuDestination.self, destination: destination)
            #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .background(Color.cardBackground)
        .presentationDetents([.fraction(VerseMenuMetrics.detentFraction), .large])
        .presentationCornerRadius(VerseMenuMetrics.cornerRadius)
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.verseMenu")
    }

    // MARK: - Root

    private var root: some View {
        VStack(alignment: .leading, spacing: 0) {
            cancel
            header
            divider
            rowList
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
    }

    private var cancel: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.body(VerseMenuMetrics.cancelLabelSize))
                .foregroundStyle(Color.textSecondary)
                .frame(
                    width: VerseMenuMetrics.cancelWidth,
                    height: VerseMenuMetrics.cancelHeight
                )
                .background(Color.chipBackground, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .padding(.leading, VerseMenuMetrics.cancelLeading)
        .padding(.top, VerseMenuMetrics.cancelTop)
        .accessibilityIdentifier("reader.verseMenu.cancel")
    }

    /// The reference and a preview of the ayah — muted Arabic above the English, per
    /// CLAUDE.md rule 5: the menu is a verse surface.
    private var header: some View {
        VStack(spacing: VerseMenuMetrics.verseTopFromReference) {
            Text(reference)
                .font(.body(VerseMenuMetrics.referenceFontSize, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .accessibilityIdentifier("reader.verseMenu.reference")
            versePreview
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VerseMenuMetrics.versePadding)
        .padding(.top, VerseMenuMetrics.referenceTopFromCancel)
    }

    /// Composed rather than `VerseText`, which has no 14 pt size: the Arabic still comes
    /// through `ArabicAccentText` at the canonical ratio, so rule 5's treatment — muted,
    /// centred, right-to-left, VoiceOver-hidden — is the component's, not this file's.
    private var versePreview: some View {
        VStack(spacing: VerseMenuMetrics.versePreviewSpacing) {
            if let arabic, !arabic.isEmpty {
                ArabicAccentText(
                    arabic,
                    size: VerseMenuMetrics.versePreviewArabic,
                    lineLimit: VerseMenuMetrics.versePreviewLineLimit
                )
            }
            Text(english)
                .font(.serifBody(VerseMenuMetrics.versePreviewEnglish))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(VerseMenuMetrics.versePreviewLineLimit)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(english)
        .accessibilityIdentifier("reader.verseMenu.verse")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, VerseMenuMetrics.dividerInset)
            .padding(.top, VerseMenuMetrics.dividerTopFromVerse)
    }

    private var rowList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                if offset > 0 {
                    separator
                }
                VerseMenuRowView(row: row) { select(row) }
            }
        }
        .padding(.top, VerseMenuMetrics.rowsTopFromDivider)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: Stroke.hairline)
            .padding(.leading, VerseMenuMetrics.separatorLeading)
            .padding(.trailing, VerseMenuMetrics.separatorTrailing)
    }

    // MARK: - Behaviour

    private func select(_ row: VerseMenuRow) {
        if row.isPremium, !isSubscribed {
            onLocked()
            return
        }
        switch row.action {
        case .explain: path.append(.explain)
        case .original: path.append(.original)
        case .related: path.append(.related)
        case .snapshot: path.append(.snapshot)
        case .deeper:
            guard let key = study?.key else { return }
            onDeeperStudy(key)
        case .widget:
            onSetWidgetVerse()
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(_ destination: VerseMenuDestination) -> some View {
        switch destination {
        case .explain:
            ExplainEasierSheet(
                reference: reference,
                text: VerseMenu.explainEasierText(for: study),
                onFullStudy: study.map { study in { onDeeperStudy(study.key) } }
            )
        case .original:
            OriginalLanguageSheet(
                reference: reference,
                arabic: arabic,
                english: english,
                keyTerms: study?.keyTerms ?? []
            )
        case .related:
            RelatedVersesSheet(
                reference: reference,
                references: VerseMenu.relatedReferences(in: study),
                text: text,
                onOpen: onOpenVerse
            )
        case .snapshot:
            ShareSheetView(
                reference: reference,
                arabic: arabic,
                english: english,
                attribution: attribution,
                onDone: onCancel
            )
        }
    }
}

/// One 54 pt row: icon, label, optional subtitle, chevron.
struct VerseMenuRowView: View {
    let row: VerseMenuRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VerseMenuMetrics.rowIconToLabel) {
                Image(systemName: row.systemImage)
                    .font(.system(size: VerseMenuMetrics.rowIconSize, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: VerseMenuMetrics.rowIconColumn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(row.title)
                        .font(.body(VerseMenuMetrics.rowLabelSize, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .font(.body(VerseMenuMetrics.rowSubtitleSize))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: VerseMenuMetrics.rowChevronSize, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, VerseMenuMetrics.rowLeading)
            .padding(.trailing, VerseMenuMetrics.rowTrailing)
            .frame(minHeight: VerseMenuMetrics.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(row.subtitle.map { "\(row.title), \($0)" } ?? row.title)
        .accessibilityIdentifier(row.identifier)
    }
}

// MARK: - Previews

#Preview("Verse menu dark") {
    VerseMenuPreview().preferredColorScheme(.dark)
}

#Preview("Verse menu light") {
    VerseMenuPreview().preferredColorScheme(.light)
}

private struct VerseMenuPreview: View {
    var body: some View {
        VerseMenuSheet(
            reference: "Al-Baqarah 2:255",
            arabic: VersePreviewFixture.ayatAlKursiArabic,
            english: VersePreviewFixture.ayatAlKursiEnglish,
            study: Study(key: "2:255", title: "The Throne Verse", meaning: "…"),
            attribution: "Translation by Talal Itani, ClearQuran.com",
            isSubscribed: true,
            text: { $0.key },
            onCancel: {},
            onLocked: {},
            onDeeperStudy: { _ in },
            onSetWidgetVerse: {},
            onOpenVerse: { _ in }
        )
        .task { DesignSystem.registerFonts() }
    }
}
