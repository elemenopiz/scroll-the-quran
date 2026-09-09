import SwiftUI

/// The five-star rating row (`#FFC733`, measured on onboarding-reviews). Half stars
/// are rendered where the rating lands mid-star, matching the App Store summary row.
public struct StarRow: View {
    private let rating: Double
    private let size: CGFloat
    private let spacing: CGFloat

    public init(rating: Double, size: CGFloat = 18, spacing: CGFloat = Spacing.xs) {
        self.rating = rating
        self.size = size
        self.spacing = spacing
    }

    /// One symbol name per star. Extracted so it can be tested without a renderer.
    static func symbols(for rating: Double, count: Int = 5) -> [String] {
        let clamped = rating.isFinite ? min(max(rating, 0), Double(count)) : 0
        return (0 ..< count).map { index in
            let remaining = clamped - Double(index)
            if remaining >= 0.75 {
                return "star.fill"
            }
            if remaining >= 0.25 {
                return "star.leadinghalf.filled"
            }
            return "star"
        }
    }

    public var body: some View {
        let symbols = StarRow.symbols(for: rating)
        return HStack(spacing: spacing) {
            ForEach(symbols.indices, id: \.self) { index in
                Image(systemName: symbols[index])
                    .font(.system(size: size))
                    .foregroundStyle(Color.ratingStar)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(0 ... 1)))) out of 5")
    }
}

#Preview("StarRow light") {
    StarRowPreviews().preferredColorScheme(.light)
}

#Preview("StarRow dark") {
    StarRowPreviews().preferredColorScheme(.dark)
}

private struct StarRowPreviews: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach([5.0, 4.8, 4.5, 3.0, 0.0], id: \.self) { rating in
                HStack(spacing: Spacing.md) {
                    Text(rating.formatted(.number.precision(.fractionLength(1))))
                        .font(.body(15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 40, alignment: .leading)
                    StarRow(rating: rating)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appBackground)
    }
}
