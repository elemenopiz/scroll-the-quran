import DesignSystem
import SwiftUI

/// The white "4.8 ★★★★★ 10,166+ reviews" capsule.
///
/// Only rendered when real App Store numbers are injected — see `OnboardingStats`.
struct RatingPill: View {
    let value: String
    let count: String
    let suffix: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(value)
                .font(.body(22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 2) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.body(15))
                        .foregroundStyle(Color.ratingStar)
                }
            }
            Text("\(count) \(suffix)")
                .font(.body(15, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(height: OnboardingMetrics.ratingPillHeight)
        .background(Color.cardBackground, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.reviews.ratingPill")
    }
}

/// One review card: yellow rule, five stars, title, body, author.
struct ReviewCard: View {
    let card: OnboardingContent.Reviews.Card

    var body: some View {
        HStack(spacing: 0) {
            Color.ratingStar
                .frame(width: OnboardingMetrics.cardAccentWidth)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    ForEach(0 ..< max(0, min(card.stars, 5)), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.body(17))
                            .foregroundStyle(Color.ratingStar)
                    }
                }
                Text(card.title)
                    .font(.body(19, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(card.body)
                    .font(.body(19))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.author)
                    .font(.body(16, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: OnboardingMetrics.cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
