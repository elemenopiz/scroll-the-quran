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
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HeadlineText(
                        plain: content.title,
                        size: OnboardingMetrics.slideHeadlineSize,
                        pitch: OnboardingMetrics.slideHeadlinePitch
                    )
                    .accessibilityIdentifier("onboarding.reviews.headline")
                    .padding(.top, OnboardingMetrics.reviewsTopPadding)

                    SubheadlineText(text: subtitle)
                        .padding(.top, OnboardingMetrics.headlineToSubheadline)
                        .accessibilityIdentifier("onboarding.reviews.subtitle")

                    if let ratingValue, let ratingCount {
                        RatingPill(value: ratingValue, count: ratingCount, suffix: content.ratingSuffix)
                            .padding(.top, Spacing.lg)
                    }

                    VStack(spacing: OnboardingMetrics.cardSpacing) {
                        ForEach(content.cards) { card in
                            ReviewCard(card: card)
                        }
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.horizontal, OnboardingMetrics.cardInset - OnboardingMetrics.textInset)
                }
                .padding(.horizontal, OnboardingMetrics.textInset)
                .padding(.bottom, OnboardingMetrics.ctaHeight + Spacing.huge)
            }
            .scrollIndicators(.hidden)

            CallToActionStack {
                PrimaryPillButton(
                    title: content.primaryCTA,
                    identifier: "onboarding.reviews.continue",
                    action: onContinue
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding-reviews")
    }
}

#Preview("Reviews") {
    ReviewsScreen(
        content: OnboardingContent.sample.reviews,
        subtitle: OnboardingContent.sample.reviews.subtitleWithoutCount,
        ratingValue: nil,
        ratingCount: nil,
        onContinue: {}
    )
}
