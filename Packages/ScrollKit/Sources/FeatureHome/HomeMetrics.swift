import DesignSystem
import SwiftUI

/// Geometry measured off the Home references, in the same way as
/// `DesignSystem/Components/README.md`: `home-dark.png` is 1179x2556 px for a 393x852 pt screen
/// (pt = px / 3) and is read directly; the light Home only exists inside the phone-frame mockup
/// on `onboarding-slide4-search.png`, so those numbers come from the frame's screen window
/// (x 256..920, y 754..2170 px → 665 px for 393 pt) and carry the mockup's ~2 % vertical stretch.
///
/// Anything this feature hard-codes lives here. `Metrics` (DesignSystem) owns whatever a shared
/// component hard-codes; this is only the Home-specific spine.
enum HomeMetrics {
    // MARK: The card stack (home-dark, column density scan over x 400..1100)

    /// Card runs measured on home-dark: streak 124.7..308.7, progress 334.3..483.7,
    /// rows 504.0..575.7 and 596.0..667.7, pill 688..739.7. The gaps are 26 between the two
    /// stat cards and 20 from there down.
    static let cardGap: CGFloat = 26
    static let rowGap: CGFloat = 20
    /// Top of the hero card: 73.4 pt on a 59 pt safe area.
    static let contentTopPadding: CGFloat = 13
    /// The pill sits 29 pt above the tab bar at the bottom of the scroll (home-dark: pill
    /// 688..739.7 against a 769 pt viewport bottom). Both the reference and this build come to
    /// rest at the end of the content in the scrolled capture, so this padding is what sets
    /// where the whole stack lands.
    static let contentBottomPadding: CGFloat = 38

    // MARK: Hero (Verse Search) card

    /// The magnifier above the title: ink 85.4..111.3 pt.
    static let searchGlyph: CGFloat = 26
    /// "Verse Search", ink 130.5..154.6 pt (cap height 24 pt → ~34 pt Source Serif).
    static let searchTitle: CGFloat = 34
    static let searchSubtitle: CGFloat = 15
    static let searchTab: CGFloat = 17
    /// The 2 pt rule under the selected tab, 6 pt below its baseline.
    static let tabUnderline: CGFloat = 2
    /// "Study This Verse": 413.3..462.6 pt → 49 pt tall.
    static let studyPillHeight: CGFloat = 50
    static let searchHint: CGFloat = 13
    static let searchFootnote: CGFloat = 11

    // MARK: Today's Reading card

    /// Cover: 125 pt square, 14 pt in from the card edge.
    static let todayCover: CGFloat = 125
    static let todayCoverRadius: CGFloat = 18
    static let todayCardPadding: CGFloat = 16
    static let todayTitle: CGFloat = 22
    /// The bar under the card is noticeably chunkier than the 10 pt one on the stat card:
    /// 734.6..754.1 pt.
    static let todayProgressHeight: CGFloat = 18

    // MARK: Streak week row (home-dark)

    /// The dot strip on home-dark runs 263.3..297.0 pt including the ring around today, over
    /// letters whose ink is 248.7..256.0 — a 7.3 pt cap height, so an 11 pt semibold.
    static let streakDot: CGFloat = 26
    static let streakRing: CGFloat = 32
    static let streakRingWidth: CGFloat = 3
    static let streakLetter: CGFloat = 11
    /// Letters to dots, and the footer's own rhythm. The whole card is 184 pt tall
    /// (124.7..308.7) and `StatCard` spends 18 + header + 16 of that before the footer starts.
    static let streakLetterGap: CGFloat = 4
    static let statFooterSpacing: CGFloat = 6
    /// The line under the count (ink 217.0..229.0) and the verse count under the bar
    /// (453.0..464.7): one line each, spanning the card's full inner width.
    static let streakMessage: CGFloat = 14

    // MARK: Settings pill

    /// "Settings / Manage Accounts" is set in the serif, not the geometric sans the shared
    /// `PrimaryPillButton` uses, so Home draws its own capsule on the same tokens.
    static let settingsPillText: CGFloat = 21

    // MARK: Sheets

    /// Plan detail hero: full width inside the page margin, roughly 2:1.
    static let planHeroAspect: CGFloat = 1.95
    static let planHeroRadius: CGFloat = 20
    /// Two columns with a 14 pt gutter in the plans grid.
    static let planGridSpacing: CGFloat = 14
    /// Section to section in the plans sheet. The reference's first eyebrow sits 21 pt under the
    /// active-plan card (card edge ~325, "FOR NEW READERS" ink at 346).
    static let planSectionSpacing: CGFloat = 22
    /// The cover on the active-plan card (reference: 175..300 pt inside the card).
    static let activePlanCover: CGFloat = 118
    /// The plan detail's "Close" row sits lower than a plain sheet header: the reference has
    /// the pill centred at 108 pt and the hero starting at 145.
    static let planDetailHeaderTop: CGFloat = 14

    // MARK: Snapshot routing

    /// How much of the Today's Reading card is still on screen in the `home#scrolled` capture:
    /// the reference has that card's bottom edge at 98.7 pt with a 59 pt safe area above it.
    /// The content is barely longer than the viewport, so the scroll usually comes to rest at
    /// its end before reaching this anchor; it is the ceiling, not the resting place.
    static let scrolledFragment: CGFloat = 40
}

/// One colour Home needs that `Tokens` does not carry yet.
///
/// `#8A7561` is the brown fill behind the book glyph on the "% Quran read" card, measured off
/// `home-dark.png` (the same value `DesignSystem`'s own `StatCard` preview uses). It belongs in
/// `Tokens.swift` next to `flameTop`/`flameBottom`; until DesignSystem adds it, it is spelled
/// once, here, rather than inline at the call site.
enum HomeTokens {
    static let readEmblem = Color(rgb: 0x8A7561)
}
