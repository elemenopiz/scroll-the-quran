import SwiftUI

/// Lays its content out in the 393x852 pt space the reference captures were taken in and
/// scales that canvas up to fill the real screen.
///
/// The paywall and the gift screens are fixed marketing compositions: every element sits
/// at a measured coordinate rather than flowing, so scaling the whole canvas keeps the
/// composition identical on a 852 pt iPhone 15 and a 874 pt iPhone 17 instead of letting
/// the extra 22 pt drift through the layout.
struct ReferenceCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let scale = max(
                proxy.size.width / PaywallMetrics.referenceWidth,
                proxy.size.height / PaywallMetrics.referenceHeight
            )
            content()
                .frame(
                    width: PaywallMetrics.referenceWidth,
                    height: PaywallMetrics.referenceHeight,
                    alignment: .top
                )
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        // The canvas is a fixed composition: let type grow, but not far enough to push
        // the call to action off the bottom of a screen that cannot scroll.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
