import CoreGraphics
import DesignSystem

/// Reader geometry measured off `Reference/reader-dark.png` (1179x2556 px for a 393x852 pt
/// screen, so **pt = px / 3**), the same way `DesignSystem/Components/ComponentMetrics.swift`
/// was measured. Every number names the scan that produced it, so a re-measure is one edit.
///
/// Positions are stored **relative to the safe area**, not to the screen, because that is what
/// the layout can actually anchor to. The reference device's insets are top 59 pt and
/// bottom 83 pt (tab bar plus home indicator), so a screen-space y of 117 pt is written here
/// as `safeAreaTop + 58`.
public enum ReaderMetrics {
    // MARK: - Reference frame

    /// The screen the reference captures were taken on.
    public static let referenceSize = CGSize(width: 393, height: 852)
    /// Safe-area insets on that device, inside a tab bar.
    public static let referenceTopInset: CGFloat = 59
    public static let referenceBottomInset: CGFloat = 83

    // MARK: - Toolbar

    // Row of chrome, all four items centred on y = 83.8 pt (col scans at x = 40/300/800/1000).

    /// Capsule group top is 198 px = 66 pt, i.e. 7 pt below the safe-area top.
    public static let toolbarTopInset: CGFloat = 7
    /// `[dice][heart]` capsule: 106 px tall, x 30..239 px.
    public static let toolbarHeight = Metrics.capsuleGroupHeight
    /// Capsule starts at x = 30 px, the surah pill ends 10.3 pt from the right edge.
    public static let toolbarSideMargin: CGFloat = 10
    /// 255 px − 239 px = 16 px between the capsule group and the translation pill.
    public static let toolbarLeadingSpacing: CGFloat = 5
    /// 875 px − 856 px = 19 px between the bookmark circle and the surah pill.
    public static let toolbarTrailingSpacing: CGFloat = 6
    /// Translation pill ("KJV"): 88 px tall, 131 px wide.
    public static let translationPillHeight: CGFloat = 29
    public static let translationPillMinWidth: CGFloat = 44
    /// Surah pill ("Romans 5 ⌄"): 90 px tall, 273 px wide.
    public static let surahPillHeight: CGFloat = 30
    /// Bookmark: a 107 px circle, the same height as the capsule group.
    public static let bookmarkDiameter = Metrics.capsuleGroupHeight
    /// Glyph inside the bookmark circle.
    public static let toolbarGlyph: CGFloat = 15
    /// The surah pill's chevron, a step smaller than the bookmark glyph.
    public static let toolbarChevronGlyph: CGFloat = 11
    /// Label inside the translation and surah pills.
    public static let toolbarLabel: CGFloat = 15
    /// The pills are drawn at their measured 29-36 pt but take taps over the HIG's 44 pt.
    public static let hitTarget: CGFloat = 44

    // MARK: - Surah opening card

    // Logo card fill runs x 449..730, y 390..671 px: a 281 px (93.7 pt) square.

    /// The reference card is 93.7 pt. Phase 4e's accepted deviation, on the owner's
    /// direction that the mark should read bigger inside the app: 112 pt, with the ring at
    /// 0.80 of it (`CARD_SCALE` in `Artwork/tools/logo.sh` matches, so the shipped
    /// `LogoCard` artwork is pixel-exact at 112 pt @1x/@2x/@3x).
    public static let logoCardSize: CGFloat = 112
    /// The mark inside it: 0.80 of the card, an 11.2 pt inset on each side.
    public static let logoMarkSize: CGFloat = 90
    /// Card top is 390 px = 130 pt, 28 pt below the toolbar's 101.7 pt bottom edge.
    public static let logoCardTopFromToolbar: CGFloat = 28
    /// Corner inset reaches zero at dy ≈ 55 px and is 16 px at dy = 12 px — a 48 px (16 pt) corner.
    public static let logoCardRadius = Radius.chip

    // MARK: - Verse block

    // Three lines of ink at y 1227/1318/1408 px (30 pt pitch, 23 pt English) and the
    // reference line at 1555..1585 px.

    /// The widest line runs x 103..1070 px, so the text column is inset ~32 pt each side.
    public static let versePadding: CGFloat = 32
    /// Verse ink ends 1458 px, the reference line starts 1555 px: 97 px = 32.3 pt.
    public static let verseReferenceSpacing = Spacing.xxxl
    /// Verse + reference span y 409..528 pt, centred on 468.6 pt, which is 57.7 % of the way
    /// down the 710 pt page (safe-area top 59 to safe-area bottom 769).
    public static let verseCentreFraction: CGFloat = 0.577
    /// "Romans 5:1" has a 31 px (10.3 pt) cap height and is set wide.
    public static let referenceFontSize: CGFloat = 15
    public static let referenceTracking = Tracking.capsTight

    // MARK: - Verse rail

    // 21 segments for Romans 5's 21 verses: 84 px dashes on a 90 px pitch, y 351..2231 px.

    /// Track runs x 21..29 px, the solid indicator x 18..32 px; both centred on x = 8.33 pt.
    public static let railCentreX: CGFloat = 8.5
    public static let railTrackWidth: CGFloat = 3
    public static let railIndicatorWidth: CGFloat = 5
    /// 90 px pitch − 84 px dash.
    public static let railGap: CGFloat = 2
    /// Rail top is 351 px = 117 pt, 15 pt below the toolbar's bottom edge.
    public static let railTopFromToolbar: CGFloat = 15
    /// The same measurement from the safe-area top: 7 + 36 + 15 = 58 pt (117 − 59).
    public static let railTopInset = toolbarTopInset + toolbarHeight + railTopFromToolbar
    /// Rail bottom is 2231 px = 743.7 pt, 25 pt above the safe-area bottom (769 pt).
    public static let railBottomInset: CGFloat = 25
    /// The ayah number sits beside the rail: "1" at x 45..55 px, "21" at x 41..68 px.
    public static let railNumberLeading: CGFloat = 14
    public static let railNumberSize: CGFloat = 10
    /// The invisible strip that takes taps and drags: wide enough for a finger.
    public static let railHitWidth: CGFloat = 44

    // MARK: - Action stack

    // Heart / comment / share glyphs centred at y 581 / 644.8 / 708.8 pt, x 353.8 pt.

    public static let actionGlyph = Metrics.actionIcon
    public static let actionButton: CGFloat = 44
    /// A 44 pt button centred on 353.8 pt leaves 17 pt to the right edge; the page margin wins.
    public static let actionTrailingInset = Spacing.lg
    /// 64 pt centre-to-centre with a 44 pt button.
    public static let actionSpacing = Spacing.xl
    /// The share button's bottom edge is 730.8 pt, 38 pt above the safe-area bottom.
    public static let actionBottomInset: CGFloat = 38

    // MARK: - Hint toast

    // 642 x 182 px at x 150..791, y 2014..2195 px.

    /// The reference toast is 642 px (214 pt) wide, and `ToastHint` sizes itself from its own
    /// measured paddings to within a few points of that — forcing the width instead wraps
    /// "Tap or slide" onto two lines, so the reader lets the component size itself.
    public static let toastLeadingInset: CGFloat = 50
    /// Toast bottom is 2195 px = 731.7 pt, 37 pt above the safe-area bottom.
    public static let toastBottomInset: CGFloat = 37

    // MARK: - Sheets

    // translation-sheet.png and notes-sheet.png, both 1179x2556.

    /// Divider at y 387 px runs x 48..1130 px: the 16 pt page margin on both sides.
    public static let sheetRowPadding: CGFloat = 20
    /// Title 691..726 px to subtitle 758..788 px.
    public static let sheetRowSpacing = Spacing.sm
    /// "NIV" has a 35 px (11.7 pt) cap height.
    public static let sheetRowTitleSize: CGFloat = 17
    /// "New International Version".
    public static let sheetRowSubtitleSize: CGFloat = 15
    /// The copyright block: three lines on a 36 px (12 pt) pitch.
    public static let sheetRowCopyrightSize: CGFloat = 13
    /// The translation sheet's "Done" pill: 51..279 px wide, 237..348 px tall.
    public static let sheetDoneWidth: CGFloat = 76
    public static let sheetDoneHeight: CGFloat = 37
    /// The row check mark, and the small glyphs in the surah picker.
    public static let sheetGlyph: CGFloat = 18
    public static let sheetSmallGlyph: CGFloat = 15
    /// Surah picker rows: number column, name, and the "The Cow · 286 verses · Medinan" line.
    public static let pickerNumberWidth: CGFloat = 28
    public static let pickerNumberSize: CGFloat = 13
    public static let pickerNameSize: CGFloat = 17
    public static let pickerSubtitleSize: CGFloat = 13
    public static let pickerFieldSize: CGFloat = 16

    /// Notes sheet: the editor fill runs x 48..1130, y 850..1466 px.
    public static let notesEditorHeight: CGFloat = 205
    public static let notesEditorRadius = Radius.cardSmall
    /// "Romans 5:12" has a 40 px (13.3 pt) cap height.
    public static let notesTitleSize: CGFloat = 19
    /// "Your Notes" / "Auto-saved" have a 31 px (10.3 pt) cap height.
    public static let notesLabelSize: CGFloat = 15
    /// The note the reader types.
    public static let notesBodySize: CGFloat = 16
    /// The muted verse above the editor, dimmed against the sheet.
    public static let notesVerseOpacity: CGFloat = 0.75

    // MARK: - Share card

    /// Square, so it drops into a story or a message without being re-cropped.
    public static let shareCardSide: CGFloat = 360
    public static let shareReferenceSize: CGFloat = 15
    /// The licence line the translation requires, set small but legible.
    public static let shareAttributionSize: CGFloat = 10
}
