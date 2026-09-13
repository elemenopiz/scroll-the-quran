import DesignSystem
import StudyContent
import SwiftUI

/// "Original Language": the one surface in the app where the Arabic is the reading text.
///
/// Everywhere else the Uthmani line is the muted design layer CLAUDE.md rule 5 describes —
/// 58 % of the English, `textTertiary`, hidden from VoiceOver. Here it is the subject: 30 pt,
/// `textPrimary`, right-to-left and centred, with the English under it as the gloss. It is
/// *not* hidden from VoiceOver on this screen, because here it is what the reader came for.
///
/// Under it the unit's key terms, in the same never-transliterated shape Deep Study uses:
/// Arabic script, then the English gloss, then the note.
struct OriginalLanguageSheet: View {
    let reference: String
    let arabic: String?
    let english: String
    let keyTerms: [Study.KeyTerm]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                verse
                if !keyTerms.isEmpty {
                    terms
                }
            }
            .padding(.horizontal, VerseMenuMetrics.versePadding)
            .padding(.vertical, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(Color.cardBackground)
        .navigationTitle(reference)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader.originalLanguage")
    }

    private var verse: some View {
        VStack(spacing: Spacing.xl) {
            if let arabic, !arabic.isEmpty {
                Text(arabic)
                    .font(.arabicAccent(VerseMenuMetrics.originalArabicSize))
                    // KFGQPC stacks its pause marks and superscript alefs high; the same
                    // relaxed leading `ArabicAccentText` gives the muted layer.
                    .lineSpacing(VerseMenuMetrics.originalArabicSize * 0.35)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("reader.originalLanguage.arabic")
            }
            Text(english)
                .font(.serifBody(VerseMenuMetrics.originalEnglishSize))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("reader.originalLanguage.english")
        }
    }

    private var terms: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Key Arabic Terms")
                .capsLabelStyle()
                .foregroundStyle(Color.textTertiaryReadable)
            ForEach(keyTerms) { term in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                        ArabicAccentText(term.arabic, size: VerseMenuMetrics.keyTermArabicSize)
                            .fixedSize()
                        Text(term.gloss)
                            .font(.body(VerseMenuMetrics.rowSubtitleSize, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer(minLength: 0)
                    }
                    if !term.note.isEmpty {
                        Text(term.note)
                            .font(.serifBody(VerseMenuMetrics.rowSubtitleSize))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(term.gloss). \(term.note)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("reader.originalLanguage.keyTerms")
    }
}
