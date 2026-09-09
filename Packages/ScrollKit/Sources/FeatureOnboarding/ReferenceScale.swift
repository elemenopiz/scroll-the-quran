import CoreGraphics
import SwiftUI

/// Maps the measured reference geometry (393 x 852 pt, iPhone 15 Pro class) onto
/// whatever device is actually running.
///
/// Everything in `OnboardingMetrics` is a reference-point number. On a 402 x 874 pt
/// iPhone 17 the funnel has to grow proportionally, not sit at the same absolute
/// points: that is both what the design wants and what `Tools/snapshot/compare.sh`
/// measures, since it squashes the capture back to 393 x 852 before diffing.
struct ReferenceScale: Equatable {
    /// The reference screen the captures in `Reference/` were taken on.
    static let referenceWidth: CGFloat = 393
    /// 852 pt less the reference device's 59 pt top and 34 pt bottom safe areas.
    static let referenceSafeHeight: CGFloat = 759

    let horizontal: CGFloat
    let vertical: CGFloat

    init(_ size: CGSize) {
        horizontal = size.width > 0 ? size.width / Self.referenceWidth : 1
        vertical = size.height > 0 ? size.height / Self.referenceSafeHeight : 1
    }

    static let identity = ReferenceScale(CGSize(width: referenceWidth, height: referenceSafeHeight))

    /// A reference width, inset or radius in device points.
    func width(_ value: CGFloat) -> CGFloat {
        value * horizontal
    }

    /// A reference height or vertical gap in device points.
    func height(_ value: CGFloat) -> CGFloat {
        value * vertical
    }

    /// Type scales with the horizontal axis so line breaks land where they do on the
    /// reference; scaling it vertically would change the wrapping.
    func type(_ value: CGFloat) -> CGFloat {
        value * horizontal
    }
}

/// Lays a funnel screen out on the reference grid: fills the safe area, measures it,
/// and hands the content a `ReferenceScale`.
struct OnboardingCanvas<Content: View>: View {
    @ViewBuilder var content: (ReferenceScale) -> Content

    var body: some View {
        GeometryReader { proxy in
            content(ReferenceScale(proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
