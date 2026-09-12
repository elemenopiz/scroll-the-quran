import CoreGraphics
import DesignSystem
import SwiftUI

/// Everything on the paywall and the gift screens is positioned from numbers measured
/// off `Reference/paywall-trial.png`, `paywall-plans.png`, `gift-closed.png` and
/// `gift-open.png` (both normalised to the 393x852 pt reference space).
///
/// They live in one place so the snapshot loop has a single dial per element instead of
/// magic numbers buried in a view body.
enum PaywallMetrics {
    /// The reference capture space. Screens are laid out top-anchored for the header and
    /// bottom-anchored for the footer, so a taller device grows the slack in the middle.
    static let referenceWidth: CGFloat = 393
    static let referenceHeight: CGFloat = 852

    // MARK: - paywall-trial

    /// Logo mark. The reference draws it 58x54 at y 47, which on a Dynamic Island device
    /// puts it *behind* the island (bottom edge ~52 pt). Phase 4e's accepted deviation:
    /// square, 72 pt, and anchored to the safe-area top instead of a measured constant —
    /// see `logoTop(safeAreaTop:screen:)`.
    static let logoSize = CGSize(width: 72, height: 72)
    /// Air between the safe-area top edge and the mark, in **screen** points. The safe-area
    /// top already sits below the island; this is the extra breathing room on top of it.
    static let logoTopPadding: CGFloat = 2
    /// The reference's own y, and the floor for a device that reports no top inset.
    static let logoTopFloor: CGFloat = 47

    /// `ReferenceCanvas` scales the 393x852 composition to fill the screen and centres it,
    /// so a screen-space y has to be mapped back before it can be used as a canvas padding.
    static func canvasScale(screen: CGSize) -> CGFloat {
        guard screen.width > 0, screen.height > 0 else { return 1 }
        return max(screen.width / referenceWidth, screen.height / referenceHeight)
    }

    /// Screen point -> reference-canvas point.
    static func referenceY(screenY: CGFloat, screen: CGSize) -> CGFloat {
        (screenY - screen.height / 2) / canvasScale(screen: screen) + referenceHeight / 2
    }

    /// Reference-canvas point -> screen point. The inverse of `referenceY(screenY:screen:)`,
    /// and what the tests measure the mark's clearance from the island with.
    static func screenY(referenceY y: CGFloat, screen: CGSize) -> CGFloat {
        (y - referenceHeight / 2) * canvasScale(screen: screen) + screen.height / 2
    }

    /// Where the mark's top goes, in canvas points, for a device whose safe-area top inset
    /// is `safeAreaTop`. Anchoring to the inset rather than to a constant is what keeps the
    /// ring clear of the Dynamic Island (or the notch, or nothing at all) on every device.
    static func logoTop(safeAreaTop: CGFloat, screen: CGSize) -> CGFloat {
        max(referenceY(screenY: safeAreaTop + logoTopPadding, screen: screen), logoTopFloor)
    }

    /// Close control: ~11 pt glyph centred on (24, 76).
    static let closeSize: CGFloat = 17
    /// Leading edge of the 44 pt tap target, so the 17 pt glyph centres on x = 24
    /// without the target hanging off the screen.
    static let closeLeading: CGFloat = 24
    static let closeCenterY: CGFloat = 76

    /// Headline cap-top y 166, second baseline y 220.
    static let headlineSize: CGFloat = 29
    static let headlineTop: CGFloat = 158
    /// Poppins sets 1.4 em of line box; the reference runs 34 pt baseline to baseline.
    static let headlineLineSpacing: CGFloat = -8

    /// Timeline: 40 pt discs at x 16, centres y 287.5 / 371.5 / 441.5, copy from x 73.
    static let timelineTop: CGFloat = 268
    static let timelineDisc: CGFloat = 40
    static let timelineGap: CGFloat = 17
    static let timelineRowSpacing: CGFloat = 18
    static let timelineTitleSize: CGFloat = 16
    static let timelineTitleGap: CGFloat = 3
    static let timelineTextTop: CGFloat = 2
    static let timelineBodySize: CGFloat = 15
    static let timelineBodyLineSpacing: CGFloat = -3
    static let timelineConnector: CGFloat = 1.5
    /// First disc centre (287.5) to last disc centre (441.5).
    static let timelineConnectorHeight: CGFloat = 154

    /// Footer stack, measured from the bottom edge of the 852 pt reference.
    static let noPaymentSize: CGFloat = 14
    static let priceSize: CGFloat = 16

    /// Absolute box tops for the footer stack, tuned against the reference ink bands
    /// (586, 623, 647, 680, 763 and 810 respectively).
    static let noPaymentTop: CGFloat = 582
    static let priceTop: CGFloat = 619
    static let priceNoteTop: CGFloat = 644
    static let ctaTop: CGFloat = 680
    static let viewAllTop: CGFloat = 759
    static let legalTop: CGFloat = 806
    static let priceNoteSize: CGFloat = 14
    static let ctaHeight: CGFloat = 65
    static let ctaLabelSize: CGFloat = 17
    static let viewAllPlansSize: CGFloat = 14
    static let legalSize: CGFloat = 12

    /// y 586 (check + "No payment due now") down to y 819 (legal row) on a 852 pt screen.
    static let footerTop: CGFloat = 582
    static let footerBottomInset: CGFloat = 33

    // MARK: - paywall-plans

    /// The sheet's dimmed backdrop measured #BABABA over white.
    static let sheetDim: Double = 0.27
    /// Sheet: x 7...386, top y 512, 10 pt top corners.
    static let sheetInset: CGFloat = 7
    static let sheetTop: CGFloat = 512
    static let sheetCornerRadius: CGFloat = 10
    /// Plan cards: x 20...373, 62 pt tall, 9 pt apart, 12 pt corners.
    static let cardInset: CGFloat = 20
    static let cardHeight: CGFloat = 62
    static let cardSpacing: CGFloat = 9
    static let cardCornerRadius: CGFloat = 12
    static let cardTop: CGFloat = 546
    /// "SAVE 50%": 65x19 centred, bottom edge 7 pt below the selected card's top border.
    static let badgeSize = CGSize(width: 65, height: 19)
    static let badgeOverlap: CGFloat = 7
    static let badgeTextSize: CGFloat = 11
    static let planTitleSize: CGFloat = 16
    static let planPriceSize: CGFloat = 15
    static let planWeeklySize: CGFloat = 15
    /// Absolute tops inside the sheet, from the reference ink bands.
    static let sheetNoPaymentTop: CGFloat = 694
    static let sheetCTATop: CGFloat = 727
    static let sheetCancelTop: CGFloat = 803
    static let cancelAnytimeSize: CGFloat = 14

    // MARK: - gift

    /// Envelope: x 68...328, y 277...458 on gift-closed.
    static let closedEnvelope = CGRect(x: 68, y: 277, width: 235, height: 153)
    /// The sealed envelope sits slightly off square in the reference.
    static let closedEnvelopeRotation: CGFloat = -6.6
    static let closedEnvelopeCenter = CGPoint(x: 196, y: 368)

    /// The generated `EnvelopeClosed` layer: its 1200x900 canvas and the envelope's own
    /// bounds inside it (printed by `Artwork/tools/gift-assets.sh`). The paper is centred
    /// in the canvas, so centring the canvas centres the paper.
    static let closedEnvelopeCanvas = CGSize(width: 1200, height: 900)
    static let closedEnvelopeArtBody = CGRect(x: 24, y: 55, width: 1152, height: 790)

    /// Where to draw the `EnvelopeClosed` layer so its paper spans `width` about `center`.
    /// The render is a shade squarer than the reference's envelope (1.46 : 1 against
    /// 1.54 : 1), and width is what the eye measures, so width is what is matched.
    static func closedEnvelopeArt(
        body: CGRect = closedEnvelopeArtBody,
        canvas: CGSize = closedEnvelopeCanvas,
        width: CGFloat = closedEnvelope.width,
        center: CGPoint = closedEnvelopeCenter
    ) -> CGRect {
        let scale = width / body.width
        let size = CGSize(width: canvas.width * scale, height: canvas.height * scale)
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Wax seal on the sealed envelope: 75 pt across, centred on (196, 371). The generated
    /// layer already carries one (0.298 of the paper's width, so 70 pt at 235), which is
    /// why `SealedEnvelope` only draws `WaxSeal` when the artwork is missing.
    static let closedSealDiameter: CGFloat = 75
    /// The recessed disc inside the wax: 56.7 pt across on the 75 pt seal in
    /// `gift-closed.png`, i.e. inset 12.2 % of the diameter on each side.
    static let sealDiscInset: CGFloat = 0.122
    /// The struck mark: 46.7 pt across on that same 75 pt seal — 0.62 of the diameter,
    /// so it is inset 19 % on each side.
    static let sealMarkInset: CGFloat = 0.19
    /// The emboss offset, as a fraction of the seal: 1 pt on the 92 pt open seal.
    static let sealEmbossOffset: CGFloat = 0.011
    static let giftHeadlineSize: CGFloat = 31
    static let giftHeadlineTop: CGFloat = 564
    static let giftHeadlineLineSpacing: CGFloat = -7
    static let giftSubtitleSize: CGFloat = 17
    static let giftSubtitleLineSpacing: CGFloat = -3
    static let giftRevealSize: CGFloat = 22

    /// gift-closed text, from the reference ink bands (576, 614, 664, 686, 764).
    static let giftHeadlineTopClosed: CGFloat = 568
    static let giftSubtitleTop: CGFloat = 659
    static let giftRevealTop: CGFloat = 758

    // MARK: - gift artwork

    /// The generated `EnvelopeOpen` layer, measured on its own 1000x1500 canvas.
    ///
    /// `Artwork/tools/gift-assets.sh` prints these six fractions every time it cuts the
    /// layer, and they are the *only* thing tying the app to a particular render: a new
    /// portrait envelope is a one-file drop-in plus one line here.
    struct OpenEnvelopeArt: Sendable, Equatable {
        /// Canvas width / canvas height.
        let aspect: CGFloat
        /// Left and right edge of the envelope **body**, as fractions of the canvas width.
        let bodyLeft: CGFloat
        let bodyRight: CGFloat
        /// The raised flap's peak, as a fraction of the canvas height.
        let flapApex: CGFloat
        /// The front pocket's top corners — the horizontal line the offer card is cut at.
        let pocketCorner: CGFloat
        /// Where the two front-pocket edges meet at the centre, under the wax seal.
        let pocketApex: CGFloat
        /// The envelope's bottom edge.
        let bottom: CGFloat
    }

    static let openEnvelopeArt = OpenEnvelopeArt(
        aspect: 1000.0 / 1500.0,
        bodyLeft: 0.0400,
        bodyRight: 0.9600,
        flapApex: 0.1147,
        pocketCorner: 0.6133,
        pocketApex: 0.7667,
        bottom: 0.9733
    )

    /// The `EnvelopeCard` layer's 900x1200 canvas, and the card **body** inside it (the
    /// paper itself; its drop shadow spills into the margin around this rect).
    static let giftCardCanvas = CGSize(width: 900, height: 1200)
    static let giftCardBody = CGRect(x: 55, y: 36, width: 791, height: 1128)

    /// Every coordinate of the opened envelope, in reference points.
    struct OpenEnvelope: Sendable, Equatable {
        /// Where the `EnvelopeOpen` layer is drawn. Its canvas is larger than the
        /// envelope: the margins around the paper are part of the image.
        let art: CGRect
        let left: CGFloat
        let right: CGFloat
        /// Where the raised flap meets the body sides — the front pocket's top corners,
        /// and the line the offer card is clipped at.
        let bodyTop: CGFloat
        let bottom: CGFloat
        let flapApex: CGPoint
        /// The point where the two front-pocket edges meet, under the seal.
        let pocketPoint: CGPoint
        let sealCenter: CGPoint
        /// The card's paper, which the text overlay is positioned against.
        let card: CGRect
        /// Where the `EnvelopeCard` layer is drawn so its body lands exactly on `card`.
        let cardArt: CGRect

        /// The bottom of the card's visible band at a given x: flat across the pocket's
        /// top corners and dipping to the point where the two front edges meet. This is
        /// the line `PocketMouth` clips the card at, and what the offer copy has to
        /// stay above to be readable.
        func pocketEdgeY(atX x: CGFloat) -> CGFloat {
            let half = pocketPoint.x - left
            guard half > 0 else { return bodyTop }
            let across = min(1, abs(x - pocketPoint.x) / half)
            return pocketPoint.y + (bodyTop - pocketPoint.y) * across
        }
    }

    /// Envelope body x 26...366 with its bottom edge on y 579, and the card 249 pt wide
    /// with its top on y 162 — all four measured off `gift-open.png`.
    static let openEnvelopeBodyWidth: CGFloat = 340
    static let openEnvelopeBottom: CGFloat = 579
    /// Card top is 486 px = 162 pt in `gift-open.png`, not the 143 Phase 3 used: at 143
    /// the card swallowed the flap and left only a sliver of the peak showing.
    static let openCardTop: CGFloat = 162
    static let openCardWidth: CGFloat = 249

    /// Fit the generated layers into the reference composition: scale the envelope art so
    /// its body spans `bodyWidth` and its bottom edge lands on `bodyBottom`, then hang the
    /// card, the seal and the card's text rect off the art's own proportions.
    ///
    /// Everything the two gift layers need is derived here rather than hard-coded, so a
    /// re-rendered envelope only changes `openEnvelopeArt`.
    static func openEnvelope(
        art: OpenEnvelopeArt = openEnvelopeArt,
        cardBody: CGRect = giftCardBody,
        cardCanvas: CGSize = giftCardCanvas,
        bodyWidth: CGFloat = openEnvelopeBodyWidth,
        bodyCenterX: CGFloat = referenceWidth / 2,
        bodyBottom: CGFloat = openEnvelopeBottom,
        cardTop: CGFloat = openCardTop,
        cardWidth: CGFloat = openCardWidth
    ) -> OpenEnvelope {
        let artWidth = bodyWidth / (art.bodyRight - art.bodyLeft)
        let artHeight = artWidth / art.aspect
        let artRect = CGRect(
            x: bodyCenterX - artWidth / 2,
            y: bodyBottom - art.bottom * artHeight,
            width: artWidth,
            height: artHeight
        )
        func y(_ fraction: CGFloat) -> CGFloat {
            artRect.minY + fraction * artHeight
        }

        let cardScale = cardWidth / cardBody.width
        let card = CGRect(
            x: bodyCenterX - cardWidth / 2,
            y: cardTop,
            width: cardWidth,
            height: cardBody.height * cardScale
        )
        return OpenEnvelope(
            art: artRect,
            left: artRect.minX + art.bodyLeft * artWidth,
            right: artRect.minX + art.bodyRight * artWidth,
            bodyTop: y(art.pocketCorner),
            bottom: y(art.bottom),
            flapApex: CGPoint(x: bodyCenterX, y: y(art.flapApex)),
            pocketPoint: CGPoint(x: bodyCenterX, y: y(art.pocketApex)),
            sealCenter: CGPoint(x: bodyCenterX, y: y(art.pocketApex)),
            card: card,
            cardArt: CGRect(
                x: card.minX - cardBody.minX * cardScale,
                y: card.minY - cardBody.minY * cardScale,
                width: cardCanvas.width * cardScale,
                height: cardCanvas.height * cardScale
            )
        )
    }

    static let openEnvelopeGeometry = openEnvelope()

    static let openSealDiameter: CGFloat = 92
    static let oneTimeOfferSize: CGFloat = 24
    static let oneTimeOfferTop: CGFloat = 185
    static let percentSize: CGFloat = 70
    /// The "33%" ink band runs y 224.7...268.7 in the reference. Geo Bold sets a taller
    /// cap than the reference's face, so the box top is what is matched: 202 puts our
    /// ink top on 224.8 and the digits run 5 pt deeper than the reference's.
    static let percentTop: CGFloat = 202
    /// "OFF": black capsule x 162...230.7, y 268...301 in `gift-open.png`, with a ~3.3 pt
    /// white outline around it. It clears the "33%" digits, whose ink ends at y 266.
    static let offPillSize = CGSize(width: 69, height: 33)
    /// 2 pt below the reference's 268, which is what our deeper digits need to keep the
    /// pill under their baseline rather than across it.
    static let offPillTop: CGFloat = 270
    static let offPillOutline: CGFloat = 3.3
    /// The "33%" ink **as we render it** — Geo Bold at `percentSize`, measured off
    /// `.build/snapshots/gift-open.png`. The reference's own band is 224.7...268.7; ours is
    /// the same top and 5 pt deeper. The OFF pill, outline included, must not cover more
    /// than a quarter of it.
    static let percentInk = ClosedRange<CGFloat>(uncheckedBounds: (lower: 224.8, upper: 274.1))
    static let trialPillSize = CGSize(width: 131, height: 35)
    static let trialPillTop: CGFloat = 323
    static let neverAgainSize: CGFloat = 13
    static let neverAgainTop: CGFloat = 369
    static let luckySize: CGFloat = 30
    static let luckyTop: CGFloat = 622
    static let strikePriceSize: CGFloat = 24
    static let offerPillSize = CGSize(width: 105, height: 40)
    static let priceRowTop: CGFloat = 674
    static let footnoteSize: CGFloat = 13
    static let footnoteTop: CGFloat = 800
    static let giftCTAHeight: CGFloat = 60
    static let giftCTATop: CGFloat = 728
    static let giftCloseTop: CGFloat = 73
}
