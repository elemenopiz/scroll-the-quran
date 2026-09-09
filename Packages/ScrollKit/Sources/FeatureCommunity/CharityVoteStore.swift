import Foundation
import UserState

/// The Community tab's slice of user state: which organisation the user voted for, if any.
///
/// The same narrowing `UserState/StoreProtocols.swift` does for onboarding, the paywall and the
/// reader. It lives here rather than there because `UserState` is not this task's to edit;
/// `UserStore` picks up the conformance below for free, since it already has `setCharityVote`.
@MainActor
public protocol CharityVoteStore: AnyObject {
    /// The organisation id the user voted for, or nil when they have not voted.
    var charityVote: String? { get }
    func setCharityVote(_ organisationID: String?)
}

extension UserStore: CharityVoteStore {}

/// A store with nowhere to persist to: previews, `--screenshot` runs and tests that only care
/// about the in-session behaviour.
@MainActor
public final class InMemoryCharityVoteStore: CharityVoteStore {
    public private(set) var charityVote: String?

    public init(charityVote: String? = nil) {
        self.charityVote = charityVote
    }

    public func setCharityVote(_ organisationID: String?) {
        charityVote = organisationID
    }
}
