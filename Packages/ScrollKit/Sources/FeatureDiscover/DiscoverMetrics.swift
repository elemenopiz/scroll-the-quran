import CoreText
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

    /// The quote's slot is no longer a fixed four lines: the owner asked on 2026-09-13 for
    /// "the entirety of the verse" to fit and for "the meaning/did you know [to] be cut
    /// off" instead, so the quote takes the lines it actually needs and
    /// `DiscoverCardLayout.body(for:meaning:didYouKnow:width:)` divides what is left.
    /// This is what the four-line slot *used* to be, and it is still the arithmetic the
    /// body budget is built from, so the card height is unchanged (Phase 4m).
    static let quoteLines = 4
    static let meaningLines = 4
    static let didYouKnowLines = 3

    /// The point sizes the quote may be laid out at, largest first. 16 pt is
    /// `VerseText.Size.discover`; 14 pt is the floor — below it the italic serif stops
    /// reading as the card's voice, and it is the same spirit as rule 5's 13 pt Arabic
    /// floor.
    static let quoteSizeLadder: [CGFloat] = [VerseText.Size.discover.english, 15, 14]

    /// MEANING is never shown in less than this. Under it the section is noise, so the
    /// card drops it outright instead (Phase 4m).
    static let minimumMeaningLines = 2

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

    /// The block MEANING occupies with `lines` of body under its label, gap included.
    static func meaningBlock(lines: Int) -> CGFloat {
        DiscoverMetrics.quoteToMeaning
            + capsLabelHeight
            + DiscoverMetrics.labelToBody
            + slot(lines: lines, size: DiscoverMetrics.bodySize)
    }

    /// The block DID YOU KNOW occupies, gap included.
    static var didYouKnowBlock: CGFloat {
        DiscoverMetrics.bodyToDidYouKnow + didYouKnowBox
    }

    /// **The body budget.** Quote + MEANING + DID YOU KNOW share exactly this much height
    /// on every card, whatever the passage's length — which is why the card is a constant
    /// and the pager lands identically (Phase 4i), and why Phase 4m could re-divide the
    /// three blocks without moving the chip, the title, "Deep study ›" or the action row.
    ///
    /// Its value is Phase 4i's own slots totalled: a four-line quote, a four-line MEANING
    /// and the three-line DID YOU KNOW box. Nothing about the number changed, only who
    /// gets which part of it.
    static var bodyBudget: CGFloat {
        quoteSlot + meaningBlock(lines: DiscoverMetrics.meaningLines) + didYouKnowBlock
    }

    /// Every card is this tall. The one number this whole task is about.
    static var cardHeight: CGFloat {
        2 * DiscoverMetrics.cardPadding
            + Metrics.chipHeight
            + DiscoverMetrics.chipToTitle + titleSlot
            + DiscoverMetrics.titleToQuote + bodyBudget
            + DiscoverMetrics.didYouKnowToChips + Metrics.crossRefChipHeight
            + DiscoverMetrics.chipsToDeepStudy + Metrics.hitTarget
            + DiscoverMetrics.deepStudyToActions + Metrics.hitTarget
    }

    /// The width a slot's text is laid out in: the screen less the page margin on each
    /// side and the card's own padding on each side.
    static func contentWidth(screenWidth: CGFloat) -> CGFloat {
        screenWidth - 2 * DiscoverMetrics.cardInset - 2 * DiscoverMetrics.cardPadding
    }

    // MARK: - The body plan

    /// How one card divides `bodyBudget` between the quote, MEANING and DID YOU KNOW.
    ///
    /// The quote comes first and whole (owner, 2026-09-13: "ideally the entirety of the
    /// verse fits on the card. the meaning/did you know can be cut off"); the other two
    /// take what is left, MEANING never under `minimumMeaningLines` and DID YOU KNOW only
    /// if its box still fits. Whatever the plan, the three blocks are stacked from the top
    /// of a `bodyBudget`-tall container, so the card totals `cardHeight` either way.
    struct BodyPlan: Equatable, Sendable {
        /// The point size the quote is laid out at: 16, 15 or 14 (`quoteSizeLadder`).
        var quoteSize: CGFloat
        /// How many lines the quote gets — its *actual* line count, not a cap, except on
        /// the overflow cards where `quoteIsTruncated` is true.
        var quoteLines: Int
        /// The MEANING slot, 0 when the section is dropped from the card.
        var meaningLines: Int
        /// Whether the DID YOU KNOW box is on the card. It always is in Deep Study.
        var showsDidYouKnow: Bool
        /// True only when even a 14 pt quote alone will not fit the body — the single case
        /// the brief allows a "…" on a Discover quote.
        var quoteIsTruncated: Bool

        /// The height the three blocks draw, which is never more than `bodyBudget`.
        var bodyHeight: CGFloat {
            var height = slot(lines: quoteLines, size: quoteSize)
            if meaningLines > 0 {
                height += meaningBlock(lines: meaningLines)
            }
            if showsDidYouKnow {
                height += didYouKnowBlock
            }
            return height
        }
    }

    /// Divides `bodyBudget` for one unit.
    ///
    /// The ladder, in the order the brief sets it out:
    /// 1. at 16 pt, quote whole, MEANING 4 lines, DID YOU KNOW shown;
    /// 2. shorten MEANING toward `minimumMeaningLines`;
    /// 3. drop DID YOU KNOW (the section still lives in Deep Study) and try MEANING again;
    /// 4. step the quote to 15 pt, then 14 pt, repeating 1–3 at each size;
    /// 5. drop MEANING and let the quote take the whole body, at the largest size it fits at;
    /// 6. and only then truncate the quote with a tail "…".
    ///
    /// - Parameter passageText: the quote exactly as it will be drawn, measured flat — see
    ///   `PassagePresentation.layoutQuote`.
    static func body(
        for passageText: String,
        meaning: String,
        didYouKnow: String,
        width: CGFloat
    ) -> BodyPlan {
        let budget = bodyBudget
        let wantsMeaning = !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let wantsDidYouKnow = !didYouKnow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        for size in DiscoverMetrics.quoteSizeLadder {
            let lines = quoteLineCount(passageText, size: size, width: width)
            let quote = slot(lines: lines, size: size)

            for showsDidYouKnow in (wantsDidYouKnow ? [true, false] : [false]) {
                let extra = showsDidYouKnow ? didYouKnowBlock : 0
                guard wantsMeaning else {
                    if quote + extra <= budget {
                        return BodyPlan(
                            quoteSize: size,
                            quoteLines: lines,
                            meaningLines: 0,
                            showsDidYouKnow: showsDidYouKnow,
                            quoteIsTruncated: false
                        )
                    }
                    continue
                }
                let slots = stride(
                    from: DiscoverMetrics.meaningLines,
                    through: DiscoverMetrics.minimumMeaningLines,
                    by: -1
                )
                for meaningLines in slots where quote + meaningBlock(lines: meaningLines) + extra <= budget {
                    return BodyPlan(
                        quoteSize: size,
                        quoteLines: lines,
                        meaningLines: meaningLines,
                        showsDidYouKnow: showsDidYouKnow,
                        quoteIsTruncated: false
                    )
                }
            }
        }

        // Nothing on the ladder held a two-line MEANING: MEANING goes too and the quote
        // takes the whole body — at the largest size it fits at, so a card that has given
        // up both prose sections at least reads at the size it was designed for.
        for size in DiscoverMetrics.quoteSizeLadder {
            let lines = quoteLineCount(passageText, size: size, width: width)
            if slot(lines: lines, size: size) <= budget {
                return BodyPlan(
                    quoteSize: size,
                    quoteLines: lines,
                    meaningLines: 0,
                    showsDidYouKnow: false,
                    quoteIsTruncated: false
                )
            }
        }

        // The passage does not fit the card at any size on the ladder. This is the only
        // place a Discover quote is allowed a tail "…"; `OverflowLedger` in the tests names
        // the units it happens to, so a content change that adds one fails the gate.
        let size = DiscoverMetrics.quoteSizeLadder.last ?? VerseText.Size.discover.english
        let lines = quoteLineCount(passageText, size: size, width: width)
        let fits = Int(budget / lineHeight(size))
        return BodyPlan(
            quoteSize: size,
            quoteLines: min(lines, fits),
            meaningLines: 0,
            showsDidYouKnow: false,
            quoteIsTruncated: lines > fits
        )
    }

    // MARK: - Measurement

    /// How many lines `text` takes in the card's italic serif at `size` across `width`.
    ///
    /// The card draws the passage as an `AttributedString` whose ayah boundaries carry a
    /// small muted numeral between two thin spaces (`VerseText`); measuring the flat
    /// `layoutQuote` — the same words with " n " at each boundary, all in the quote's own
    /// face — is a few points *wider* per boundary than what is drawn, so the count is
    /// never short. Erring long costs a line of MEANING; erring short would put a "…" on
    /// the verse, which is the one thing this task exists to remove.
    static func quoteLineCount(_ text: String, size: CGFloat, width: CGFloat) -> Int {
        lineCount(text, fontName: FontFamily.serifItalic, size: size, width: width)
    }

    static func lineCount(_ text: String, fontName: String, size: CGFloat, width: CGFloat) -> Int {
        guard !text.isEmpty, width > 0 else { return 0 }
        let key = MeasurementCache.Key(text: text, fontName: fontName, size: size, width: width)
        if let cached = measurements.value(for: key) { return cached }

        _ = DesignSystem.registerFonts()
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        let lines = CFArrayGetCount(CTFrameGetLines(frame))
        measurements.store(lines, for: key)
        return lines
    }

    /// Laying a 200-word passage out three times is cheap, but the card's `body` is
    /// re-evaluated on every save/read toggle and on every frame of a page turn, so the
    /// answers are kept.
    private static let measurements = MeasurementCache()
}

/// A tiny thread-safe memo for `DiscoverCardLayout.lineCount`.
final class MeasurementCache: @unchecked Sendable {
    struct Key: Hashable {
        let text: String
        let fontName: String
        let size: CGFloat
        let width: CGFloat
    }

    private let lock = NSLock()
    private var storage: [Key: Int] = [:]

    func value(for key: Key) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func store(_ value: Int, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        // The feed is 326 units x 3 sizes x 2 widths; the cap is a guard against a
        // Dynamic Type sweep, not a working limit.
        if storage.count > 4000 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = value
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

/// The REFLECTION card's geometry (Phase 4o), measured off the owner's screenshot of the
/// original at 402x874 pt.
///
/// The card is the Discover card's frame exactly — same fill, same `Radius.cardLarge`, same
/// `DiscoverCardLayout.cardHeight`, same place on the page — with a different inside: a
/// quote mark in a disc, the REFLECTION label, the saying and who said it, the four of them
/// centred as one group on the card's own centre line. There is no action row: the original
/// shows no bookmark, comment, share or check on a reflection, and there is nothing to save,
/// note or mark read.
enum ReflectionMetrics {
    /// The disc behind the quote glyph: 73 pt across, `chipBackground` — one step lighter
    /// than the card, the same relationship the theme chip has to it.
    static let markDiameter: CGFloat = 73
    /// The open-quote glyph inside it, in the display serif.
    static let markGlyphSize: CGFloat = 44

    /// disc → REFLECTION, label → quote, quote → attribution. Measured as ink-to-ink gaps
    /// on the screenshot; the label and the attribution carry their own line-box leading
    /// inside the slots below, which is why these are larger than the card's other rhythm.
    static let markToLabel: CGFloat = 42
    static let labelToQuote: CGFloat = 32
    static let quoteToAttribution: CGFloat = 28

    /// The quote is inset this far from the card's own edge — wider than the study card's
    /// text, because a centred pull-quote needs the measure short.
    static let quoteInset: CGFloat = 40

    /// The sizes the saying may be set at, largest first. It steps down before it is
    /// allowed to wrap past `quoteLines`; 22 pt is the floor, and below it the display
    /// serif stops reading as a pull quote.
    static let quoteSizeLadder: [CGFloat] = [26, 24, 22]
    /// The line count the ladder tries to stay inside. It is a preference, not a cap: a
    /// reflection is **never** truncated, so a saying that still needs a seventh line at
    /// 22 pt gets it (there is room for eleven inside the card).
    static let quoteLines = 6

    /// "— Rumi". SF Pro semibold, one line, shrunk for the long ones the same way the
    /// study card's title is (`referenceMinimumScale`): the longest attribution we ship,
    /// "The Prophet Muhammad (peace be upon him)", is about 8 % wider than the card.
    static let attributionSize: CGFloat = 17
    static let attributionMinimumScale: CGFloat = 0.75
}

/// The REFLECTION card's arithmetic, in points, at the default content size.
///
/// Same contract as `DiscoverCardLayout`: kept out of the views so a test can total it
/// without a render pass. `ReflectionCardLayoutTests` runs every reflection that ships
/// through it and asserts the group still fits the card.
enum ReflectionCardLayout {
    /// The SF Pro line box at `ReflectionMetrics.attributionSize`
    /// (`UIFont.systemFont(ofSize: 17).lineHeight`), the same kind of measured constant as
    /// `DiscoverCardLayout.capsLabelHeight`.
    static let attributionHeight: CGFloat = 20.3

    /// The height inside the card, padding removed. The group is centred in it, so the
    /// card totals `DiscoverCardLayout.cardHeight` exactly like a study card.
    static var contentHeight: CGFloat {
        DiscoverCardLayout.cardHeight - 2 * DiscoverMetrics.cardPadding
    }

    /// The width the saying is laid out in: the screen less the page margin on each side
    /// and `quoteInset` on each side.
    static func quoteWidth(screenWidth: CGFloat) -> CGFloat {
        screenWidth - 2 * DiscoverMetrics.cardInset - 2 * ReflectionMetrics.quoteInset
    }

    /// The same width, from the study card's content width — which is what the page
    /// already measured off its own geometry.
    static func quoteWidth(cardContentWidth: CGFloat) -> CGFloat {
        cardContentWidth - 2 * (ReflectionMetrics.quoteInset - DiscoverMetrics.cardPadding)
    }

    /// The width the attribution is laid out in: the card's own content width — it is not
    /// pulled in to the quote's measure.
    static func attributionWidth(screenWidth: CGFloat) -> CGFloat {
        DiscoverCardLayout.contentWidth(screenWidth: screenWidth)
    }

    /// How one saying is set: a point size off the ladder and the line count it takes there.
    struct QuotePlan: Equatable, Sendable {
        var size: CGFloat
        var lines: Int

        var height: CGFloat {
            DiscoverCardLayout.slot(lines: lines, size: size)
        }
    }

    /// Steps down the ladder until the saying fits `ReflectionMetrics.quoteLines`, and
    /// settles for the floor's own line count when none of them does. Nothing here can
    /// return a truncating plan: the count is always the saying's real one.
    static func quote(for text: String, width: CGFloat) -> QuotePlan {
        for size in ReflectionMetrics.quoteSizeLadder {
            let lines = lineCount(text, size: size, width: width)
            if lines <= ReflectionMetrics.quoteLines {
                return QuotePlan(size: size, lines: lines)
            }
        }
        let size = ReflectionMetrics.quoteSizeLadder.last ?? 22
        return QuotePlan(size: size, lines: lineCount(text, size: size, width: width))
    }

    static func lineCount(_ text: String, size: CGFloat, width: CGFloat) -> Int {
        DiscoverCardLayout.lineCount(text, fontName: FontFamily.serif, size: size, width: width)
    }

    /// The four blocks plus the three gaps between them — what the card centres.
    static func groupHeight(_ plan: QuotePlan) -> CGFloat {
        ReflectionMetrics.markDiameter
            + ReflectionMetrics.markToLabel + DiscoverCardLayout.capsLabelHeight
            + ReflectionMetrics.labelToQuote + plan.height
            + ReflectionMetrics.quoteToAttribution + attributionHeight
    }

    /// How far down the open-quote glyph has to move to sit on the disc's centre.
    ///
    /// SwiftUI centres a `Text`'s *line box*, and `“` is all ink in the upper half of the
    /// em — centring the box leaves the glyph visibly high. Measured off the registered
    /// font rather than nudged by eye: the ink box's middle is put on the disc's middle.
    static func markGlyphOffset(size: CGFloat = ReflectionMetrics.markGlyphSize) -> CGFloat {
        _ = DesignSystem.registerFonts()
        let font = CTFontCreateWithName(FontFamily.serif as CFString, size, nil)
        var character: UniChar = 0x201C
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) else { return 0 }
        let ink = withUnsafePointer(to: glyph) { pointer in
            CTFontGetBoundingRectsForGlyphs(font, .default, pointer, nil, 1)
        }
        let ascent = CTFontGetAscent(font)
        let lineHeight = ascent + CTFontGetDescent(font) + CTFontGetLeading(font)
        // Text space is y-up from the baseline; the view's is y-down from the box's top.
        // With the box centred, the baseline sits at `ascent - lineHeight / 2` below
        // centre, and the ink's middle `ink.midY` above that baseline.
        return lineHeight / 2 - ascent + ink.midY
    }
}
