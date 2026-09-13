import CoreGraphics
import DesignSystem

/// Geometry of the verse menu — the sheet that rises when the reader taps the logo card.
///
/// Measured off the owner's screenshot of the original (iPhone 402x874 pt, 2026-09-13). There
/// is no PNG of it on disk, so the numbers below record the measurement itself: every constant
/// names the screen-space y it came from, and everything is then expressed **relative to the
/// sheet's own top edge** (y 249 pt) because that is what the layout can anchor to.
public enum VerseMenuMetrics {
    // MARK: - The sheet

    /// The screen the measurements were taken on.
    public static let referenceSize = CGSize(width: 402, height: 874)
    /// The sheet's top edge is at y 249 pt, so it covers the bottom 71.5 % of the **screen**.
    public static let screenCoverage: CGFloat = 0.715

    /// How much of the screen a sheet's own container is.
    ///
    /// `presentationDetents(.fraction:)` is a fraction of the *sheet's* maximum height, not of
    /// the screen — iOS keeps an inset above even a `.large` sheet — so handing it 0.715
    /// lands the top edge well below the measurement. Measured on the reference device:
    /// `.fraction(0.715)` put the top edge at 291.0 pt of an 874 pt screen, so the container
    /// is (874 − 291) / 0.715 = 815.4 pt, which is 93.3 % of the screen.
    public static let sheetContainerRatio: CGFloat = 0.933

    /// What `presentationDetents` is actually handed, so the top edge lands on the measured
    /// 249 pt: 0.715 of the screen expressed as a fraction of the sheet's container (0.766).
    public static var detentFraction: CGFloat {
        screenCoverage / sheetContainerRatio
    }
    /// Corner inset reaches zero ~40 pt in; continuous, like every other card in the app.
    public static let cornerRadius: CGFloat = 40

    // MARK: - Cancel

    /// Pill at x 24..115, y 266..306 — 17 pt below the sheet's top edge.
    public static let cancelTop: CGFloat = 17
    public static let cancelLeading: CGFloat = 24
    public static let cancelWidth: CGFloat = 91
    public static let cancelHeight: CGFloat = 40
    /// "Cancel" is set at ~19 pt regular.
    public static let cancelLabelSize: CGFloat = 19

    // MARK: - Reference and verse preview

    /// The reference sits in the band around y 346, i.e. 30 pt under the Cancel pill's
    /// bottom edge (306).
    public static let referenceTopFromCancel: CGFloat = 30
    /// "Isaiah 40:31" is ~20 pt semibold; ours reads "Al-Baqarah 2:255".
    public static let referenceFontSize: CGFloat = 20

    /// The verse preview under it.
    public static let verseTopFromReference: CGFloat = 12
    /// Serif, ~14 pt, `textSecondary`: a preview of the ayah, not the reading text.
    public static let versePreviewEnglish: CGFloat = 14
    /// The muted Arabic layer above it (CLAUDE.md rule 5), at the canonical 58 % of the
    /// English with the legibility floor `VerseText` applies everywhere else.
    public static var versePreviewArabic: CGFloat {
        max(versePreviewEnglish * VerseText.arabicRatio, VerseText.arabicFloor)
    }

    /// The gap `VerseText` puts between the Arabic line and the English.
    public static var versePreviewSpacing: CGFloat {
        versePreviewEnglish * 0.5
    }

    /// It is a preview, so it elides rather than pushing the rows down the sheet.
    public static let versePreviewLineLimit = 4
    /// The text column is inset 24 pt each side, like the divider under it.
    public static let versePadding: CGFloat = 24

    // MARK: - Divider

    /// Hairline at y 448, inset 24 pt each side.
    public static let dividerInset: CGFloat = 24
    /// 448 is ~20 pt below a two-line preview; the block above is content-sized, so this is
    /// the gap rather than the absolute y.
    public static let dividerTopFromVerse: CGFloat = 20

    // MARK: - Rows

    /// The first row's top edge is y 470, 22 pt below the divider.
    public static let rowsTopFromDivider: CGFloat = 22
    /// Each row is 54 pt tall — over the 44 pt hit target on its own.
    public static let rowHeight: CGFloat = 54
    /// The icon is centred on x 39: a 30 pt column starting at the 24 pt page inset.
    public static let rowLeading: CGFloat = 24
    public static let rowIconColumn: CGFloat = 30
    /// SF Symbol at 22 pt regular, `textPrimary`.
    public static let rowIconSize: CGFloat = 22
    /// The label starts at x 68, which is 14 pt past the icon column's trailing edge (54).
    public static let rowIconToLabel: CGFloat = 14
    /// Where the label — and the separator under it — begins.
    public static var rowLabelLeading: CGFloat {
        rowLeading + rowIconColumn + rowIconToLabel
    }

    /// ~18 pt semibold, `textPrimary`.
    public static let rowLabelSize: CGFloat = 18
    /// The one subtitle in the menu ("Share as an image anywhere"), ~15 pt regular.
    public static let rowSubtitleSize: CGFloat = 15
    /// `chevron.right`, 15 pt semibold, `textTertiary`, its left edge on x 371.
    public static let rowChevronSize: CGFloat = 15
    /// 402 − 371 − a ~9 pt glyph leaves 22; the 24 pt page inset is within measurement noise
    /// and keeps the chevron on the same rail as the divider above it.
    public static let rowTrailing: CGFloat = 24
    /// Separators run from the label's x to 24 pt from the right edge.
    public static var separatorLeading: CGFloat {
        rowLabelLeading
    }

    public static let separatorTrailing: CGFloat = 24

    // MARK: - Destinations

    // The four screens the menu pushes are ours to design: the original has no capture of
    // them. They follow the app's own type scale rather than inventing one.

    /// "Explain Easier" body: serif running text, a step above Deep Study's 17 pt because
    /// the whole point of the screen is that it is short and easy to read.
    public static let explainBodySize: CGFloat = 19
    /// "Original Language": the one place the Uthmani line is the reading text, so it is set
    /// at reading size in `textPrimary` rather than at 58 % in `textTertiary`.
    public static let originalArabicSize: CGFloat = 30
    /// The English gloss under it, at the Deep Study quote size.
    public static let originalEnglishSize: CGFloat = 20
    /// Key terms, the same 20 pt Deep Study's `KeyTermsList` draws them at.
    public static let keyTermArabicSize: CGFloat = 20
    /// The "why it is related" line under a cross reference.
    public static let relatedWhySize: CGFloat = 13
}
