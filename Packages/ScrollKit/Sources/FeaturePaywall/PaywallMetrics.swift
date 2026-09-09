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

    /// Logo mark: x 167...225, y 47...101.
    static let logoSize = CGSize(width: 58, height: 54)
    static let logoTop: CGFloat = 47
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
    /// Wax seal on the sealed envelope: 75 pt across, centred on (196, 371).
    static let closedSealDiameter: CGFloat = 75
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

    /// Every coordinate of the opened envelope, in reference points.
    struct OpenEnvelope: Sendable {
        let left: CGFloat
        let right: CGFloat
        /// Where the raised flap meets the body sides.
        let bodyTop: CGFloat
        let bottom: CGFloat
        let flapApex: CGPoint
        /// The point where the two front-pocket edges meet, under the seal.
        let pocketPoint: CGPoint
        let sealCenter: CGPoint
        let card: CGRect
    }

    static let openEnvelopeGeometry = OpenEnvelope(
        left: 26,
        right: 366,
        bodyTop: 338,
        bottom: 579,
        flapApex: CGPoint(x: 196.5, y: 118),
        pocketPoint: CGPoint(x: 196.5, y: 505),
        sealCenter: CGPoint(x: 196.5, y: 490),
        card: CGRect(x: 72, y: 143, width: 249, height: 417)
    )

    static let openSealDiameter: CGFloat = 92
    static let oneTimeOfferSize: CGFloat = 24
    static let oneTimeOfferTop: CGFloat = 185
    static let percentSize: CGFloat = 70
    static let percentTop: CGFloat = 206
    static let offPillSize = CGSize(width: 72, height: 47)
    static let offPillTop: CGFloat = 255
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
