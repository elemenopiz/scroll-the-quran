@testable import FeatureCommunity
import Foundation
import Testing
import UserState

@MainActor
@Suite("Charity vote")
struct CommunityModelTests {
    private let relief = Charity.fixture(id: "islamic-relief", image: "giving-hands")
    private let penny = Charity.fixture(id: "penny-appeal", image: "clean-water")

    private func model(vote: String? = nil) -> CommunityModel {
        CommunityModel(
            catalog: .fixture(organisations: [relief, penny]),
            store: InMemoryCharityVoteStore(charityVote: vote)
        )
    }

    @Test("starts with no vote and both buttons reading Vote")
    func startsUnvoted() {
        let model = model()
        #expect(model.vote == nil)
        #expect(!model.hasVoted)
        #expect(model.voteButtonTitle(for: relief) == "Vote")
        #expect(model.voteButtonTitle(for: penny) == "Vote")
    }

    @Test("voting marks that organisation and only that one")
    func voting() {
        let model = model()
        model.toggleVote(for: relief)
        #expect(model.vote == "islamic-relief")
        #expect(model.hasVoted)
        #expect(model.hasVoted(for: relief))
        #expect(!model.hasVoted(for: penny))
        #expect(model.voteButtonTitle(for: relief) == "Voted")
        #expect(model.voteButtonTitle(for: penny) == "Vote")
    }

    @Test("the vote is exclusive: voting again moves it rather than adding one")
    func votingIsExclusive() {
        let model = model()
        model.toggleVote(for: relief)
        model.toggleVote(for: penny)
        #expect(model.vote == "penny-appeal")
        #expect(!model.hasVoted(for: relief))
        #expect(model.hasVoted(for: penny))
    }

    @Test("tapping the organisation you voted for withdraws the vote")
    func togglingOffClears() {
        let model = model()
        #expect(model.toggleVote(for: relief) == "islamic-relief")
        #expect(model.toggleVote(for: relief) == nil)
        #expect(model.vote == nil)
        #expect(!model.hasVoted)
    }

    @Test("an existing vote is read back out of the store on init")
    func restoresExistingVote() {
        let model = model(vote: "penny-appeal")
        #expect(model.hasVoted(for: penny))
        #expect(model.voteButtonTitle(for: penny) == "Voted")
    }

    @Test("a stored vote for an organisation that has left the catalog counts as no vote")
    func staleVote() {
        let model = CommunityModel(
            catalog: .fixture(organisations: [relief]),
            store: InMemoryCharityVoteStore(charityVote: "gone-away")
        )
        #expect(!model.hasVoted)
        #expect(!model.hasVoted(for: relief))
    }

    @Test("every change is written through to the store, not just held in the model")
    func writesThrough() {
        let store = InMemoryCharityVoteStore()
        let model = CommunityModel(catalog: .fixture(organisations: [relief, penny]), store: store)
        model.toggleVote(for: relief)
        #expect(store.charityVote == "islamic-relief")
        model.toggleVote(for: penny)
        #expect(store.charityVote == "penny-appeal")
        model.toggleVote(for: penny)
        #expect(store.charityVote == nil)
    }

    @Test("VoiceOver says what the button will do, not just its title")
    func accessibilityLabels() {
        let model = model()
        #expect(model.voteAccessibilityLabel(for: relief) == "Vote for Islamic-Relief")
        model.toggleVote(for: relief)
        #expect(model.voteAccessibilityLabel(for: relief).hasPrefix("Voted for Islamic-Relief"))
        #expect(model.voteAccessibilityLabel(for: relief).contains("withdraw"))
    }
}

@MainActor
@Suite("Vote persistence")
struct CharityVotePersistenceTests {
    /// The DoD's "vote persists across relaunch", at the layer that owns the file: vote through
    /// the model, flush, then build a **new** `UserStore` over the same directory — which is what
    /// a cold launch does — and read it back.
    @Test("a vote survives a relaunch")
    func voteSurvivesRelaunch() throws {
        let directory = TemporaryDirectory()
        let charity = Charity.fixture(id: "human-appeal", image: "harvest-wheat")
        let catalog = CharityCatalog.fixture(organisations: [charity])

        let first = try UserStore(directory: directory.url)
        first.load()
        let model = CommunityModel(catalog: catalog, store: first)
        #expect(model.vote == nil)
        model.toggleVote(for: charity)
        first.save()

        let relaunched = try UserStore(directory: directory.url)
        relaunched.load()
        #expect(relaunched.prefs.charityVote == "human-appeal")

        let restored = CommunityModel(catalog: catalog, store: relaunched)
        #expect(restored.hasVoted(for: charity))
        #expect(restored.voteButtonTitle(for: charity) == "Voted")
    }

    @Test("withdrawing a vote survives a relaunch too")
    func withdrawalSurvivesRelaunch() throws {
        let directory = TemporaryDirectory()
        let charity = Charity.fixture(id: "penny-appeal", image: "clean-water")
        let catalog = CharityCatalog.fixture(organisations: [charity])

        let first = try UserStore(directory: directory.url)
        first.load()
        let model = CommunityModel(catalog: catalog, store: first)
        model.toggleVote(for: charity)
        model.toggleVote(for: charity)
        first.save()

        let relaunched = try UserStore(directory: directory.url)
        relaunched.load()
        #expect(relaunched.prefs.charityVote == nil)
    }

    @Test("UserStore is the vote store, so nothing has to be mirrored by hand")
    func userStoreConforms() throws {
        let directory = TemporaryDirectory()
        let store: any CharityVoteStore = try UserStore(directory: directory.url)
        store.setCharityVote("islamic-relief")
        #expect(store.charityVote == "islamic-relief")
    }
}
