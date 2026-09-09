import DesignSystem
import SwiftUI

/// The device mockup the funnel slides show our own screens inside.
///
/// Geometry is measured off the reference slides: a 244 x 494 pt body, an 8 pt black
/// bezel, a 228 x 478 pt screen and the Dynamic Island 5 pt below the screen's top edge.
struct PhoneFrame<Screen: View>: View {
    @ViewBuilder var screen: Screen

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OnboardingMetrics.phoneCornerRadius, style: .continuous)
                .fill(Color.pillFill)
                .frame(width: OnboardingMetrics.phoneWidth, height: OnboardingMetrics.phoneHeight)

            screen
                .frame(
                    width: OnboardingMetrics.phoneScreenSize.width,
                    height: OnboardingMetrics.phoneScreenSize.height
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: OnboardingMetrics.phoneScreenCornerRadius, style: .continuous)
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.pillFill)
                        .frame(
                            width: OnboardingMetrics.phoneIslandSize.width,
                            height: OnboardingMetrics.phoneIslandSize.height
                        )
                        .padding(.top, OnboardingMetrics.phoneIslandTop)
                }
        }
        .frame(width: OnboardingMetrics.phoneWidth, height: OnboardingMetrics.phoneHeight)
        .accessibilityHidden(true)
    }
}
