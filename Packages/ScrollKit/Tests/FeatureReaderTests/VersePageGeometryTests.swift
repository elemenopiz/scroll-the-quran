import CoreGraphics
@testable import FeatureReader
import Testing

/// Where the verse block's centre lands once the logo card is on every page (Phase 4n).
///
/// The collision this guards against is arithmetic and was visible on the simulator before it
/// was fixed: 2:255 in Pickthall is a ~500 pt block, and centring it on the measured 57.7 %
/// of a 710 pt page put its first Arabic line at y 160 — 23 pt *inside* the card, which ends
/// at 183. Nothing about that is a matter of taste, so it is asserted here rather than left
/// to a capture.
@Suite("Verse page geometry")
struct VersePageGeometryTests {
    /// `reader-dark`'s page: 393x852 pt screen, 59 pt top inset, 83 pt bottom.
    static let pageHeight: CGFloat = 710
    /// Toolbar inset + toolbar + 28 pt, then the 112 pt card.
    static let cardBottom = VersePageView.logoCardTop + 112

    static var ideal: CGFloat {
        pageHeight * 0.577
    }

    @Test("a page with no logo card is centred on the measured 57.7 %, whatever its height")
    func noCardMeansNoClamp() {
        for height in [0, 120, 500, 900] as [CGFloat] {
            let y = VersePageView.verseCentreY(
                blockHeight: height, pageHeight: Self.pageHeight, showsLogoCard: false
            )
            #expect(y == Self.ideal)
        }
    }

    /// The reference capture. The Bismillah block is ~119 pt tall and clears the card by a
    /// long way, so the clamp is inert and `reader-dark` cannot move.
    @Test("the opening page keeps the measured centre exactly")
    func openingPageIsUnchanged() {
        let y = VersePageView.verseCentreY(
            blockHeight: 119, pageHeight: Self.pageHeight, showsLogoCard: true
        )
        #expect(y == Self.ideal)
        #expect(y - 119 / 2 > Self.cardBottom, "the block already clears the card unaided")
    }

    /// Before the fix this was the bug: the block's top edge landed inside the card.
    @Test("a long ayah is pushed down until it clears the card")
    func longAyahClearsTheCard() {
        let height: CGFloat = 500
        #expect(Self.ideal - height / 2 < Self.cardBottom, "the fixture must collide unclamped")

        let y = VersePageView.verseCentreY(
            blockHeight: height, pageHeight: Self.pageHeight, showsLogoCard: true
        )
        #expect(y > Self.ideal, "a colliding block has to move down")
        #expect(y - height / 2 >= Self.cardBottom, "the block still overlaps the card")
    }

    /// The other side of the clamp: a block that fits has to stay on the page.
    @Test("a block is never pushed past the bottom margin when there is room for both")
    func staysOnThePage() {
        for height in stride(from: CGFloat(120), through: 420, by: 60) {
            let y = VersePageView.verseCentreY(
                blockHeight: height, pageHeight: Self.pageHeight, showsLogoCard: true
            )
            #expect(y - height / 2 >= Self.cardBottom, "\(height) pt block overlaps the card")
            #expect(
                y + height / 2 <= Self.pageHeight,
                "\(height) pt block runs off the bottom of the page"
            )
        }
    }

    /// A block too tall to satisfy both clamps clears the card and overflows the bottom —
    /// a readable opening with a long tail, not a first line hidden under the mark.
    @Test("clearing the card wins when a block cannot satisfy both clamps")
    func cardClampWins() {
        let height = Self.pageHeight // taller than the space under the card
        let y = VersePageView.verseCentreY(
            blockHeight: height, pageHeight: Self.pageHeight, showsLogoCard: true
        )
        #expect(y - height / 2 >= Self.cardBottom)
    }

    /// The clamp only ever pushes down. A short block must not float up into the toolbar.
    @Test("the clamp never raises a block above the measured centre")
    func clampOnlyPushesDown() {
        for height in stride(from: CGFloat(0), through: 900, by: 50) {
            let y = VersePageView.verseCentreY(
                blockHeight: height, pageHeight: Self.pageHeight, showsLogoCard: true
            )
            #expect(y >= Self.ideal, "a \(height) pt block was raised to \(y)")
        }
    }
}
