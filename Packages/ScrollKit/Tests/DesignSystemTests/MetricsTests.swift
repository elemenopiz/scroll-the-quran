@testable import DesignSystem
import SwiftUI
import Testing

/// The reference captures are 1179x2556 px for a 393x852 pt screen, so every measured
/// value is a whole number of thirds of a pixel. These tests pin the numbers that the
/// feature tasks lay out against, so a re-measure has to be deliberate.
@Suite("Measured geometry")
struct MetricsTests {
    /// The scale the whole `Components/README.md` table is derived at.
    private let scale: CGFloat = 3

    @Test("A card spans the screen minus two 16 pt margins")
    func cardWidth() {
        #expect(Metrics.cardInset == Spacing.pageMargin)
        #expect(393 - Metrics.cardInset * 2 == 361)
    }

    @Test("Pill heights are the three measured CTA sizes", arguments: [
        (Metrics.pillHeightCompact, CGFloat(156)),
        (Metrics.pillHeight, CGFloat(168)),
        (Metrics.pillHeightLarge, CGFloat(195)),
    ])
    func pillHeights(points: CGFloat, pixels: CGFloat) {
        #expect(points * scale == pixels)
    }

    @Test("Circle diameters round-trip to their measured pixel values", arguments: [
        (Metrics.headerButton, CGFloat(132)),
        (Metrics.timelineNode, CGFloat(120)),
        (Metrics.rowLinkIcon, CGFloat(120)),
        (Metrics.statIcon, CGFloat(168)),
        (Metrics.capsuleGroupHeight, CGFloat(108)),
    ])
    func circleSizes(points: CGFloat, pixels: CGFloat) {
        #expect(points * scale == pixels)
    }

    @Test("Hairlines and bars stay sub-pixel-honest")
    func strokes() {
        #expect(Metrics.accentBarWidth * scale == 9)
        #expect(Metrics.timelineConnector * scale == 6)
        #expect(Metrics.progressBarHeight * scale == 30)
        #expect(Stroke.hairline == 1)
    }

    @Test("Deep Study boxes are inset further than the page margin")
    func sectionInset() {
        #expect(Metrics.sectionBoxInset == 24)
        #expect(Metrics.sectionBoxInset > Spacing.pageMargin)
        #expect(393 - Metrics.sectionBoxInset * 2 == 345)
    }

    @Test("The phone mockup keeps the real screen's aspect ratio")
    func phoneFrameAspect() {
        // CGFloat and the constant-folded literal differ in the last bit or two.
        #expect(abs(Metrics.phoneScreenAspect - 393.0 / 852.0) < 1e-12)
        #expect(Metrics.phoneScreenWidth + Metrics.phoneBezel * 2 <= Metrics.phoneFrameWidth)
    }
}
