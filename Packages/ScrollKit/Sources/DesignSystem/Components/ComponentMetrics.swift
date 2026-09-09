import SwiftUI

/// Component geometry measured off `Reference/*.png` (1179x2556 px = 393x852 pt @3x,
/// so **pt = px / 3**). Every number here is traceable to a screen id and a scan line;
/// the full table with the raw pixel runs is in `Components/README.md`.
///
/// Anything a component hard-codes belongs here, not inline, so a re-measure is one edit.
public enum Metrics {
    // MARK: Pills

    /// Onboarding CTA ("Continue", onboarding-hook): 168 px tall.
    public static let pillHeight: CGFloat = 56
    /// Paywall CTA ("Redeem 7 days…", paywall-trial): 195 px tall.
    public static let pillHeightLarge: CGFloat = 65
    /// Home "Settings / Manage Accounts": 156 px tall.
    public static let pillHeightCompact: CGFloat = 52
    /// The onboarding CTAs are inset far more than the 16 pt page margin (157 px).
    public static let ctaInsetOnboarding: CGFloat = 52
    /// Gap between the outline pill and the primary pill on onboarding-hook (29 px).
    public static let ctaStackSpacing: CGFloat = 10

    // MARK: Chips and small capsules

    /// Discover theme chip "Joy in Trials": 79 px tall.
    public static let chipHeight: CGFloat = 26
    /// Deep Study cross-reference chip: 1 px hairline, 30 pt tall.
    public static let crossRefChipHeight: CGFloat = 30
    /// Reader toolbar capsule `[dice][heart]`: 106 px tall.
    public static let capsuleGroupHeight: CGFloat = 36
    /// Glyph size inside the reader toolbar capsule (40 px).
    public static let capsuleGroupIcon: CGFloat = 14
    /// Horizontal padding around each icon inside the grouped capsule.
    public static let capsuleGroupItemPadding: CGFloat = 11
    /// Translation-sheet "Offline" badge: 47 px tall.
    public static let badgeHeight: CGFloat = 16

    // MARK: Circles

    /// Deep Study header buttons (check / close): 132 px.
    public static let headerButton: CGFloat = 44
    /// Paywall timeline node: 120 px.
    public static let timelineNode: CGFloat = 40
    /// Paywall timeline connector: 6 px wide, `#D3D1C7`.
    public static let timelineConnector: CGFloat = 2
    /// Home `RowLink` leading circle: 120 px.
    public static let rowLinkIcon: CGFloat = 40
    /// Home `StatCard` leading circle: 168 px.
    public static let statIcon: CGFloat = 56

    // MARK: Cards and boxes

    /// Every full-bleed card sits 16 pt in from the screen edge (48 px) → 361 pt wide.
    public static let cardInset: CGFloat = Spacing.pageMargin
    /// Padding inside a `StatCard` (54 px from card edge to the icon circle).
    public static let cardPadding: CGFloat = 18
    /// Padding inside a `RowLink` (48 px from card edge to the icon circle).
    public static let rowPadding: CGFloat = 16
    /// Home `RowLink` height: 200 px.
    public static let rowLinkHeight: CGFloat = 67
    /// Deep Study section boxes are inset 24 pt (72 px) → 345 pt wide.
    public static let sectionBoxInset: CGFloat = 24
    /// Padding inside a `TintedSectionBox`.
    public static let sectionBoxPadding: CGFloat = 20
    /// `ReviewCard` left accent bar: 9 px.
    public static let accentBarWidth: CGFloat = 3
    /// Home progress bar track: 30 px tall.
    public static let progressBarHeight: CGFloat = 10

    // MARK: Rows of actions

    /// Discover card action icons (bookmark / comment / share / check).
    public static let actionIcon: CGFloat = 24
    /// Reader hint toast: 182 px tall, 642 px wide.
    public static let toastHeight: CGFloat = 61

    // MARK: Device mockup

    /// onboarding-slide2: outer frame 740 px, screen 665 px, so the bezel is 10 pt.
    public static let phoneFrameWidth: CGFloat = 247
    public static let phoneScreenWidth: CGFloat = 222
    public static let phoneBezel: CGFloat = 10
    /// A 393x852 pt screen rendered 222 pt wide.
    public static let phoneScreenAspect: CGFloat = 393.0 / 852.0

    // MARK: Wheels

    /// `WheelPicker3` row height and visible-row count (iOS wheel convention).
    public static let wheelRowHeight: CGFloat = 34
    public static let wheelHeight: CGFloat = 170
}
