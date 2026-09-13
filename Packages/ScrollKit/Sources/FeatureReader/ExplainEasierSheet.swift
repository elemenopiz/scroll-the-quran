import DesignSystem
import SwiftUI

/// "Explain Easier": the ayah's unit told plainly, with a way through to the full study.
///
/// The copy is `Study.explainEasier` where the simplify pass has been through the unit and
/// `Study.meaning` where it has not (`VerseMenu.explainEasierText(for:)`). 1,316 of the 3,293
/// units carry one as of 2026-09-13 — 2:255, the screenshot route's ayah, among them — and
/// the rest read their `meaning` until the pass reaches them.
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
