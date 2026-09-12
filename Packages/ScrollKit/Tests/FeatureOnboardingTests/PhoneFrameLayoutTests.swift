import CoreGraphics
@testable import FeatureOnboarding
import Testing

/// The frame on the funnel slides is a drawing of a device, and a drawing of a device that
/// is off by a few points stops reading as one. Everything here is a property of
/// `DeviceFrameMetrics` rather than a number copied out of a picture, so a future tweak to
/// the enclosure cannot quietly reintroduce the crop it was written to remove.
@Suite("Phone frame geometry")
struct PhoneFrameLayoutTests {
    /// Both slide scales the funnel can actually run at: the reference grid, and a real
    /// iPhone 17 Pro safe area.
    static let scales: [ReferenceScale] = [
        .identity,
        ReferenceScale(CGSize(width: 402, height: 778)),
    ]

    @Test("The enclosure is the device's, with the glass concentric inside it")
    func enclosureFollowsTheDevice() {
        let metrics = DeviceFrameMetrics.self
        #expect(metrics.inset == metrics.innerBorder + metrics.rim)
        #expect(metrics.outerSize.width == metrics.screenSize.width + metrics.inset * 2)
        #expect(metrics.outerSize.height == metrics.screenSize.height + metrics.inset * 2)
        // Concentric corners: the two radii differ by exactly the material between them.
        #expect(metrics.outerCornerRadius - metrics.screenCornerRadius == metrics.inset)
    }

    @Test("The screen window keeps the capture's aspect exactly", arguments: scales)
    func windowHasTheCapturesAspect(scale: ReferenceScale) {
        let layout = PhoneFrameLayout(scale: scale)
        let device = DeviceFrameMetrics.screenSize.width / DeviceFrameMetrics.screenSize.height
        let window = layout.screenSize.width / layout.screenSize.height
        // Nothing to crop: a capture fitted into this window touches all four edges.
        #expect(abs(window - device) < 0.0001)
    }

    @Test("The frame is a single scale of the device, not two", arguments: scales)
    func oneScaleForBothAxes(scale: ReferenceScale) {
        let layout = PhoneFrameLayout(scale: scale)
        let outer = DeviceFrameMetrics.outerSize
        #expect(abs(layout.outerSize.width / outer.width - layout.outerSize.height / outer.height) < 0.0001)
        #expect(abs(layout.outerSize.height - scale.height(OnboardingMetrics.phoneHeight)) < 0.0001)
    }

    @Test("The enclosure lands on the reference's own silhouette")
    func enclosureLandsOnTheReferenceRows() {
        let layout = PhoneFrameLayout(scale: .identity)
        let top = OnboardingMetrics.slidePhoneTop(titleLines: 2)
        // onboarding-slide3/4: the reference's enclosure is 74.85...318.15 x 238.3...736.
        #expect(abs(top - 238.3) < 1)
        #expect(abs(top + layout.outerSize.height - 736) < 1)
        let left = (ReferenceScale.referenceWidth - layout.outerSize.width) / 2
        // The width cannot match as well: the reference's body is 243.3 pt across, which
        // is a proportion no iPhone has. Ours is inside it, never outside, by under 5 pt.
        #expect(left > 74.85)
        #expect(left - 74.85 < 5)
    }

    @Test("The call to action still follows the enclosure onto the reference row")
    func callToActionStaysOnRow746() {
        let bottom = OnboardingMetrics.slidePhoneTop(titleLines: 2)
            + OnboardingMetrics.phoneHeight
            + OnboardingMetrics.phoneToCallToAction
        #expect(bottom == 746)
        // Slide 2's three-line headline pushes both down by the same 16 pt.
        let tall = OnboardingMetrics.slidePhoneTop(titleLines: 3)
            + OnboardingMetrics.phoneHeight
            + OnboardingMetrics.phoneToCallToAction
        #expect(tall == 762)
    }

    @Test("Every side button is proud of the rail and inside the enclosure", arguments: scales)
    func buttonsSitOnTheEdges(scale: ReferenceScale) {
        let layout = PhoneFrameLayout(scale: scale)
        #expect(!DeviceFrameMetrics.buttons.isEmpty)
        #expect(DeviceFrameMetrics.buttons.filter(\.onLeft).count == 3)
        #expect(DeviceFrameMetrics.buttons.filter { !$0.onLeft }.count == 1)
        for button in DeviceFrameMetrics.buttons {
            let rect = layout.buttonRect(button)
            #expect(abs(rect.width - (layout.rim + layout.buttonProud)) < 0.0001)
            // Stands out of the rail by `buttonProud` and tucks under it by the rail's width.
            if button.onLeft {
                #expect(abs(rect.minX + layout.buttonProud) < 0.0001)
            } else {
                #expect(abs(rect.maxX - (layout.outerSize.width + layout.buttonProud)) < 0.0001)
            }
            // Well clear of the corner radius at both ends, or it reads as a dent.
            #expect(rect.minY > layout.outerCornerRadius)
            #expect(rect.maxY < layout.outerSize.height - layout.outerCornerRadius)
        }
    }

    @Test("The buttons do not overlap each other down the left edge")
    func leftButtonsAreSeparate() {
        let left = DeviceFrameMetrics.buttons.filter(\.onLeft).sorted { $0.top < $1.top }
        for (upper, lower) in zip(left, left.dropFirst()) {
            #expect(upper.top + upper.height < lower.top)
        }
    }
}
