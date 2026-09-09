import Foundation

/// One organisation on the Community tab, straight out of `Content/charities.json`.
///
/// `image` is the artwork slug (`giving-hands`), not a file name; `artworkName` turns it into
/// the asset-catalog name the app bundle ships (`Charity-giving-hands`). Nothing here carries a
/// real logo — the imagery is abstract, per `Artwork/README.md`.
public struct Charity: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// The long description under the divider.
    public let blurb: String
    /// The one-line tagline next to the name.
    public let focus: String
    public let founded: Int?
    /// Artwork slug. Falls back to the organisation id when the field is absent.
    public let image: String
    public let url: URL?

    public init(
        id: String,
        name: String,
        blurb: String,
        focus: String,
        founded: Int? = nil,
        image: String? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.focus = focus
        self.founded = founded
        self.image = image ?? id
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, blurb, focus, founded, image, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        try self.init(
            id: id,
            name: container.decode(String.self, forKey: .name),
            blurb: container.decode(String.self, forKey: .blurb),
            focus: container.decode(String.self, forKey: .focus),
            founded: container.decodeIfPresent(Int.self, forKey: .founded),
            image: container.decodeIfPresent(String.self, forKey: .image),
            url: container.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(blurb, forKey: .blurb)
        try container.encode(focus, forKey: .focus)
        try container.encodeIfPresent(founded, forKey: .founded)
        try container.encode(image, forKey: .image)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
    }
}

/// The whole `Content/charities.json` document: the running total, the copy around it, and the
/// organisations that can be voted for.
public struct CharityCatalog: Hashable, Codable, Sendable {
    /// Money actually given, in whole `currency` units. Starts at **zero** and is rendered as
    /// "$0" rather than hidden — the app makes no claim until money has been given.
    public let givenTotalUSD: Int
    public let currency: String
    /// The caps label above the amount. Rendered uppercase by `CapsLabel`.
    public let headline: String
    /// The line under the divider inside the green card.
    public let subline: String
    /// The serif section title under the card.
    public let voteTitle: String
    /// The body copy under the title.
    public let voteBody: String
    public let organisations: [Charity]

    public init(
        givenTotalUSD: Int,
        currency: String = "USD",
        headline: String,
        subline: String,
        voteTitle: String,
        voteBody: String,
        organisations: [Charity]
    ) {
        self.givenTotalUSD = givenTotalUSD
        self.currency = currency
        self.headline = headline
        self.subline = subline
        self.voteTitle = voteTitle
        self.voteBody = voteBody
        self.organisations = organisations
    }

    private enum CodingKeys: String, CodingKey {
        case givenTotalUSD, totalGivenUSD, currency, headline, subline, voteTitle, voteBody, organisations
    }

    /// Every key is optional-with-a-default so a `charities.json` written by an older build (which
    /// spelled the total `totalGivenUSD` and carried no copy) still decodes.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let total = try container.decodeIfPresent(Int.self, forKey: .givenTotalUSD)
            ?? container.decodeIfPresent(Int.self, forKey: .totalGivenUSD)
            ?? 0
        try self.init(
            givenTotalUSD: max(0, total),
            currency: container.decodeIfPresent(String.self, forKey: .currency) ?? "USD",
            headline: container.decodeIfPresent(String.self, forKey: .headline) ?? Self.defaultHeadline,
            subline: container.decodeIfPresent(String.self, forKey: .subline) ?? Self.defaultSubline,
            voteTitle: container.decodeIfPresent(String.self, forKey: .voteTitle) ?? Self.defaultVoteTitle,
            voteBody: container.decodeIfPresent(String.self, forKey: .voteBody) ?? Self.defaultVoteBody,
            organisations: container.decodeIfPresent([Charity].self, forKey: .organisations) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(givenTotalUSD, forKey: .givenTotalUSD)
        try container.encode(currency, forKey: .currency)
        try container.encode(headline, forKey: .headline)
        try container.encode(subline, forKey: .subline)
        try container.encode(voteTitle, forKey: .voteTitle)
        try container.encode(voteBody, forKey: .voteBody)
        try container.encode(organisations, forKey: .organisations)
    }

    static let defaultHeadline = "Given to charities"
    static let defaultSubline = "Every subscription gives a share back to the Ummah."
    static let defaultVoteTitle = "Vote Who We Give To"
    static let defaultVoteBody = """
    A portion of all proceeds across the entire app goes to one of these charities each month. \
    Subscribers get one vote to choose who receives it.
    """

    /// The amount as the card shows it: whole units, grouped, no cents — "$0", "$59,185".
    ///
    /// The locale is pinned to `en_US` so a snapshot taken on a French simulator still reads
    /// "$0" with the grouping the reference shows; the currency code itself comes from the JSON.
    public var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: givenTotalUSD)) ?? "\(givenTotalUSD)"
    }

    /// The organisation with this id, if it is still in the catalog. A vote for an organisation
    /// that has since been removed simply stops matching anything.
    public func organisation(id: String?) -> Charity? {
        guard let id else { return nil }
        return organisations.first { $0.id == id }
    }
}

// MARK: - Artwork

/// Charity id (or artwork slug) → asset-catalog name.
///
/// A private copy of the table in `AppShell/ArtworkAssets.swift`: `FeatureCommunity` must not
/// depend on the composition root. `charities.json` now carries an explicit `image` slug, so the
/// mapping lives in the data and this table is only the fallback for an id with no slug.
public enum CharityArtwork {
    /// Prefix every charity image in `App/Assets.xcassets` shares.
    public static let prefix = "Charity-"
    /// The dark overlay composited over a charity image so white titles read.
    public static let scrimName = "CharityCardScrim"

    /// Artwork slugs shipped in the catalog, in catalog order.
    public static let slugs = ["giving-hands", "harvest-wheat", "clean-water"]

    /// Fallback for a `charities.json` entry with no `image` field.
    static let slugByOrganisationID = [
        "islamic-relief": "giving-hands",
        "penny-appeal": "clean-water",
        "human-appeal": "harvest-wheat",
    ]

    /// The asset-catalog name for a charity, or nil when neither the slug nor the id is known.
    /// Unknown slugs return nil rather than a broken `Image`, so the card can fall back to a
    /// plain tinted panel instead of an empty box.
    public static func assetName(forSlug slug: String) -> String? {
        if slugs.contains(slug) {
            return prefix + slug
        }
        if let mapped = slugByOrganisationID[slug] {
            return prefix + mapped
        }
        return nil
    }
}

public extension Charity {
    /// `Charity-giving-hands`, resolved through `image` first and the id second. Nil when the
    /// catalog ships no artwork for this organisation.
    var artworkName: String? {
        CharityArtwork.assetName(forSlug: image) ?? CharityArtwork.assetName(forSlug: id)
    }
}
