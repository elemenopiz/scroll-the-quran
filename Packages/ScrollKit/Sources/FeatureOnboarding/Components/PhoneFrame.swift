import DesignSystem
import SwiftUI

/// The device mockup the funnel slides show our own screens inside.
///
/// Geometry is measured off the reference slides: a 244 x 494 pt body, an 8 pt black
/// bezel, a 228 x 478 pt screen and the Dynamic Island 5 pt below the screen's top edge.
struct PhoneFrame<Screen: View>: View {
    let scale: ReferenceScale
    @ViewBuilder var screen: Screen

    private var size: CGSize {
        CGSize(
            width: scale.width(OnboardingMetrics.phoneWidth),
            height: scale.height(OnboardingMetrics.phoneHeight)
        )
    }

    private var screenSize: CGSize {
        CGSize(
            width: scale.width(OnboardingMetrics.phoneScreenSize.width),
            height: scale.height(OnboardingMetrics.phoneScreenSize.height)
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: scale.width(OnboardingMetrics.phoneCornerRadius), style: .continuous)
                .fill(Color.pillFill)
                .frame(width: size.width, height: size.height)

            screen
                .frame(width: screenSize.width, height: screenSize.height)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: scale.width(OnboardingMetrics.phoneScreenCornerRadius),
                        style: .continuous
                    )
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.pillFill)
                        .frame(
                            width: scale.width(OnboardingMetrics.phoneIslandSize.width),
                            height: scale.height(OnboardingMetrics.phoneIslandSize.height)
                        )
                        .padding(.top, scale.height(OnboardingMetrics.phoneIslandTop))
                }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}
