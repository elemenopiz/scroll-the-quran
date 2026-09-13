import CoreText
import DesignSystem
@testable import FeatureDiscover
import Foundation
import QuranData
@testable import StudyContent
import Testing

/// The fixed-slot guarantee, checked against the whole corpus with the real fonts.
///
/// The owner's complaint that started Phase 4i was that "when you scroll the verses on the
/// original app all of them have the same placement and look polished; on ours it's not the
/// case". The fix is that every block of the card sits in a slot with a matching
/// `lineLimit`, so the card's height is a constant rather than a function of how long the
/// unit's prose happens to be. This lays all 326 Discover units out — the bundled Itani
/// text through `PassagePresentation`, the authored `meaning` and `didYouKnow` — in the real
/// registered Source Serif at the real content width, and asserts that constant.
@Suite("Discover card layout", .serialized)
struct DiscoverCardLayoutTests {
    // MARK: - Corpus

    /// Repo root, walked up from this file: Tests/FeatureDiscoverTests -> Tests -> ScrollKit
    /// -> Packages -> root.
    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        return url
    }()

    private static let contentRoot = repoRoot.appendingPathComponent("Content", isDirectory: true)

    private static func corpus() throws -> (items: [DiscoverItem], studies: StudyStore, translations: TranslationStore) {
        let loader = DirectoryContentLoader(root: contentRoot)
        let file = try JSONDecoder().decode(DiscoverFile.self, from: loader.data(at: "discover.json"))
        let studies = try StudyStore(loader: loader)
        let translations = try TranslationStore(locator: ContentLocator(roots: [contentRoot]))
        return (file.items, studies, translations)
    }

    // MARK: - Measurement

    /// The width a slot's text is laid out in on the 402x874 pt simulator canvas the
    /// captures are taken on (iPhone 17 Pro). The 393x852 pt reference canvas is checked
    /// beside it: a narrower card is the harder case, and no unit may overflow on it that
    /// does not overflow here.
    private static let contentWidth = DiscoverCardLayout.contentWidth(screenWidth: 402)
    private static let referenceContentWidth = DiscoverCardLayout.contentWidth(screenWidth: 393)

    /// The only units whose quote cannot fit the card whole, even at 14 pt with MEANING and
    /// DID YOU KNOW dropped. The brief asks for this list by name so the owner can decide
    /// whether to narrow them in `discover.json`; it is an assertion, not a note, so a
    /// content change that adds a truncated card fails the gate.
    private static let expectedOverflow: Set<String> = OverflowLedger.keys

    private static func font(_ name: String, _ size: CGFloat) -> CTFont {
        DesignSystem.registerFonts()
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    /// How many lines `text` takes in `font` at `width`, unbounded.
    private static func lineCount(_ text: String, font: CTFont, width: CGFloat) -> Int {
        guard !text.isEmpty else { return 0 }
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        return CFArrayGetCount(CTFrameGetLines(frame))
    }

    /// One unit's plan plus what it was planned from.
    private struct Planned {
        let key: String
        let plan: DiscoverCardLayout.BodyPlan
        /// The lines the quote needs at the plan's own size, unbounded.
        let naturalQuoteLines: Int
        let words: Int
    }

    private static func plans(width: CGFloat) throws -> [Planned] {
        let (items, studies, translations) = try corpus()
        var out: [Planned] = []
        for item in items {
            guard let study = studies.study(forKey: item.key) else { continue }
            let presentation = try #require(
                PassagePresentation.make(forKey: item.key, translations: translations)
            )
            let plan = DiscoverCardLayout.body(
                for: presentation.layoutQuote,
                meaning: study.meaning,
                didYouKnow: study.didYouKnow,
                width: width
            )
            out.append(
                Planned(
                    key: item.key,
                    plan: plan,
                    naturalQuoteLines: DiscoverCardLayout.quoteLineCount(
                        presentation.layoutQuote,
                        size: plan.quoteSize,
                        width: width
                    ),
                    words: presentation.english.split(separator: " ").count
                )
            )
        }
        return out
    }

    // MARK: - Tests

    @Test("The line-box ratio the slots are built on is the registered font's own")
    func lineRatioMatchesTheFont() {
        for name in [FontFamily.serif, FontFamily.serifItalic] {
            let font = Self.font(name, 100)
            let box = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
            #expect(
                abs(box / 100 - DiscoverCardLayout.serifLineRatio) < 0.005,
                "\(name) line box is \(box / 100) em, not \(DiscoverCardLayout.serifLineRatio)"
            )
        }
    }

    /// Phase 4m re-divides the body; it does not resize the card. The budget is still
    /// Phase 4i's own three slots totalled, and the card is still the number the pager and
    /// `UITests/Specs/discover-dark.json` were recorded against.
    @Test("The body budget and the card height are exactly what the fixed slots totalled")
    func theCardIsStillTheSameHeight() {
        let phase4iSlots = DiscoverCardLayout.quoteSlot
            + DiscoverMetrics.quoteToMeaning + DiscoverCardLayout.capsLabelHeight
            + DiscoverMetrics.labelToBody + DiscoverCardLayout.meaningSlot
            + DiscoverMetrics.bodyToDidYouKnow + DiscoverCardLayout.didYouKnowBox
        #expect(abs(DiscoverCardLayout.bodyBudget - phase4iSlots) < 0.001)
        #expect(abs(DiscoverCardLayout.cardHeight - 607.365) < 0.01, "the card is \(DiscoverCardLayout.cardHeight) pt")
    }

    @Test("All 326 Discover units build a card of exactly the same height")
    func everyCardIsTheSameHeight() throws {
        let planned = try Self.plans(width: Self.contentWidth)
        #expect(planned.count == 326, "only \(planned.count) of the 326 units resolved against the bundled content")

        var heights: Set<Int> = []
        for unit in planned {
            #expect(
                unit.plan.bodyHeight <= DiscoverCardLayout.bodyBudget + 0.001,
                "\(unit.key): the body plans \(unit.plan.bodyHeight) pt into a \(DiscoverCardLayout.bodyBudget) pt budget"
            )
            // The three blocks stack from the top of a budget-tall container, so whatever
            // the plan the card totals the same number.
            heights.insert(Int((DiscoverCardLayout.cardHeight * 100).rounded()))
        }
        #expect(heights.count == 1, "the 326 units produce \(heights.count) different card heights")
    }

    /// The task in one assertion: no Discover quote is cut short, except the units the
    /// ledger names.
    @Test("Every quote fits the card whole except the ledgered overflows")
    func everyQuoteFitsWhole() throws {
        for width in [Self.contentWidth, Self.referenceContentWidth] {
            let planned = try Self.plans(width: width)
            var truncated: Set<String> = []
            for unit in planned where unit.plan.quoteIsTruncated || unit.plan.quoteLines < unit.naturalQuoteLines {
                truncated.insert(unit.key)
            }
            #expect(
                truncated == Self.expectedOverflow,
                "at \(width) pt the truncated quotes are \(truncated.sorted()), the ledger says \(Self.expectedOverflow.sorted())"
            )
        }
    }

    @Test("MEANING is never shown in under two lines")
    func meaningIsNeverAStub() throws {
        for unit in try Self.plans(width: Self.contentWidth) {
            #expect(
                unit.plan.meaningLines == 0 || unit.plan.meaningLines >= DiscoverMetrics.minimumMeaningLines,
                "\(unit.key): MEANING is planned at \(unit.plan.meaningLines) lines"
            )
            #expect(
                unit.plan.meaningLines <= DiscoverMetrics.meaningLines,
                "\(unit.key): MEANING is planned at \(unit.plan.meaningLines) lines, more than the slot"
            )
            #expect(
                DiscoverMetrics.quoteSizeLadder.contains(unit.plan.quoteSize),
                "\(unit.key): the quote is planned at \(unit.plan.quoteSize) pt, off the ladder"
            )
            #expect(unit.plan.quoteSize >= 14, "\(unit.key): the quote is under the 14 pt floor")
        }
    }

    /// Not an assertion about the design: the distribution the brief asks to be reported,
    /// printed from the same arithmetic the card draws from.
    @Test("The plan distribution over the 326 units is on the record")
    func planDistributionIsReported() throws {
        let planned = try Self.plans(width: Self.contentWidth)
        var bySize: [CGFloat: Int] = [:]
        var noDidYouKnow: [String] = []
        var noMeaning: [String] = []
        var meaningLines: [Int: Int] = [:]
        for unit in planned {
            bySize[unit.plan.quoteSize, default: 0] += 1
            meaningLines[unit.plan.meaningLines, default: 0] += 1
            if !unit.plan.showsDidYouKnow { noDidYouKnow.append(unit.key) }
            if unit.plan.meaningLines == 0 { noMeaning.append(unit.key) }
        }
        let sizes = bySize.keys.sorted(by: >).map { "\(Int($0)) pt: \(bySize[$0] ?? 0)" }.joined(separator: ", ")
        let meanings = meaningLines.keys.sorted(by: >).map { "\($0) lines: \(meaningLines[$0] ?? 0)" }.joined(separator: ", ")
        print("PLAN quote size — \(sizes)")
        print("PLAN meaning — \(meanings)")
        print("PLAN drops DID YOU KNOW — \(noDidYouKnow.count): \(noDidYouKnow.sorted().joined(separator: " "))")
        print("PLAN drops MEANING — \(noMeaning.count): \(noMeaning.sorted().joined(separator: " "))")
        print("PLAN overflow — \(planned.filter(\.plan.quoteIsTruncated).map(\.key).sorted().joined(separator: " "))")
        let longest = planned.max { $0.words < $1.words }
        let lines = longest?.plan.quoteLines ?? 0
        print("PLAN longest unit — \(longest?.key ?? "?") at \(longest?.words ?? 0) words, \(lines) lines")
        #expect(bySize.values.reduce(0, +) == 326)
    }

    @Test("The card lands in the reference's band on the 393x852 canvas")
    func cardSitsWhereTheReferenceDoes() {
        // Reference/discover-dark.png: card fill y = 360..2141 px of 2556 = 14.08 %..83.8 %.
        let top = DiscoverMetrics.cardTopFraction * 852
        let bottom = top + DiscoverCardLayout.cardHeight
        #expect(abs(top - 120) < 1, "card top is \(top) pt, the reference's is 120")
        #expect(bottom / 852 > 0.83, "card bottom is \(bottom / 852) of the screen")
        #expect(bottom / 852 < 0.86, "card bottom is \(bottom / 852) of the screen")
    }

    @Test("Every reference line fits one line of the 32 pt title at the 0.7 floor")
    func titlesFitOneLine() throws {
        let (items, _, translations) = try Self.corpus()
        let title = Self.font(FontFamily.serif, DiscoverMetrics.referenceSize)
        var widest = (key: "", width: CGFloat(0))

        for item in items {
            guard let presentation = PassagePresentation.make(forKey: item.key, translations: translations) else {
                continue
            }
            let attributed = NSAttributedString(
                string: presentation.reference,
                attributes: [.font: title]
            )
            let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
            if width > widest.width {
                widest = (presentation.reference, width)
            }
        }

        let available = Self.contentWidth / DiscoverMetrics.referenceMinimumScale
        #expect(
            widest.width <= available,
            "'\(widest.key)' needs \(widest.width) pt at 32 pt, more than a 0.7 scale of \(available) pt gives"
        )
    }

    @Test("--discover-index parses the way the capture loop uses it")
    func discoverIndexParses() {
        #expect(DiscoverLaunchIndex.parse(["--screenshot", "discover", "--discover-index", "7"]) == 7)
        #expect(DiscoverLaunchIndex.parse(["--discover-index", "0"]) == 0)
        #expect(DiscoverLaunchIndex.parse(["--discover-index"]) == nil)
        #expect(DiscoverLaunchIndex.parse(["--screenshot", "discover"]) == nil)
    }
}

/// The Discover units whose quote cannot fit the card whole.
///
/// A unit lands here only after the whole ladder has been spent: 14 pt, MEANING dropped,
/// DID YOU KNOW dropped, the quote alone across the entire body budget. These are the only
/// cards that still draw a tail "…" (the brief's escape hatch), and the list is the one the
/// owner asked for so they can decide whether to narrow the passage in `discover.json`.
enum OverflowLedger {
    static let keys: Set<String> = [
        // 215 words over seven ayat — Luqman's counsel to his son. 18 lines at 14 pt
        // against the 17 the body holds.
        "31:13-19",
        // 178 words over ten ayat — the opening of Al-Kahf.
        "18:1-10",
    ]
}
