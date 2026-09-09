import DesignSystem
import SwiftUI

/// Geometry measured off `Reference/community-dark.png` (1179x2556 px = 393x852 pt @3x, so
/// **pt = px / 3**), the same way `DesignSystem/Components/README.md` records its numbers.
/// Every value names the scan that produced it so a re-measure is one edit.
enum CommunityMetrics {
    /// Community insets its cards 60 px, not the 48 px (16 pt) the Home rows use.
    /// Row y=560: the green card runs x=60..1113.
    static let pageMargin: CGFloat = 20
    /// Col x=70: the green card runs y=306..832 → 176 pt tall.
    static let givingCardHeight: CGFloat = 176
    /// Card top 306 px → caps-label cap top 385 px, and the subline's line box ends 25 pt above
    /// the card's bottom edge. Top and bottom differ by a couple of points; the sides are 22.
    static let givingCardPaddingTop: CGFloat = 24
    static let givingCardPaddingBottom: CGFloat = 25
    static let givingCardPaddingSide: CGFloat = 22
    /// Caps-label line box bottom → the amount's line box top.
    static let givingLabelToAmount: CGFloat = 3
    /// Amount line box bottom → the rule (divider centre at 216.7 pt), and rule → subline.
    static let givingAmountToRule: CGFloat = 5
    static let givingRuleToSubline: CGFloat = 11
    /// The hairline between the amount and the subline: 83x6 px of white at 25 %.
    static let givingDividerWidth: CGFloat = 28
    static let givingDividerHeight: CGFloat = 2

    /// Scroll top inset: the card's top edge sits at 102 pt, 43 pt below the 59 pt safe area.
    static let scrollTopInset: CGFloat = 43
    /// Green card bottom 277.3 pt → headline line top 301.4 pt.
    static let titleTopGap: CGFloat = 24
    /// Headline line bottom 341 pt → body line top 348.9 pt.
    static let bodyTopGap: CGFloat = 8
    /// Body block bottom 401.7 pt → first organisation card top 414.3 pt.
    ///
    /// The 12.6 pt that measures is the gap below the last *glyph*; SwiftUI applies the padding
    /// below the text's *layout* box, whose bottom sits ~11 pt above the visual one (the trailing
    /// line's leading). 13 put the first card at 402.9 pt in reference space instead of 414.3 —
    /// the gap `CommunityTests.testGivingCardAndVoteButtonMatchTheReferenceGeometry` measures,
    /// which only started running when Phase 3e wired the tab in.
    static let cardsTopGap: CGFloat = 24
    /// Only one organisation card is visible in the reference; the gap follows the Home stack.
    static let cardSpacing: CGFloat = 20

    /// Col x=300: the charity image runs y=1243..1722 → 160 pt tall on a 353 pt card.
    static let charityImageHeight: CGFloat = 160
    /// Card left 60 px → first glyph 108 px.
    static let charityCardPadding: CGFloat = 16
    /// Name line top 590.4 pt → tagline line top 610.9 pt.
    static let charityTitleSpacing: CGFloat = 2
    /// Tagline bottom ≈ 625.5 pt → divider 635.7 pt → description top 646.6 pt.
    static let charityDividerGap: CGFloat = 10

    /// The green pill: x=895..1070, y=1771..1859 → 58.7 x 29.3 pt.
    static let voteButtonWidth: CGFloat = 59
    static let voteButtonHeight: CGFloat = 29

    // MARK: Type sizes (cap heights measured off the capture, divided by the font's cap ratio)

    /// "GIVEN TO MINISTRIES": cap 22 px = 7.33 pt / 0.714 (SF Pro capHeight) ≈ 10.3.
    static let capsSize: CGFloat = 10
    /// "$59,185": figure height 97 px = 32.3 pt / 0.67 (Source Serif capHeight) ≈ 48; the "$"
    /// spans 123 px = 41 pt, which pins it at 49.
    static let amountSize: CGFloat = 49
    /// "Every dollar from JCBSN apps": cap 26 px = 8.67 pt / 0.714 ≈ 12.1.
    static let sublineSize: CGFloat = 12
    /// Line pitch 52 px = 17.33 pt against a 14.3 pt line box.
    static let sublineLineSpacing: CGFloat = 3
    /// "Vote Who We Give To": cap 59 px = 19.67 pt / 0.67 ≈ 29.4.
    static let titleSize: CGFloat = 29
    /// Body copy: cap 28 px = 9.33 pt / 0.714 ≈ 13.1; pitch 56 px = 18.67 pt.
    static let bodySize: CGFloat = 13
    static let bodyLineSpacing: CGFloat = 3
    /// Organisation name: cap 31 px = 10.33 pt / 0.714 ≈ 14.5.
    static let charityNameSize: CGFloat = 15
    /// Tagline: ascender 27 px = 9 pt / 0.75 ≈ 12.
    static let charityFocusSize: CGFloat = 12
    /// Description: cap 27 px = 9 pt / 0.714 ≈ 12.6; pitch 59 px = 19.67 pt.
    static let charityBlurbSize: CGFloat = 13
    static let charityBlurbLineSpacing: CGFloat = 4
    /// "Vote": ~72 px of ink for four characters.
    static let voteLabelSize: CGFloat = 13
}

/// The four colours this screen adds to the palette, measured off `community-dark.png` the same
/// way `Tokens.swift`'s were. They are **brand** colours, not surfaces: like `Color.offlineBadge`
/// and the flame gradient they are the same in both appearances, so the light build derives from
/// the tokens (background, card, text) and keeps the green card exactly as it is.
///
/// They live here rather than in `Tokens.swift` only because `DesignSystem` is out of this task's
/// scope; they belong there next to the other measured accents.
enum CommunityPalette {
    /// Fitted from a grid of samples inside the card: `#357956` at t≈0.03 and `#0D2F22` at
    /// t≈0.97 along the top-leading → bottom-trailing diagonal.
    static let givingTop = Color(rgb: 0x367C58)
    static let givingBottom = Color(rgb: 0x0C2D21)
    /// The pill behind "Vote", sampled flat across x=895..1070, y=1771..1859.
    static let voteFill = Color(rgb: 0x2A5D3F)
    /// The label inside it.
    static let voteLabel = Color(rgb: 0x0C1B13)

    /// The green card's gradient, top-leading to bottom-trailing.
    static let giving = LinearGradient(
        colors: [givingTop, givingBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Text on the green card. The amount is pure white; the caps label and the subline are
    /// measured at ~85 % (`#D7E2DD` over the fitted background).
    static let onGiving = Color.white
    static let onGivingMuted = Color.white.opacity(0.85)
    /// The 83x6 px hairline: white at 25 % over the gradient.
    static let givingDivider = Color.white.opacity(0.25)
}
