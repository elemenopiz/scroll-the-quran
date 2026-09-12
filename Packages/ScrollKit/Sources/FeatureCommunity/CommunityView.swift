import DesignSystem
import SwiftUI

/// The Community tab: what the app has given away so far, and the vote that decides where next
/// month's share goes.
///
/// Modelled on `Reference/community-dark.png`; every number in `CommunityMetrics` names the scan
/// line it came from. The light appearance is derived — the surfaces and type come from
/// `Tokens`, which already flips, and the green card and vote pill are brand colours that stay
/// put in both.
public struct CommunityView: View {
    @State private var model: CommunityModel
    /// Audit A11Y-4: casting a vote re-flows the whole card list, and this was the one
    /// animation in Community that did not check.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The app's entry point: the bundled catalog, the real vote store.
    public init(store: any CharityVoteStore) {
        _model = State(initialValue: CommunityModel(store: store))
    }

    /// Previews, `--screenshot` runs and tests hand in a model they already own.
    public init(model: CommunityModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GivingCard(
                    headline: model.catalog.headline,
                    amount: model.catalog.formattedTotal,
                    subline: model.catalog.subline
                )

                Text(model.catalog.voteTitle)
                    .font(.serifDisplay(CommunityMetrics.titleSize))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CommunityMetrics.titleTopGap)
                    .accessibilityIdentifier("community.title")
                    .accessibilityAddTraits(.isHeader)

                Text(model.catalog.voteBody)
                    .font(.body(CommunityMetrics.bodySize))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(CommunityMetrics.bodyLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CommunityMetrics.bodyTopGap)
                    .accessibilityIdentifier("community.body")

                LazyVStack(spacing: CommunityMetrics.cardSpacing) {
                    ForEach(model.organisations) { charity in
                        CharityCard(
                            charity: charity,
                            isVoted: model.hasVoted(for: charity),
                            voteTitle: model.voteButtonTitle(for: charity),
                            voteAccessibilityLabel: model.voteAccessibilityLabel(for: charity)
                        ) {
                            model.toggleVote(for: charity)
                        }
                    }
                }
                .padding(.top, CommunityMetrics.cardsTopGap)
            }
            .padding(.horizontal, CommunityMetrics.pageMargin)
            .padding(.top, CommunityMetrics.scrollTopInset)
            .padding(.bottom, Spacing.huge)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: model.vote)
        .accessibilityIdentifier("screen.community")
    }
}

#Preview("Community dark") {
    CommunityView(model: .preview).preferredColorScheme(.dark)
}

#Preview("Community light") {
    CommunityView(model: .preview).preferredColorScheme(.light)
}

public extension CommunityModel {
    /// A model over the bundled catalog with nothing persisted — previews and `--screenshot`.
    @MainActor
    static var preview: CommunityModel {
        CommunityModel(catalog: .loadOrEmpty(), store: InMemoryCharityVoteStore())
    }
}
