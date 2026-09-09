import Foundation

/// Where the paywall's Terms and Privacy links go. Injected rather than hard-coded in the
/// view so the composition root owns the real URLs, and so App Review's requirement for
/// live links (guideline 3.1.2(a)) is satisfied by construction.
public struct PaywallLegalLinks: Sendable, Equatable {
    public let terms: URL
    public let privacy: URL

    public init(terms: URL, privacy: URL) {
        self.terms = terms
        self.privacy = privacy
    }

    public static let `default` = PaywallLegalLinks(
        terms: URL(string: "https://scrollthequran.app/terms")!,
        privacy: URL(string: "https://scrollthequran.app/privacy")!
    )
}
