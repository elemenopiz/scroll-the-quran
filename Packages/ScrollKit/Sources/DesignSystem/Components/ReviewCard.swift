import SwiftUI

/// An App Store review quoted on the onboarding reviews slide: white card, a 3 pt
/// (9 px) `Color.ratingStar` bar down the leading edge, stars, headline, body and
/// the reviewer's handle.
public struct ReviewCard: View {
    private let rating: Double
    private let title: String
    private let quote: String
    private let author: String

    public init(rating: Double = 5, title: String, quote: String, author: String) {
        self.rating = rating
        self.title = title
        self.quote = quote
        self.author = author
    }

    public var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.ratingStar)
                .frame(width: Metrics.accentBarWidth)
            VStack(alignment: .leading, spacing: Spacing.md) {
                StarRow(rating: rating, size: 17)
                Text(title)
                    .font(.body(19, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(quote)
                    .font(.body(17))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(author)
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.xl)
        }
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Radius.cardSmall, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("ReviewCard light") {
    ReviewCardPreviews().preferredColorScheme(.light)
}

#Preview("ReviewCard dark") {
    ReviewCardPreviews().preferredColorScheme(.dark)
}

private struct ReviewCardPreviews: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                ReviewCard(
                    title: "Game Changer",
                    quote: "I cannot praise this app enough. It turned scrolling into "
                        + "something that grounds me instead of draining me.",
                    author: "MellowViolence"
                )
                ReviewCard(
                    rating: 4.5,
                    title: "Best App Ever!",
                    quote: "Reading the Quran always felt overwhelming. One ayah a page "
                        + "changed that completely.",
                    author: "QuietReader"
                )
            }
            .padding(Spacing.xxl)
        }
        .background(Color.appBackground)
    }
}
