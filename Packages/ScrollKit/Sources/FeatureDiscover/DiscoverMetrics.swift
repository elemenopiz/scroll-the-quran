import DesignSystem
import Foundation
import QuranData
import SwiftUI

/// Discover card geometry, measured from `Reference/discover-dark.png`
/// (1179x2556 px for 393x852 pt, so pt = px / 3).
///
/// **Fixed slots (Phase 4i).** Every card is the same height with the same slots, so the
/// pager lands identically on each one. Everything below the chip sits in a slot whose
/// height comes from the font metrics at the default content size, and each slot's text
/// carries the matching `lineLimit`, so a one-ayah unit and the longest of the 326 build
/// exactly the same card. `DiscoverCardLayout` is that arithmetic, asserted over the whole
/// corpus by `DiscoverCardLayoutTests`.
///
/// Under Dynamic Type the fonts grow, the slots are `minHeight` rather than `height`, and
/// the card grows with them — which is what Phase 4d's scaling asks for.
enum DiscoverMetrics {
    /// Card fill `#1E1E23` runs x = 48..1130 px, i.e. the 16 pt page margin.
    static let cardInset = Metrics.cardInset
    /// Card top 360 px → theme chip top 420 px: 60 px of padding.
    static let cardPadding: CGFloat = 20

    // MARK: Type

    /// The card title.
    ///
    /// Measured off `Reference/discover-dark.png`, twice: "James 1:2-3" runs y = 549..614 px
    /// from the top of the `J` (cap height, 670/1000 em in Source Serif 4) to the baseline,
    /// which is 65 px = 21.7 pt of cap for a 97 px = 32.3 pt em; and its ink box is 487 px
    /// wide against a 5050/1000 em advance, which is a 96.4 px = 32.1 pt em. 32 pt it is.
    /// It was 44 pt, which is why the owner read "the chapters label" as too big — at 44 pt
    /// a surah name plus its numbers also hit `minimumScaleFactor` and shrank, so no two
    /// cards drew the title at the same size.
    static let referenceSize: CGFloat = 32
    /// One line, shrinking to 70 % for the longest surah names ("Al-Mutaffifin 83:1-3").
    static let referenceMinimumScale: CGFloat = 0.7
    /// MEANING body: line pitch 70 px = 23.3 pt at 1.371 em.
    static let bodySize: CGFloat = 17
    /// Discover card action icons, measured off `Reference/discover-dark.png` rather than
    /// estimated: the row's ink runs y = 1978..2045 px (22.4 pt tall) and the bookmark
    /// glyph is 42 px (14.0 pt) wide, which for SF Symbols is a **21 pt** glyph — the brief
    /// guessed 26, and 26 draws them 22 % too large. The four centres sit at 88.5, 160.3,
    /// 232.5 and 304.3 pt: 72 pt apart, centred on the card's own centre line (196.5), not
    /// spread evenly across the card's width.
    static let actionIcon: CGFloat = 21
    static let actionColumnWidth: CGFloat = 72

    // MARK: Slots

    static let quoteLines = 4
    static let meaningLines = 4
    static let didYouKnowLines = 3

    // MARK: Vertical rhythm

    /// chip → title. The title's line box carries 11.7 pt of leading above the cap at
    /// 32 pt, so 4 pt of padding is the reference's 17 pt of *ink* gap.
    static let chipToTitle = Spacing.xs
    /// title → quote. The reference has its `KJV` badge in this gap; ours does not
    /// (owner, Phase 4i amendment 2), so the padding absorbs it and the quote's first
    /// line still lands on the reference's y.
    static let titleToQuote = Spacing.xl
    /// quote → MEANING (reference 10.5 pt), label → body (3.1), body → DID YOU KNOW
    /// (10.2), box → chips (11.3).
    static let quoteToMeaning = Spacing.md
    static let labelToBody = Spacing.xs
    static let bodyToDidYouKnow = Spacing.md
    static let didYouKnowToChips = Spacing.md
    /// chips → "Deep study ›". The link is a 44 pt hit target with the text centred in it,
    /// so its own padding is the visible gap; the reference's chips and link boxes touch.
    static let chipsToDeepStudy: CGFloat = 0
    /// "Deep study ›" → the action row.
    static let deepStudyToActions = Spacing.sm

    /// Padding inside the DID YOU KNOW box (reference 11.3 pt) and the gap under its label
    /// (2.8 pt) — tighter than the generic `TintedSectionBox`, which is why they are here.
    static let didYouKnowPadding = Spacing.md
    static let didYouKnowLabelGap = Spacing.xs

    // MARK: Page

    /// Where the card sits on the page.
    ///
    /// `Reference/discover-dark.png`: the card fill runs y = 360..2141 px, i.e. 120..714 pt
    /// of an 852 pt screen — 14.08 % to 83.8 %. The card is a fixed *point* height (see
    /// `DiscoverCardLayout.cardHeight`), not a fraction of the screen, so it is centred on
    /// the page and nudged down to put its top edge on the reference's 14 %.
    static let cardTopFraction: CGFloat = 0.1408
    /// Downward nudge applied to the page so the centred card's top edge lands on
    /// `cardTopFraction`. A `.padding(.top, n)` on a centred child moves it by n/2.
    static let pageTopBias: CGFloat = 4
    /// Minimum air above and below the card on a short screen.
    static let pagePadding: CGFloat = Spacing.xxl
}

/// The card's fixed-slot arithmetic, in points, at the default content size.
///
/// Kept out of the views so a test can total it without a render pass:
/// `DiscoverCardLayoutTests` lays every one of the 326 Discover units out with the real
/// registered fonts and asserts each block clamps into its slot, so every card is
/// `cardHeight` tall and the pager lands identically on all of them.
enum DiscoverCardLayout {
    /// Source Serif 4's line box: hhea ascent 1036, descent −335, line gap 0, per 1000 em.
    /// Both the Roman and the Italic file carry it, so the quote and the prose share it.
    /// `DiscoverCardLayoutTests` checks this against the registered font.
    static let serifLineRatio: CGFloat = 1.371

    /// The SF Pro line box a `CapsLabel` occupies at 11 pt, and the taller one it occupies
    /// when it carries a 13 pt symbol (the DID YOU KNOW lightbulb).
    static let capsLabelHeight: CGFloat = 13.1
    static let capsLabelWithIconHeight: CGFloat = 15.5

    static func lineHeight(_ size: CGFloat) -> CGFloat {
        size * serifLineRatio
    }

    static func slot(lines: Int, size: CGFloat) -> CGFloat {
        CGFloat(lines) * lineHeight(size)
    }

    static var titleSlot: CGFloat {
        lineHeight(DiscoverMetrics.referenceSize)
    }

    static var quoteSlot: CGFloat {
        slot(lines: DiscoverMetrics.quoteLines, size: VerseText.Size.discover.english)
    }

    static var meaningSlot: CGFloat {
        slot(lines: DiscoverMetrics.meaningLines, size: DiscoverMetrics.bodySize)
    }

    static var didYouKnowSlot: CGFloat {
        slot(lines: DiscoverMetrics.didYouKnowLines, size: DiscoverMetrics.bodySize)
    }

    /// The DID YOU KNOW box, outer edge to outer edge.
    static var didYouKnowBox: CGFloat {
        2 * DiscoverMetrics.didYouKnowPadding
            + capsLabelWithIconHeight
            + DiscoverMetrics.didYouKnowLabelGap
            + didYouKnowSlot
    }

    /// Every card is this tall. The one number this whole task is about.
    static var cardHeight: CGFloat {
        2 * DiscoverMetrics.cardPadding
            + Metrics.chipHeight
            + DiscoverMetrics.chipToTitle + titleSlot
            + DiscoverMetrics.titleToQuote + quoteSlot
            + DiscoverMetrics.quoteToMeaning + capsLabelHeight
            + DiscoverMetrics.labelToBody + meaningSlot
            + DiscoverMetrics.bodyToDidYouKnow + didYouKnowBox
            + DiscoverMetrics.didYouKnowToChips + Metrics.crossRefChipHeight
            + DiscoverMetrics.chipsToDeepStudy + Metrics.hitTarget
            + DiscoverMetrics.deepStudyToActions + Metrics.hitTarget
    }

    /// The width a slot's text is laid out in: the screen less the page margin on each
    /// side and the card's own padding on each side.
    static func contentWidth(screenWidth: CGFloat) -> CGFloat {
        screenWidth - 2 * DiscoverMetrics.cardInset - 2 * DiscoverMetrics.cardPadding
    }
}

/// A cross-reference chip: the passage and the name to print on it.
struct ReferenceChip: Identifiable, Hashable {
    let passage: PassageRef
    let title: String

    var id: String {
        passage.key
    }
}
