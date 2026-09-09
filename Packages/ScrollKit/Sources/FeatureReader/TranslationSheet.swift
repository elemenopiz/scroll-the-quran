import DesignSystem
import QuranData
import SwiftUI

/// The translation picker. Every row prints its licence line **verbatim** — Itani's CC BY-ND,
/// QuranEnc's terms for Saheeh and Ruwwad and Tanzil's CC BY all require the attribution to
/// be shown as written, so the copy comes straight out of `Content/quran/translations.json`
/// and is never paraphrased here.
///
/// Measured from `translation-sheet.png`: header divider at y 129.7 pt, rows 20 pt padded,
/// title 17 pt bold, subtitle 15 pt, copyright 13 pt on a 12 pt pitch.
struct TranslationSheet: View {
    let translations: [TranslationInfo]
    let arabicEdition: ArabicEditionInfo
    let selectedID: String
    let onSelect: (String) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Translation") {
                OutlinePillButton("Done", height: ReaderMetrics.sheetDoneHeight, action: onDone)
                    .frame(width: ReaderMetrics.sheetDoneWidth)
                    .accessibilityIdentifier("translationSheet.done")
            } trailing: {
                Color.clear.frame(width: ReaderMetrics.sheetDoneWidth, height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(translations) { info in
                        row(info)
                        divider
                    }
                    arabicRow
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.sheetBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("translationSheet")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, Spacing.pageMargin)
    }

    private func row(_ info: TranslationInfo) -> some View {
        Button {
            onSelect(info.id)
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: ReaderMetrics.sheetRowSpacing) {
                    HStack(spacing: Spacing.sm) {
                        Text(info.abbrev)
                            .font(.body(ReaderMetrics.sheetRowTitleSize, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        if info.offline {
                            OfflineBadge()
                        }
                    }
                    Text(info.name)
                        .font(.body(ReaderMetrics.sheetRowSubtitleSize))
                        .foregroundStyle(Color.textSecondary)
                    Text(info.copyright)
                        .font(.body(ReaderMetrics.sheetRowCopyrightSize))
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.md)
                if info.id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, ReaderMetrics.sheetRowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(info.abbrev), \(info.name)")
        .accessibilityAddTraits(info.id == selectedID ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("translationSheet.row.\(info.id)")
    }

    /// The Arabic layer is not a translation, so it sits below the list as an attribution
    /// rather than as a choice — but its licence still has to be printed.
    private var arabicRow: some View {
        VStack(alignment: .leading, spacing: ReaderMetrics.sheetRowSpacing) {
            Text("Arabic")
                .capsLabelStyle()
                .foregroundStyle(Color.textTertiary)
            Text(arabicEdition.name)
                .font(.body(ReaderMetrics.sheetRowSubtitleSize))
                .foregroundStyle(Color.textSecondary)
            Text(arabicEdition.attribution)
                .font(.body(ReaderMetrics.sheetRowCopyrightSize))
                .foregroundStyle(Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, ReaderMetrics.sheetRowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("translationSheet.arabic")
    }
}
