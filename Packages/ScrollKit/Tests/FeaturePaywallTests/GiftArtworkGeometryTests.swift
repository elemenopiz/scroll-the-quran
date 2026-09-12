import CoreGraphics
@testable import FeaturePaywall
import Testing

/// `PaywallMetrics.openEnvelope(...)` fits the generated 1000x1500 envelope render into the
/// 393x852 reference composition. Everything the gift-open screen draws hangs off it, so
/// the arithmetic is checked here rather than read off a screenshot.
@Suite("Gift artwork geometry")
struct GiftArtworkGeometryTests {
    private let geometry = PaywallMetrics.openEnvelopeGeometry

    @Test("The envelope's paper lands on the rect measured off gift-open.png")
    func envelopeSitsOnTheReferenceRect() {
        // The reference's 26...366 measured to the pixel; ours is centred on the canvas's
        // own midline (196.5), which puts each edge half a point further out.
        #expect(abs(geometry.left - 26) < 1)
        #expect(abs(geometry.right - 366) < 1)
        #expect(abs(geometry.bottom - PaywallMetrics.openEnvelopeBottom) < 0.5)
        #expect(abs(geometry.right - geometry.left - PaywallMetrics.openEnvelopeBodyWidth) < 0.5)
        // The layer's canvas is wider and taller than the paper it holds.
        #expect(geometry.art.minX < geometry.left)
        #expect(geometry.art.maxX > geometry.right)
        #expect(geometry.art.maxY > geometry.bottom)
        // ... and it keeps the render's own 2:3 aspect rather than being stretched to fit.
        #expect(abs(geometry.art.width / geometry.art.height - PaywallMetrics.openEnvelopeArt.aspect) < 0.001)
    }

    @Test("Flap peak, card, pocket mouth, seal and bottom edge stack in that order")
    func layersStackInReadingOrder() {
        #expect(geometry.flapApex.y < geometry.card.minY)
        #expect(geometry.card.minY < geometry.bodyTop)
        #expect(geometry.bodyTop < geometry.pocketPoint.y)
        #expect(geometry.pocketPoint.y < geometry.bottom)
        // The peak has to clear the card's top edge, or the tower reads as a stub.
        #expect(geometry.card.minY - geometry.flapApex.y >= 30)
        // The card is cut off by the pocket rather than ending in mid air.
        #expect(geometry.card.maxY > geometry.pocketPoint.y)
    }

    @Test("The card layer is drawn so its paper lands exactly on the card rect")
    func cardArtworkRegistersOnTheCardRect() {
        let scale = geometry.cardArt.width / PaywallMetrics.giftCardCanvas.width
        let body = PaywallMetrics.giftCardBody
        #expect(abs(geometry.cardArt.minX + body.minX * scale - geometry.card.minX) < 0.01)
        #expect(abs(geometry.cardArt.minY + body.minY * scale - geometry.card.minY) < 0.01)
        #expect(abs(body.width * scale - geometry.card.width) < 0.01)
        #expect(abs(body.height * scale - geometry.card.height) < 0.01)
        // The canvas is bigger than the paper, so the baked drop shadow has room to show.
        #expect(geometry.cardArt.minX < geometry.card.minX)
        #expect(geometry.cardArt.maxY > geometry.card.maxY)
    }

    @Test("The pocket mouth is flat at the corners and dips to the point under the seal")
    func pocketMouthDipsToTheSeal() {
        #expect(abs(geometry.pocketEdgeY(atX: geometry.left) - geometry.bodyTop) < 0.01)
        #expect(abs(geometry.pocketEdgeY(atX: geometry.right) - geometry.bodyTop) < 0.01)
        #expect(abs(geometry.pocketEdgeY(atX: geometry.pocketPoint.x) - geometry.pocketPoint.y) < 0.01)
        // Outside the paper it stays on the corner line rather than running away.
        #expect(abs(geometry.pocketEdgeY(atX: 0) - geometry.bodyTop) < 0.01)
        #expect(abs(geometry.pocketEdgeY(atX: PaywallMetrics.referenceWidth) - geometry.bodyTop) < 0.01)
    }

    /// The clip is what makes the card look inserted; it must not eat the offer.
    @Test("Every row of the offer copy stays above the pocket mouth")
    func offerCopyIsNotClipped() {
        let rows: [CGFloat] = [
            PaywallMetrics.oneTimeOfferTop + PaywallMetrics.oneTimeOfferSize,
            PaywallMetrics.percentInk.upperBound,
            PaywallMetrics.offPillTop + PaywallMetrics.offPillSize.height + PaywallMetrics.offPillOutline,
            PaywallMetrics.trialPillTop + PaywallMetrics.trialPillSize.height,
            PaywallMetrics.neverAgainTop + PaywallMetrics.neverAgainSize,
        ]
        // Checked at the card's own edges: the copy is centred, so it can never reach
        // further out than that, and the mouth is highest there.
        for edge in [geometry.card.minX, geometry.card.maxX] {
            let mouth = geometry.pocketEdgeY(atX: edge)
            for row in rows {
                #expect(row < mouth)
            }
        }
    }

    @Test("The wax seal covers the junction and stays on the paper")
    func sealSitsWhereTheFrontEdgesMeet() {
        let radius = PaywallMetrics.openSealDiameter / 2
        #expect(geometry.sealCenter == geometry.pocketPoint)
        #expect(geometry.sealCenter.y + radius < geometry.bottom)
        #expect(geometry.sealCenter.x - radius > geometry.left)
        #expect(geometry.sealCenter.x + radius < geometry.right)
    }

    @Test("A re-rendered envelope only has to restate its own six fractions")
    func layoutScalesWithTheBodyWidth() {
        let wide = PaywallMetrics.openEnvelope(bodyWidth: 680, bodyBottom: 1158, cardTop: 324, cardWidth: 498)
        #expect(abs(wide.art.width - geometry.art.width * 2) < 0.01)
        #expect(abs(wide.bottom - geometry.bottom * 2) < 0.01)
        #expect(abs(wide.bodyTop - geometry.bodyTop * 2) < 0.01)
        #expect(abs(wide.card.height - geometry.card.height * 2) < 0.01)
    }

    @Test("The closed envelope's canvas is placed so its paper is the reference envelope")
    func closedEnvelopeArtCentresThePaper() {
        let art = PaywallMetrics.closedEnvelopeArt()
        let scale = art.width / PaywallMetrics.closedEnvelopeCanvas.width
        let paper = PaywallMetrics.closedEnvelopeArtBody
        #expect(abs(paper.width * scale - PaywallMetrics.closedEnvelope.width) < 0.01)
        #expect(abs(art.midX - PaywallMetrics.closedEnvelopeCenter.x) < 0.01)
        #expect(abs(art.midY - PaywallMetrics.closedEnvelopeCenter.y) < 0.01)
        // The paper is centred in its canvas, so the canvas centre is the paper's centre.
        #expect(abs(paper.midX - PaywallMetrics.closedEnvelopeCanvas.width / 2) < 1)
        #expect(abs(paper.midY - PaywallMetrics.closedEnvelopeCanvas.height / 2) < 1)
    }
}
