@testable import AppShell
import Foundation
import Testing

/// `ArtworkAsset` names images by string, and the asset catalog lives in the **app** target, so
/// nothing in the compiler checks that a case still resolves to a file. A renamed or dropped
/// imageset shows up as an empty rectangle on a device and nowhere else — these tests read the
/// catalog off disk instead.
@Suite("Artwork catalog")
struct ArtworkCatalogTests {
    /// `App/Assets.xcassets`, found by walking up from this file.
    static let catalogDirectory: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url.appending(components: "App", "Assets.xcassets")
            if FileManager.default.fileExists(atPath: candidate.appending(component: "Contents.json").path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: "App/Assets.xcassets", isDirectory: true)
    }()

    /// The file an imageset's `Contents.json` names, or nil when the imageset is missing.
    private func imageFile(_ name: String) throws -> URL? {
        let directory = Self.catalogDirectory.appending(component: "\(name).imageset")
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
        let contents = try JSONDecoder().decode(
            ImagesetContents.self,
            from: Data(contentsOf: directory.appending(component: "Contents.json"))
        )
        guard let filename = contents.images.compactMap(\.filename).first else { return nil }
        return directory.appending(component: filename)
    }

    /// Every `<name>.imageset` directory in the catalog.
    private func imagesets(prefix: String) throws -> Set<String> {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.catalogDirectory.path)
        return Set(
            names
                .filter { $0.hasSuffix(".imageset") && $0.hasPrefix(prefix) }
                .map { String($0.dropLast(".imageset".count)) }
        )
    }

    @Test("every ArtworkAsset case resolves to an imageset with a file on disk")
    func everyCaseHasAnImage() throws {
        for asset in ArtworkAsset.allCases {
            let file = try #require(try imageFile(asset.name), "'\(asset.name)' has no imageset")
            #expect(
                FileManager.default.fileExists(atPath: file.path),
                "\(asset.name) names '\(file.lastPathComponent)', which is not in the imageset"
            )
        }
    }

    @Test("every PlanCover-* and Charity-* imageset in the catalog has an ArtworkAsset case")
    func catalogHasNoOrphanImagesets() throws {
        let declared = Set(ArtworkAsset.allCases.map(\.name))
        for prefix in ["PlanCover-", "Charity-"] {
            for name in try imagesets(prefix: prefix) {
                #expect(declared.contains(name), "'\(name)' ships in the catalog but no case names it")
            }
        }
    }

    @Test("the covers are the eighteen PlanCover-* imagesets, and the cards the three Charity-*")
    func arraysMatchTheCatalog() throws {
        #expect(Set(ArtworkAsset.planCovers.map(\.name)) == (try imagesets(prefix: "PlanCover-")))
        #expect(ArtworkAsset.planCovers.count == 18)
        #expect(Set(ArtworkAsset.charityImages.map(\.name)) == (try imagesets(prefix: "Charity-")))
        #expect(ArtworkAsset.charityImages.count == 3)
        // The arrays are the covers, not the scrims: `PlanCoverScrim` is its own case.
        #expect(!ArtworkAsset.planCovers.contains(.planCoverScrim))
        #expect(!ArtworkAsset.charityImages.contains(.charityCardScrim))
    }

    @Test("covers and cards ship as JPEG under the 350 KB budget")
    func coversAreSmallJPEGs() throws {
        for asset in ArtworkAsset.planCovers + ArtworkAsset.charityImages {
            let file = try #require(try imageFile(asset.name))
            #expect(file.pathExtension == "jpg", "\(asset.name) ships \(file.lastPathComponent)")
            let bytes = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int ?? 0
            #expect(bytes <= 350 * 1024, "\(file.lastPathComponent) is \(bytes / 1024) KB")
        }
    }

    @Test("every slug either table maps is a cover that exists")
    func slugTablesPointAtRealArt() {
        for (slug, cover) in ArtworkAsset.planCoverBySlug {
            #expect(ArtworkAsset.planCovers.contains(cover), "'\(slug)' maps to \(cover.name)")
        }
        for (slug, card) in ArtworkAsset.charityImageBySlug {
            #expect(ArtworkAsset.charityImages.contains(card), "'\(slug)' maps to \(card.name)")
        }
        // Every cover is reachable by its own artwork slug, spares included.
        for cover in ArtworkAsset.planCovers {
            let slug = String(cover.rawValue.dropFirst("PlanCover-".count))
            #expect(ArtworkAsset.planCoverBySlug[slug] == cover)
        }
    }

    // MARK: The shape of an imageset's Contents.json

    private struct ImagesetContents: Decodable {
        struct Entry: Decodable {
            let filename: String?
        }

        let images: [Entry]
    }
}
