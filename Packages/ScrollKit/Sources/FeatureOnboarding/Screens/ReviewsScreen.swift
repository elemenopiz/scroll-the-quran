import DesignSystem
import SwiftUI

/// `onboarding-reviews`: the social-proof screen. Traced off `Reference/onboarding-reviews.png`.
///
/// Every number on it is a placeholder in `Content/onboarding.json`. The rating pill and
/// the install count render **only** when real values are injected through `OnboardingStats`;
/// with none, the subtitle drops the number and the pill disappears. Invented social proof
/// is an App Review rejection.
struct ReviewsScreen: View {
    let content: OnboardingContent.Reviews
    let subtitle: String
    let ratingValue: String?
    let ratingCount: String?
    let scale: ReferenceScale
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    HeadlineText(
                        plain: content.title,
                        size: scale.type(OnboardingMetrics.slideHeadlineSize),
                        extraLineSpacing: scale.height(OnboardingMetrics.slideHeadlineExtraLineSpacing),
                        columnWidth: scale.width(OnboardingMetrics.slideHeadlineWidth),
                        lineLimit: OnboardingMetrics.reviewsHeadlineLines
                    )
                    .accessibilityIdentifier("onboarding.reviews.headline")
                    .padding(.top, scale.height(OnboardingMetrics.reviewsTopPadding))

                    SubheadlineText(text: subtitle, size: scale.type(OnboardingMetrics.subheadlineSize))
                        .padding(.top, scale.height(OnboardingMetrics.headlineToSubheadline))
                        .padding(.horizontal, scale.width(OnboardingMetrics.textInset))
                        .accessibilityIdentifier("onboarding.reviews.subtitle")

                    if let ratingValue, let ratingCount {
                        RatingPill(
                            value: ratingValue, count: ratingCount,
                            suffix: content.ratingSuffix, scale: scale
                        )
                        .padding(.top, scale.height(OnboardingMetrics.subtitleToRatingPill))
                    }

                    VStack(spacing: scale.height(OnboardingMetrics.cardSpacing)) {
                        ForEach(content.cards) { card in
                            ReviewCard(card: card, scale: scale)
                        }
                    }
                    .padding(.top, scale.height(OnboardingMetrics.ratingPillToCards))
                    .padding(.horizontal, scale.width(OnboardingMetrics.cardInset))
                }
                .padding(.bottom, scale.height(OnboardingMetrics.ctaHeight + 60))
            }
            .scrollIndicators(.hidden)

            CallToActionStack(scale: scale) {
                PrimaryPillButton(
                    title: content.primaryCTA,
                    identifier: "onboarding.reviews.continue",
                    scale: scale,
                    action: onContinue
                )
            }
            // The cards scroll *under* the pill, and without this the third card's text
            // read straight through the button's edges. The page's own ground, fading
            // upward, so the pill sits on a clean band with no drawn edge.
            .background(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.appBackground.opacity(0), location: 0),
                        .init(color: Color.appBackground, location: 0.45),
                        .init(color: Color.appBackground, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: scale.height(OnboardingMetrics.ctaHeight + 96))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding-reviews")
    }
}

#Preview("Reviews") {
    OnboardingCanvas { scale in
        ReviewsScreen(
            content: OnboardingContent.sample.reviews,
            subtitle: OnboardingContent.sample.reviews.subtitleWithoutCount,
            ratingValue: nil,
            ratingCount: nil,
            scale: scale,
            onContinue: {}
        )
    }
    .background(Color.appBackground)
}
