import DesignSystem
import QuranData
import SwiftUI

/// The reader's floating top chrome: `[dice][heart]` and the translation pill on the left,
/// the bookmark circle and the surah pill on the right.
///
/// Measured from `reader-dark.png`: all four items are centred on y = 83.8 pt, the group
/// starts 10 pt from the left edge and the surah pill ends 10.3 pt from the right.
struct ReaderToolbar: View {
    let surahName: String
    let translationAbbreviation: String
    let isLiked: Bool
    let isSaved: Bool
    let onRandomVerse: () -> Void
    let onToggleLike: () -> Void
    let onTranslation: () -> Void
    let onToggleSaved: () -> Void
    let onSurahPicker: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            CapsuleIconGroup(
                identifierPrefix: "reader.toolbar",
                items: [
                    CapsuleIconItem(
                        id: "dice",
                        systemImage: "die.face.4",
                        label: "Random ayah",
                        action: onRandomVerse
                    ),
                    CapsuleIconItem(
                        id: "like",
                        systemImage: isLiked ? "heart.fill" : "heart",
                        label: isLiked ? "Unlike this ayah" : "Like this ayah",
                        isOn: isLiked,
                        action: onToggleLike
                    ),
                ]
            )
            Spacer(minLength: ReaderMetrics.toolbarLeadingSpacing)
                .frame(width: ReaderMetrics.toolbarLeadingSpacing)
            translationPill
            Spacer(minLength: Spacing.sm)
            bookmarkButton
            Spacer(minLength: ReaderMetrics.toolbarTrailingSpacing)
                .frame(width: ReaderMetrics.toolbarTrailingSpacing)
            surahPill
        }
        .padding(.horizontal, ReaderMetrics.toolbarSideMargin)
        .frame(height: ReaderMetrics.toolbarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.toolbar")
    }

    /// The abbreviation of the selected translation ("CLEAR"); opens the translation sheet.
    private var translationPill: some View {
        Button(action: onTranslation) {
            Text(translationAbbreviation)
                .font(.body(ReaderMetrics.toolbarLabel, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .frame(minWidth: ReaderMetrics.translationPillMinWidth)
                .frame(height: ReaderMetrics.translationPillHeight)
                .background(Color.cardBackground, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Translation: \(translationAbbreviation)")
        .accessibilityIdentifier("reader.translationPill")
    }

    private var bookmarkButton: some View {
        Button(action: onToggleSaved) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: ReaderMetrics.toolbarGlyph, weight: .medium))
                .foregroundStyle(isSaved ? Color.textPrimary : Color.textSecondary)
                .frame(width: ReaderMetrics.bookmarkDiameter, height: ReaderMetrics.bookmarkDiameter)
                .background(Color.cardBackground, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save this ayah")
        .accessibilityIdentifier("reader.bookmark")
    }

    /// "Al-Baqarah ⌄"; opens the surah picker.
    private var surahPill: some View {
        Button(action: onSurahPicker) {
            HStack(spacing: Spacing.xs) {
                Text(surahName)
                    .font(.body(ReaderMetrics.toolbarLabel, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: ReaderMetrics.toolbarGlyph * 0.75, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: ReaderMetrics.surahPillHeight)
            .background(Color.cardBackground, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Surah \(surahName). Choose a surah")
        .accessibilityIdentifier("reader.surahPill")
    }
}

/// The heart / notes / share column down the right-hand side of every page. Glyph centres
/// measured at y 581 / 644.8 / 708.8 pt, x 353.8 pt.
struct ReaderActionStack: View {
    let isLiked: Bool
    let onLike: () -> Void
    let onNotes: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: ReaderMetrics.actionSpacing) {
            button(
                systemImage: isLiked ? "heart.fill" : "heart",
                label: isLiked ? "Unlike this ayah" : "Like this ayah",
                identifier: "reader.action.like",
                isOn: isLiked,
                action: onLike
            )
            button(
                systemImage: "bubble.left",
                label: "Notes",
                identifier: "reader.action.notes",
                isOn: false,
                action: onNotes
            )
            button(
                systemImage: "paperplane",
                label: "Share",
                identifier: "reader.action.share",
                isOn: false,
                action: onShare
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.actions")
    }

    private func button(
        systemImage: String,
        label: String,
        identifier: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: ReaderMetrics.actionGlyph, weight: .light))
                .foregroundStyle(isOn ? Color.textPrimary : Color.textPrimary)
                .frame(width: ReaderMetrics.actionButton, height: ReaderMetrics.actionButton)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
