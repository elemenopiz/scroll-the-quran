import DesignSystem
import SwiftUI

/// `onboarding-slide1` … `onboarding-slide4`: headline, subheadline, a phone-frame
/// mockup of one of our own screens, and Continue. Traced off the reference slides.
struct SlideScreen: View {
    let slide: OnboardingContent.Slide
    let primaryCTA: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: OnboardingMetrics.headlineToSubheadline) {
                    HeadlineText(
                        plain: slide.title,
                        size: OnboardingMetrics.slideHeadlineSize,
                        pitch: OnboardingMetrics.slideHeadlinePitch
                    )
                    .accessibilityIdentifier("onboarding.slide.headline")

                    SubheadlineText(text: slide.body)
                        .accessibilityIdentifier("onboarding.slide.subheadline")
                }
                .padding(.horizontal, OnboardingMetrics.textInset)
                .padding(.top, OnboardingMetrics.slideTopPadding)

                PhoneFrame {
                    MockupArt(mockup: slide.mockup)
                }
                .padding(.top, OnboardingMetrics.subheadlineToPhone)

                Spacer(minLength: 0)

                CallToActionStack {
                    PrimaryPillButton(
                        title: primaryCTA,
                        identifier: "onboarding.slide.continue",
                        action: onContinue
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.\(slide.id)")
    }
}

#Preview("Slide") {
    SlideScreen(slide: OnboardingContent.sample.slides[2], primaryCTA: "Continue", onContinue: {})
}
