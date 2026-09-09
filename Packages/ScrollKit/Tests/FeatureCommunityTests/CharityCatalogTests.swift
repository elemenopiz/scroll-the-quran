@testable import FeatureCommunity
import Foundation
import Testing

@Suite("Bundled Content/charities.json")
struct BundledCharityCatalogTests {
    @Test("decodes, and the running total is still an honest zero")
    func decodesWithZeroTotal() throws {
        let catalog = try loadBundledCatalog()
        #expect(catalog.givenTotalUSD == 0)
        #expect(catalog.currency == "USD")
        #expect(catalog.formattedTotal == "$0")
    }

    @Test("carries the copy the Community tab renders")
    func carriesCopy() throws {
        let catalog = try loadBundledCatalog()
        #expect(!catalog.headline.isEmpty)
        #expect(!catalog.subline.isEmpty)
        #expect(catalog.voteTitle == "Vote Who We Give To")
        #expect(catalog.voteBody.contains("one vote"))
    }

    @Test("every organisation is complete and maps to bundled artwork")
    func organisationsAreComplete() throws {
        let catalog = try loadBundledCatalog()
        #expect(catalog.organisations.count == 3)
        for organisation in catalog.organisations {
            #expect(!organisation.name.isEmpty, "\(organisation.id) has no name")
            #expect(!organisation.focus.isEmpty, "\(organisation.id) has no focus")
            #expect(!organisation.blurb.isEmpty, "\(organisation.id) has no blurb")
            #expect(organisation.url != nil, "\(organisation.id) has no url")
            #expect(
                CharityArtwork.slugs.contains(organisation.image),
                "\(organisation.id) image slug '\(organisation.image)' is not in the asset catalog"
            )
            #expect(organisation.artworkName == "Charity-\(organisation.image)")
        }
    }

    @Test("organisation ids are unique, so one vote can only match one card")
    func idsAreUnique() throws {
        let ids = try loadBundledCatalog().organisations.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("a vote for a removed organisation matches nothing")
    func lookupByID() throws {
        let catalog = try loadBundledCatalog()
        #expect(catalog.organisation(id: "islamic-relief")?.name == "Islamic Relief Worldwide")
        #expect(catalog.organisation(id: "not-in-the-catalog") == nil)
        #expect(catalog.organisation(id: nil) == nil)
    }
}

@Suite("Catalog decoding")
struct CharityCatalogDecodingTests {
    @Test("a pre-v2 file that spelled the total totalGivenUSD still decodes")
    func legacyTotalKey() throws {
        let loader = InMemoryCharityContent(json: """
        { "totalGivenUSD": 1200, "organisations": [] }
        """)
        let catalog = try CharityCatalog.load(from: loader)
        #expect(catalog.givenTotalUSD == 1200)
        #expect(catalog.formattedTotal == "$1,200")
    }

    @Test("missing copy falls back to the defaults instead of rendering blanks")
    func defaultsForMissingCopy() throws {
        let loader = InMemoryCharityContent(json: #"{ "organisations": [] }"#)
        let catalog = try CharityCatalog.load(from: loader)
        #expect(catalog.givenTotalUSD == 0)
        #expect(catalog.voteTitle == CharityCatalog.defaultVoteTitle)
        #expect(catalog.subline == CharityCatalog.defaultSubline)
    }

    @Test("a negative total is clamped: the card never shows money owed")
    func negativeTotalClamped() throws {
        let loader = InMemoryCharityContent(json: #"{ "givenTotalUSD": -50, "organisations": [] }"#)
        #expect(try CharityCatalog.load(from: loader).formattedTotal == "$0")
    }

    @Test("an organisation with no image slug falls back to its id")
    func imageFallsBackToID() throws {
        let loader = InMemoryCharityContent(json: """
        { "organisations": [
            { "id": "penny-appeal", "name": "Penny Appeal", "blurb": "b", "focus": "f" }
        ] }
        """)
        let organisation = try #require(try CharityCatalog.load(from: loader).organisations.first)
        #expect(organisation.image == "penny-appeal")
        #expect(organisation.artworkName == "Charity-clean-water")
    }

    @Test("an unknown organisation gets no artwork rather than a broken image name")
    func unknownArtwork() {
        #expect(Charity.fixture(id: "made-up").artworkName == nil)
        #expect(CharityArtwork.assetName(forSlug: "giving-hands") == "Charity-giving-hands")
    }

    @Test("the total is formatted whole, grouped and locale-independent")
    func formatting() {
        #expect(CharityCatalog.fixture(givenTotalUSD: 0, organisations: []).formattedTotal == "$0")
        #expect(CharityCatalog.fixture(givenTotalUSD: 7, organisations: []).formattedTotal == "$7")
        #expect(CharityCatalog.fixture(givenTotalUSD: 59185, organisations: []).formattedTotal == "$59,185")
    }

    @Test("malformed JSON is reported against the file, not as a bare decoding error")
    func malformed() {
        let loader = InMemoryCharityContent(json: "{ not json")
        #expect(throws: CharityContentError.self) {
            try CharityCatalog.load(from: loader)
        }
    }

    @Test("a missing file is reported with the roots that were searched")
    func missing() {
        let loader = BundledCharityContent(roots: [URL(fileURLWithPath: "/nowhere")])
        #expect(throws: CharityContentError.self) {
            try CharityCatalog.load(from: loader)
        }
        #expect(CharityCatalog.loadOrEmpty(from: loader).organisations.isEmpty)
    }

    @Test("the catalog round-trips through Codable")
    func roundTrip() throws {
        let original = try loadBundledCatalog()
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(CharityCatalog.self, from: data) == original)
    }
}

@Suite("Legacy alias")
struct CharityTotalAliasTests {
    /// `Content/charities.json` carries the total twice: `givenTotalUSD` (what this feature
    /// reads) and `totalGivenUSD` (the Phase-1 spelling that `StudyContentTests` still decodes).
    /// They must stay equal; drop the alias once that test is updated.
    @Test("givenTotalUSD and the retained totalGivenUSD alias agree")
    func aliasMatches() throws {
        let data = try bundledContent.data(at: CharityCatalog.contentPath)
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modern = try #require(raw["givenTotalUSD"] as? Int)
        let legacy = try #require(raw["totalGivenUSD"] as? Int)
        #expect(modern == legacy)
        #expect(try loadBundledCatalog().givenTotalUSD == modern)
    }
}
