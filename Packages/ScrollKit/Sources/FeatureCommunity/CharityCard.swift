import DesignSystem
import SwiftUI

/// One organisation: the abstract card image under its scrim, the name and focus with the vote
/// button beside them, a divider, the description, and a link out to the organisation's own site.
struct CharityCard: View {
    let charity: Charity
    let isVoted: Bool
    let voteTitle: String
    let voteAccessibilityLabel: String
    let onVote: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            artwork
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .overlay(Color.divider)
                    .padding(.vertical, CommunityMetrics.charityDividerGap)
                Text(charity.blurb)
                    .font(.body(CommunityMetrics.charityBlurbSize))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(CommunityMetrics.charityBlurbLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("community.blurb.\(charity.id)")
                if let url = charity.url {
                    learnMore(url)
                }
            }
            .padding(CommunityMetrics.charityCardPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("community.card.\(charity.id)")
    }

    // MARK: Pieces

    /// The 1200x600 abstract artwork, cropped to the measured 160 pt band, with
    /// `CharityCardScrim` composited over it so the card reads as one dark surface. Both live in
    /// the **app**'s asset catalog, so previews inside the package show the fallback panel.
    private var artwork: some View {
        Rectangle()
            .fill(Color.rowBackground)
            .frame(height: CommunityMetrics.charityImageHeight)
            .overlay {
                if let name = charity.artworkName {
                    Image(name, bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                Image(CharityArtwork.scrimName, bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: CommunityMetrics.charityTitleSpacing) {
                Text(charity.name)
                    .font(.body(CommunityMetrics.charityNameSize, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityIdentifier("community.name.\(charity.id)")
                Text(charity.focus)
                    .font(.body(CommunityMetrics.charityFocusSize))
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("community.focus.\(charity.id)")
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.sm)
            voteButton
        }
    }

    private var voteButton: some View {
        Button(action: onVote) {
            HStack(spacing: Spacing.xs) {
                if isVoted {
                    Image(systemName: "checkmark")
                        .font(.body(CommunityMetrics.voteLabelSize, weight: .bold))
                }
                Text(voteTitle)
                    .font(.body(CommunityMetrics.voteLabelSize, weight: .semibold))
            }
            .foregroundStyle(CommunityPalette.voteLabel)
            .padding(.horizontal, Spacing.lg)
            .frame(minWidth: CommunityMetrics.voteButtonWidth)
            .frame(height: CommunityMetrics.voteButtonHeight)
            .background(CommunityPalette.voteFill, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(voteAccessibilityLabel)
        .accessibilityAddTraits(isVoted ? [.isSelected] : [])
        .accessibilityIdentifier("community.vote.\(charity.id)")
    }

    private func learnMore(_ url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("Learn more")
                Image(systemName: "arrow.up.right")
                    .font(.body(CommunityMetrics.charityBlurbSize - 2, weight: .semibold))
            }
            .font(.body(CommunityMetrics.charityBlurbSize, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .padding(.top, Spacing.md)
        .accessibilityLabel("Learn more about \(charity.name)")
        .accessibilityHint(url.host() ?? url.absoluteString)
        .accessibilityIdentifier("community.learnMore.\(charity.id)")
    }
}

#Preview("Charity card dark") {
    CharityCardPreviews().preferredColorScheme(.dark)
}

#Preview("Charity card light") {
    CharityCardPreviews().preferredColorScheme(.light)
}

private struct CharityCardPreviews: View {
    @State private var voted = false

    private let charity = Charity(
        id: "islamic-relief",
        name: "Islamic Relief Worldwide",
        blurb: "Emergency response and long-term development in more than 40 countries, "
            + "working through local offices rather than parachuting in.",
        focus: "Emergency relief and development",
        founded: 1984,
        image: "giving-hands",
        url: URL(string: "https://islamic-relief.org")
    )

    var body: some View {
        ScrollView {
            CharityCard(
                charity: charity,
                isVoted: voted,
                voteTitle: voted ? "Voted" : "Vote",
                voteAccessibilityLabel: "Vote for \(charity.name)"
            ) {
                voted.toggle()
            }
            .padding(CommunityMetrics.pageMargin)
        }
        .background(Color.appBackground)
    }
}
