import DesignSystem
import SwiftUI

/// The white "4.8 ★★★★★ 10,166+ reviews" capsule.
///
/// Only rendered when real App Store numbers are injected — see `OnboardingStats`.
struct RatingPill: View {
    let value: String
    let count: String
    let suffix: String
    let scale: ReferenceScale

    var body: some View {
        HStack(spacing: scale.width(Spacing.sm)) {
            Text(value)
                .font(.body(scale.type(22), weight: .bold))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: scale.width(2)) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.body(scale.type(15)))
                        .foregroundStyle(Color.ratingStar)
                }
            }
            .accessibilityHidden(true)
            Text("\(count) \(suffix)")
                .font(.body(scale.type(15), weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, scale.width(Spacing.xl))
        .frame(height: scale.height(OnboardingMetrics.ratingPillHeight))
        .background(Color.cardBackground, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) out of 5 stars, \(count) \(suffix)")
        .accessibilityIdentifier("onboarding.reviews.ratingPill")
    }
}

/// One review card: yellow rule, five stars, title, body, author.
struct ReviewCard: View {
    let card: OnboardingContent.Reviews.Card
    let scale: ReferenceScale

    var body: some View {
        HStack(spacing: 0) {
            Color.ratingStar
                .frame(width: scale.width(OnboardingMetrics.cardAccentWidth))

            VStack(alignment: .leading, spacing: scale.height(Spacing.sm)) {
                HStack(spacing: scale.width(Spacing.xs)) {
                    ForEach(0 ..< max(0, min(card.stars, 5)), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.body(scale.type(17)))
                            .foregroundStyle(Color.ratingStar)
                    }
                }
                .accessibilityHidden(true)
                Text(card.title)
                    .font(.body(scale.type(19), weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(card.body)
                    .font(.body(scale.type(19)))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                // A card flagged `placeholder` in Content/onboarding.json has no real
                // reviewer behind it, so it gets no handle: the string in the file is the
                // literal "Placeholder review", which was reaching the screen, and
                // replacing it with an invented name would be worse. Inject real App
                // Store reviews and the line comes back on its own.
                if !card.placeholder, !card.author.isEmpty {
                    Text(card.author)
                        .font(.body(scale.type(16), weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.top, scale.height(Spacing.xs))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, scale.width(Spacing.lg))
            .padding(.vertical, scale.height(Spacing.lg))
        }
        .background(Color.cardBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: scale.width(OnboardingMetrics.cardCornerRadius), style: .continuous)
        )
        // `#FFFFFF` on `#FAFAFC`. See `Color.cardBorder`; no-op on dark.
        .cardEdge(radius: scale.width(OnboardingMetrics.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let head = "\(card.stars) out of 5 stars. \(card.title). \(card.body)"
        guard !card.placeholder, !card.author.isEmpty else { return head }
        return "\(head). \(card.author)"
    }
}
