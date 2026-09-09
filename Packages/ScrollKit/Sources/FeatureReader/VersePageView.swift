import DesignSystem
import SwiftUI

/// One full-height page of the reader: the logo card (opening page only), the verse block —
/// muted Arabic above the English, per CLAUDE.md rule 5 — and the reference line under it.
///
/// The verse block is centred at 57.7 % of the page height on every page, so paging never
/// moves the type: measured from `reader-dark.png`, where the block spans y 409..528 pt of a
/// 710 pt page. The logo card is pinned 71 pt down, which is 28 pt below the toolbar.
struct VersePageView: View {
    let page: ReaderPage

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if page.showsLogoCard {
                    ReaderLogoCard()
                        .padding(.top, Self.logoCardTop)
                }
                verseBlock
                    .frame(width: max(0, proxy.size.width - 2 * ReaderMetrics.versePadding))
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height * ReaderMetrics.verseCentreFraction
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.page.\(page.id.surah).\(page.id.ayah).\(page.id.part)")
    }

    /// Toolbar inset (7) + toolbar height (36) + the measured 28 pt below it.
    static let logoCardTop = ReaderMetrics.toolbarTopInset
        + ReaderMetrics.toolbarHeight
        + ReaderMetrics.logoCardTopFromToolbar

    private var verseBlock: some View {
        VStack(spacing: ReaderMetrics.verseReferenceSpacing) {
            if !page.english.isEmpty || page.arabic != nil {
                VerseText(
                    arabic: page.arabic,
                    english: page.english,
                    size: ReaderTypeRamp.size(for: page.tier)
                )
                .accessibilityIdentifier("reader.verse")
            }
            Text(referenceLine)
                .font(.body(ReaderMetrics.referenceFontSize, weight: .semibold))
                .tracking(ReaderMetrics.referenceTracking)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("reader.reference")
        }
    }

    /// `"Al-Baqarah 2:255"`, with `"(2/3)"` appended while a long ayah is being paged through.
    private var referenceLine: String {
        guard let caption = page.caption else { return page.reference }
        return "\(page.reference) \(caption)"
    }
}

#Preview("Verse page") {
    VersePageView(
        page: ReaderPage(
            id: ReaderPageID(surah: 94, ayah: 5),
            kind: .verse,
            arabic: VersePreviewFixture.shortArabic,
            english: "With hardship comes ease.",
            reference: "Ash-Sharh 94:5"
        )
    )
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
