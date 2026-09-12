@testable import FeatureOnboarding
import Foundation
import Testing

/// The funnel slides draw bundled captures of our own screens. A missing or blank one is
/// invisible at runtime — the phone frame renders its own ground and the slide reads as a
/// switched-off phone — so it is asserted here instead.
@Suite("Slide mockups")
struct MockupArtTests {
    @Test("Every slide mockup resolves to a bundled PNG", arguments: OnboardingContent.Mockup.allCases)
    func mockupResolves(mockup: OnboardingContent.Mockup) throws {
        let url = try #require(
            mockup.resourceURL,
            "\(mockup.resourceName).png is not in Bundle.module — re-run Tools/snapshot/render-mockups.sh"
        )
        let bytes = try Data(contentsOf: url)
        // A PNG header, and big enough to be a screen rather than a 1x1 placeholder.
        #expect(bytes.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        #expect(bytes.count > 50_000, "\(mockup.resourceName).png is only \(bytes.count) bytes")
    }

    @Test("The four mockups are four different captures")
    func mockupsAreDistinct() throws {
        var seen: Set<Int> = []
        for mockup in OnboardingContent.Mockup.allCases {
            let url = try #require(mockup.resourceURL)
            let hash = try Data(contentsOf: url).hashValue
            #expect(seen.insert(hash).inserted, "\(mockup.resourceName).png duplicates another mockup")
        }
    }

    @Test("Each mockup decodes to an image")
    func mockupDecodes() {
        for mockup in OnboardingContent.Mockup.allCases {
            #expect(mockup.image != nil, "\(mockup.resourceName) did not decode")
        }
    }
}
