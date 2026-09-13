import DesignSystem
import SwiftUI

/// "Explain Easier": the ayah's unit told plainly, with a way through to the full study.
///
/// The copy is `Study.explainEasier` where the simplify pass has been through the unit and
/// `Study.meaning` where it has not (`VerseMenu.explainEasierText(for:)`). No shipped unit
/// carries `explainEasier` yet, so today every row shows `meaning` — the row is still the
/// short way in, and it gets shorter for free as the content pipeline fills the field.
struct ExplainEasierSheet: View {
    let reference: String
    let text: String
    /// Nil when there is no unit to open. Present, it dismisses the menu and hands over to
    /// the one Deep Study screen `FeatureDiscover` owns.
    let onFullStudy: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text(text)
                    .font(.serifBody(VerseMenuMetrics.explainBodySize))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("reader.explainEasier.body")
                if let onFullStudy {
                    Button(action: onFullStudy) {
                        HStack(spacing: Spacing.sm) {
                            Text("Read the full study")
                                .font(.body(VerseMenuMetrics.rowSubtitleSize, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: VerseMenuMetrics.rowChevronSize, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color.textPrimary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("reader.explainEasier.fullStudy")
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
            .accessibilityIdentifier("reader.explainEasier")
    }
}
