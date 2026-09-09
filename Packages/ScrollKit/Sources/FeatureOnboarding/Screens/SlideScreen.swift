import DesignSystem
import SwiftUI

/// `onboarding-slide1` … `onboarding-slide4`: headline, subheadline, a phone-frame
/// mockup of one of our own screens, and Continue. Traced off the reference slides.
struct SlideScreen: View {
    let slide: OnboardingContent.Slide
    let primaryCTA: String
    let scale: ReferenceScale
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: scale.height(OnboardingMetrics.headlineToSubheadline)) {
                HeadlineText(
                    plain: slide.title,
                    size: scale.type(OnboardingMetrics.slideHeadlineSize),
                    extraLineSpacing: scale.height(OnboardingMetrics.slideHeadlineExtraLineSpacing),
                    columnWidth: scale.width(OnboardingMetrics.slideHeadlineWidth(titleLines: slide.titleLines)),
                    lineLimit: slide.titleLines
                )
                .accessibilityIdentifier("onboarding.slide.headline")

                SubheadlineText(text: slide.body, size: scale.type(OnboardingMetrics.subheadlineSize))
                    .accessibilityIdentifier("onboarding.slide.subheadline")
            }
            .padding(.horizontal, scale.width(OnboardingMetrics.textInset))
            .padding(.top, scale.height(OnboardingMetrics.slideTopPadding(titleLines: slide.titleLines)))
            .frame(
                height: scale.height(OnboardingMetrics.slideTextBlockHeight(titleLines: slide.titleLines)),
                alignment: .top
            )

            PhoneFrame(scale: scale) {
                MockupArt(mockup: slide.mockup, scale: scale)
            }
            // First to give up space on a screen shorter than the reference, so the
            // call to action can never be pushed off the bottom.
            .layoutPriority(-1)

            CallToActionStack(scale: scale) {
                PrimaryPillButton(
                    title: primaryCTA,
                    identifier: "onboarding.slide.continue",
                    scale: scale,
                    action: onContinue
                )
            }
            .padding(.top, scale.height(OnboardingMetrics.phoneToCallToAction))

            Spacer(minLength: 0)
        }
        // A slide change replaces the mockup rather than interpolating one placeholder
        // rectangle into the next.
        .id(slide.id)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.\(slide.id)")
    }
}

#Preview("Slide") {
    OnboardingCanvas { scale in
        SlideScreen(slide: OnboardingContent.sample.slides[2], primaryCTA: "Continue", scale: scale, onContinue: {})
    }
    .background(Color.appBackground)
}
