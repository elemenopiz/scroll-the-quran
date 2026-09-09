import Foundation
import Observation

/// Everything the Community tab needs to render and everything it can do: the catalog, the
/// current vote, and the one mutation — casting or clearing it.
///
/// The vote is *exclusive*: there is one `Prefs.charityVote`, so voting for a second
/// organisation moves the vote rather than adding one. Tapping the organisation you already
/// voted for clears the vote, which is the only way back to "no vote" without picking someone
/// else.
@MainActor
@Observable
public final class CommunityModel {
    public let catalog: CharityCatalog

    @ObservationIgnored private let store: any CharityVoteStore
    /// Mirrors `store.charityVote`. `UserStore` is `@Observable` too, but the protocol is not,
    /// so the model keeps its own observable copy and writes through on every change.
    public private(set) var vote: String?

    public init(catalog: CharityCatalog, store: any CharityVoteStore) {
        self.catalog = catalog
        self.store = store
        vote = store.charityVote
    }

    /// The app's model: the bundled catalog and the real `UserStore`.
    public convenience init(
        store: any CharityVoteStore,
        loader: some CharityContentLoading = BundledCharityContent()
    ) {
        self.init(catalog: .loadOrEmpty(from: loader), store: store)
    }

    public var organisations: [Charity] {
        catalog.organisations
    }

    /// True for the one organisation the user voted for.
    public func hasVoted(for organisation: Charity) -> Bool {
        vote == organisation.id
    }

    /// True once any vote has been cast, which is what dims the other cards' buttons.
    public var hasVoted: Bool {
        catalog.organisation(id: vote) != nil
    }

    /// Cast, move or clear the vote. Returns the vote after the change.
    @discardableResult
    public func toggleVote(for organisation: Charity) -> String? {
        let next = vote == organisation.id ? nil : organisation.id
        vote = next
        store.setCharityVote(next)
        return next
    }

    /// The label on an organisation's button.
    public func voteButtonTitle(for organisation: Charity) -> String {
        hasVoted(for: organisation) ? "Voted" : "Vote"
    }

    /// What VoiceOver reads, and what the button promises to do when activated.
    public func voteAccessibilityLabel(for organisation: Charity) -> String {
        hasVoted(for: organisation)
            ? "Voted for \(organisation.name). Activate to withdraw your vote."
            : "Vote for \(organisation.name)"
    }
}
