import CoreGraphics
@testable import FeaturePaywall
import Testing

/// Phase 4e: the brand mark has to sit clear of the Dynamic Island on the paywall, and the
/// gift card's "OFF" pill has to stop covering the "33%" it belongs to.
///
/// `PaywallTrialView` draws the mark inside a `ReferenceCanvas`, which scales the 393x852
/// composition to fill the screen, so every assertion here goes through the same mapping the
/// view uses rather than eyeballing a constant.
@Suite("Brand mark placement")
struct BrandPlacementTests {
    /// iPhone 17 Pro, the device `Tools/snapshot/capture.sh` shoots on: 402x874 pt with a
    /// 62 pt top safe-area inset and the island's bottom edge measured at 51.7 pt.
    static let screen = CGSize(width: 402, height: 874)
    static let safeAreaTop: CGFloat = 62
    static let islandBottom: CGFloat = 51.7
    static let requiredAir: CGFloat = 10

    @Test("the canvas mapping round-trips")
    func canvasMappingRoundTrips() {
        for y in stride(from: CGFloat(0), through: 852, by: 71) {
            let screenY = PaywallMetrics.screenY(referenceY: y, screen: Self.screen)
            let back = PaywallMetrics.referenceY(screenY: screenY, screen: Self.screen)
            #expect(abs(back - y) < 0.001)
        }
    }

    @Test("the paywall mark clears the Dynamic Island by at least 10 pt")
    func markClearsTheDynamicIsland() {
        let top = PaywallMetrics.logoTop(safeAreaTop: Self.safeAreaTop, screen: Self.screen)
        let screenTop = PaywallMetrics.screenY(referenceY: top, screen: Self.screen)
        #expect(screenTop >= Self.islandBottom + Self.requiredAir)
    }

    /// The notch devices report a smaller inset, and a device with neither reports none at
    /// all; the mark must stay on the screen and never ride back up under an island.
    @Test(
        "every plausible top inset still leaves the mark below the status bar",
        arguments: [CGFloat(0), 20, 47, 48, 54, 59, 62, 72]
    )
    func markStaysBelowTheStatusBar(inset: CGFloat) {
        let top = PaywallMetrics.logoTop(safeAreaTop: inset, screen: Self.screen)
        #expect(top >= PaywallMetrics.logoTopFloor)
        let screenTop = PaywallMetrics.screenY(referenceY: top, screen: Self.screen)
        #expect(screenTop >= inset)
        #expect(screenTop + PaywallMetrics.logoSize.height < PaywallMetrics.headlineTop)
    }

    @Test("the mark is bigger than the reference's and still clears the headline")
    func markIsBiggerAndStillClearsTheHeadline() {
        #expect(PaywallMetrics.logoSize.height >= 72)
        #expect(PaywallMetrics.logoSize.width == PaywallMetrics.logoSize.height)
        let top = PaywallMetrics.logoTop(safeAreaTop: Self.safeAreaTop, screen: Self.screen)
        #expect(top + PaywallMetrics.logoSize.height <= PaywallMetrics.headlineTop)
    }

    @Test("the OFF pill tucks under the 33% instead of covering it")
    func offPillClearsThePercentDigits() {
        let ink = PaywallMetrics.percentInk
        // The white outline is drawn centred on the capsule's edge, so it reaches half its
        // width above the pill's own top — that is the edge that has to clear the digits.
        let pillTop = PaywallMetrics.offPillTop - PaywallMetrics.offPillOutline / 2
        let overlap = max(0, ink.upperBound - pillTop)
        // Phase 4h: "the OFF under 33% needs to be moved down a bit". At most a tenth of
        // the digits' height may be covered, and the pill still has to read as hanging off
        // them rather than floating free, so it stays within 6 pt of the ink.
        #expect(overlap <= (ink.upperBound - ink.lowerBound) * 0.10)
        #expect(pillTop - ink.upperBound <= 6)
        #expect(pillTop > ink.lowerBound)
    }

    @Test("nothing on the offer card overlaps the trial pill or the offer line")
    func offerCardRowsDoNotCollide() {
        let offBottom = PaywallMetrics.offPillTop + PaywallMetrics.offPillSize.height
        #expect(offBottom + PaywallMetrics.offPillOutline <= PaywallMetrics.trialPillTop)
        // Phase 4h: dropping the pill must not crowd "+3 day trial" — 8 pt of air minimum.
        #expect(PaywallMetrics.trialPillTop - offBottom >= 8)
        let offerLineBottom = PaywallMetrics.oneTimeOfferTop + PaywallMetrics.oneTimeOfferSize
        #expect(offerLineBottom <= PaywallMetrics.percentInk.lowerBound)
        let trialBottom = PaywallMetrics.trialPillTop + PaywallMetrics.trialPillSize.height
        #expect(trialBottom <= PaywallMetrics.neverAgainTop)
    }

    /// The offer card has to start *below* the flap's apex, or it swallows the peak; and it
    /// has to stay inside the envelope's own width.
    @Test("the offer card leaves the envelope flap's peak showing")
    func offerCardLeavesTheFlapPeakVisible() {
        let envelope = PaywallMetrics.openEnvelopeGeometry
        let peak = envelope.card.minY - envelope.flapApex.y
        #expect(peak >= 30)
        #expect(envelope.card.minX > envelope.left)
        #expect(envelope.card.maxX < envelope.right)
        #expect(envelope.card.maxY <= envelope.bottom)
    }

    @Test("the struck mark fills about 0.62 of the wax seal at both sizes")
    func sealMarkIsInsetToSixtyTwoPercent() {
        for diameter in [PaywallMetrics.closedSealDiameter, PaywallMetrics.openSealDiameter] {
            let mark = diameter * (1 - 2 * PaywallMetrics.sealMarkInset)
            #expect(abs(mark / diameter - 0.62) < 0.01)
            // It has to stay inside the recessed disc it is struck into.
            let disc = diameter * (1 - 2 * PaywallMetrics.sealDiscInset)
            #expect(mark < disc)
        }
    }
}
