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

    /// The width a slot's text is laid out in on the 393x852 pt reference canvas.
    private static let contentWidth = DiscoverCardLayout.contentWidth(screenWidth: 393)

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

    /// The height a slot actually draws: `lineLimit` caps the text, `minHeight` floors it,
    /// so the answer is always the slot — which is the property under test.
    private static func slotHeight(text: String, font: CTFont, limit: Int, size: CGFloat) -> CGFloat {
        let drawn = min(lineCount(text, font: font, width: contentWidth), limit)
        return max(DiscoverCardLayout.slot(lines: drawn, size: size), DiscoverCardLayout.slot(lines: limit, size: size))
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

    @Test("All 326 Discover units build a card of exactly the same height")
    func everyCardIsTheSameHeight() throws {
        let (items, studies, translations) = try Self.corpus()
        #expect(items.count == 326, "the bundled feed is \(items.count) units, not 326")

        let italic = Self.font(FontFamily.serifItalic, VerseText.Size.discover.english)
        let serif = Self.font(FontFamily.serif, DiscoverMetrics.bodySize)

        var heights: Set<Int> = []
        var measured = 0
        var quoteOverflows = 0

        for item in items {
            guard let study = studies.study(forKey: item.key) else { continue }
            let presentation = try #require(
                PassagePresentation.make(forKey: item.key, translations: translations)
            )
            measured += 1

            let quoted = presentation.quoted
            if Self.lineCount(quoted, font: italic, width: Self.contentWidth) > DiscoverMetrics.quoteLines {
                quoteOverflows += 1
            }

            let quote = Self.slotHeight(
                text: quoted,
                font: italic,
                limit: DiscoverMetrics.quoteLines,
                size: VerseText.Size.discover.english
            )
            let meaning = Self.slotHeight(
                text: study.meaning,
                font: serif,
                limit: DiscoverMetrics.meaningLines,
                size: DiscoverMetrics.bodySize
            )
            let didYouKnow = Self.slotHeight(
                text: study.didYouKnow,
                font: serif,
                limit: DiscoverMetrics.didYouKnowLines,
                size: DiscoverMetrics.bodySize
            )

            #expect(quote == DiscoverCardLayout.quoteSlot, "\(item.key): quote slot is \(quote)")
            #expect(meaning == DiscoverCardLayout.meaningSlot, "\(item.key): meaning slot is \(meaning)")
            #expect(
                didYouKnow == DiscoverCardLayout.didYouKnowSlot,
                "\(item.key): did-you-know slot is \(didYouKnow)"
            )

            // The card is the slots plus the gaps; nothing else varies with the unit.
            let height = DiscoverCardLayout.cardHeight
                - DiscoverCardLayout.quoteSlot - DiscoverCardLayout.meaningSlot
                - DiscoverCardLayout.didYouKnowSlot
                + quote + meaning + didYouKnow
            heights.insert(Int((height * 100).rounded()))
        }

        #expect(measured == 326, "only \(measured) of the 326 units resolved against the bundled content")
        #expect(heights.count == 1, "the 326 units produce \(heights.count) different card heights")
        #expect(heights.first == Int((DiscoverCardLayout.cardHeight * 100).rounded()))
        // Not an assertion about the design, a note in the record: the slot is a cap that
        // most units reach, which is exactly why it has to be reserved rather than grown into.
        #expect(quoteOverflows > 0, "no unit's quote overflows four lines — the cap is untested")
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
