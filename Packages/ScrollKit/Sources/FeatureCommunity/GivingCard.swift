import DesignSystem
import SwiftUI

/// The green gradient card at the top of the Community tab: a caps label, the running total in
/// large serif figures, a short rule, and the promise underneath.
///
/// The amount is whatever `Content/charities.json` says, formatted whole — including **$0**.
/// Nothing here hides a zero or rounds it away: the app has given nothing yet and says so.
struct GivingCard: View {
    let headline: String
    let amount: String
    let subline: String

    var body: some View {
        VStack(spacing: 0) {
            Text(headline)
                .capsLabelStyle(size: CommunityMetrics.capsSize)
                .foregroundStyle(CommunityPalette.onGivingMuted)
                .accessibilityIdentifier("community.given.label")

            Text(amount)
                .font(.serifDisplay(CommunityMetrics.amountSize))
                .foregroundStyle(CommunityPalette.onGiving)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityIdentifier("community.given.amount")

            RoundedRectangle(cornerRadius: CommunityMetrics.givingDividerHeight / 2, style: .continuous)
                .fill(CommunityPalette.givingDivider)
                .frame(
                    width: CommunityMetrics.givingDividerWidth,
                    height: CommunityMetrics.givingDividerHeight
                )
                .padding(.vertical, Spacing.md)
                .accessibilityHidden(true)

            Text(subline)
                .font(.body(CommunityMetrics.sublineSize, weight: .bold))
                .foregroundStyle(CommunityPalette.onGivingMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(CommunityMetrics.sublineLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("community.given.subline")
        }
        .frame(maxWidth: .infinity)
        .padding(CommunityMetrics.givingCardPadding)
        .frame(minHeight: CommunityMetrics.givingCardHeight)
        .background(
            CommunityPalette.giving,
            in: .rect(cornerRadius: Radius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(amount) \(headline). \(subline)")
        .accessibilityIdentifier("community.givenCard")
    }
}

#Preview("Giving card dark") {
    GivingCardPreviews().preferredColorScheme(.dark)
}

#Preview("Giving card light") {
    GivingCardPreviews().preferredColorScheme(.light)
}

private struct GivingCardPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            GivingCard(
                headline: "Given to charities",
                amount: "$0",
                subline: "Every subscription gives a share back to the Ummah."
            )
            GivingCard(
                headline: "Given to charities",
                amount: "$59,185",
                subline: "Every subscription gives a share back to the Ummah."
            )
        }
        .padding(CommunityMetrics.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
    }
}
