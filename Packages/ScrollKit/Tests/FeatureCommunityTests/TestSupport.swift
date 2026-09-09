@testable import FeatureCommunity
import Foundation

/// Repo root, walked up from this file: Tests/FeatureCommunityTests -> Tests -> ScrollKit -> Packages -> root.
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

/// The repo's real `Content/` folder — the same file the app bundles.
let bundledContent = BundledCharityContent(roots: [repoRoot.appendingPathComponent("Content")])

/// The catalog the app actually ships. Every assertion about it is an assertion about
/// `Content/charities.json`.
func loadBundledCatalog() throws -> CharityCatalog {
    try CharityCatalog.load(from: bundledContent)
}

/// A scratch directory that cleans itself up, for the `UserStore` round trip.
final class TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FeatureCommunityTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

extension Charity {
    static func fixture(id: String, name: String? = nil, image: String? = nil) -> Charity {
        Charity(
            id: id,
            name: name ?? id.capitalized,
            blurb: "Blurb for \(id).",
            focus: "Focus for \(id)",
            founded: 2000,
            image: image,
            url: URL(string: "https://example.org/\(id)")
        )
    }
}

extension CharityCatalog {
    static func fixture(givenTotalUSD: Int = 0, organisations: [Charity]) -> CharityCatalog {
        CharityCatalog(
            givenTotalUSD: givenTotalUSD,
            headline: defaultHeadline,
            subline: defaultSubline,
            voteTitle: defaultVoteTitle,
            voteBody: defaultVoteBody,
            organisations: organisations
        )
    }
}
