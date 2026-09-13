import DesignSystem
import SwiftUI

/// One full-height page of the reader: the logo card, the verse block — muted Arabic above
/// the English, per CLAUDE.md rule 5 — and the reference line under it.
///
/// The verse block is centred at 57.7 % of the page height, so paging never moves the type:
/// measured from `reader-dark.png`, where the block spans y 409..528 pt of a 710 pt page. The
/// logo card is pinned 71 pt down, which is 28 pt below the toolbar.
///
/// **Phase 4n put the card on every page, which made 57.7 % a *preference* rather than a
/// rule.** On the opening card the block is three lines and 57.7 % clears the card by 200 pt.
/// A long ayah at the reader's 23 pt is a 500 pt block, and centring *that* on 57.7 % ran its
/// first Arabic line straight through the card (seen on 2:255 in Pickthall). So the block is
/// measured and the centre is clamped: never higher than clear of the card, never lower than
/// clear of the bottom margin, and 57.7 % whenever both allow — which every page that has a
/// reference capture does, so `reader-dark` does not move (0.0386839 before and after).
struct VersePageView: View {
    let page: ReaderPage
    /// The pager's container size, read once by `ReaderView` rather than by every page.
    let pageSize: CGSize
    /// Tapping the logo card raises the verse menu (Phase 4n). Nil in previews, where there
    /// is no model to present it and the card stays the decorative mark it used to be.
    var onLogoTap: (() -> Void)?

    /// The block's measured height, which is what the clamp below needs and what SwiftUI
    /// will not tell a `.position` on its own. Zero until the first layout pass; the ideal
    /// centre wins at zero, which is what every short page settles on anyway.
    @State private var blockHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            if page.showsLogoCard {
                ReaderLogoCard(onTap: onLogoTap)
                    .padding(.top, Self.logoCardTop)
            }
            verseBlock
                .frame(width: max(0, pageSize.width - 2 * ReaderMetrics.versePadding))
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: VerseBlockHeightKey.self, value: proxy.size.height)
                    }
                }
                .position(x: pageSize.width / 2, y: verseCentreY)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .onPreferenceChange(VerseBlockHeightKey.self) { blockHeight = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.page.\(page.id.surah).\(page.id.ayah).\(page.id.part)")
    }

    /// Toolbar inset (7) + toolbar height (36) + the measured 28 pt below it.
    static let logoCardTop = ReaderMetrics.toolbarTopInset
        + ReaderMetrics.toolbarHeight
        + ReaderMetrics.logoCardTopFromToolbar

    /// Where the verse block's centre actually lands. Pure, and exercised directly by
    /// `VersePageGeometryTests` — the collision this fixes is arithmetic, not a look.
    var verseCentreY: CGFloat {
        Self.verseCentreY(
            blockHeight: blockHeight,
            pageHeight: pageSize.height,
            showsLogoCard: page.showsLogoCard
        )
    }

    /// 57.7 % of the page, clamped clear of the logo card above and the page's bottom margin
    /// below.
    ///
    /// The clamps are ordered: clearing the card wins when a block is too tall to satisfy
    /// both, because a verse whose opening line is legible and whose tail runs long is a page
    /// the reader can still read, and one whose first line is under the mark is not.
    static func verseCentreY(
        blockHeight: CGFloat,
        pageHeight: CGFloat,
        showsLogoCard: Bool
    ) -> CGFloat {
        let ideal = pageHeight * ReaderMetrics.verseCentreFraction
        guard showsLogoCard, blockHeight > 0 else { return ideal }
        let cardBottom = logoCardTop + ReaderMetrics.logoCardSize + ReaderMetrics.logoCardToVerse
        let lowest = cardBottom + blockHeight / 2
        let highest = pageHeight - ReaderMetrics.verseBottomMargin - blockHeight / 2
        return min(max(ideal, lowest), max(lowest, highest))
    }

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
        ),
        pageSize: CGSize(width: 393, height: 710)
    )
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

/// The verse block's laid-out height, reported up out of the `ZStack` so the page can clamp
/// the block's centre against it.
private struct VerseBlockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
