@testable import FeatureOnboarding
import Foundation
import Testing

@Suite("Onboarding content")
struct OnboardingContentTests {
    /// `Content/onboarding.json` as it ships. Host tests have no app bundle, so the
    /// file is read out of the repository next to this test.
    static func repoContent() throws -> OnboardingContent {
        try OnboardingContent.load(contentsOf: repoContentURL)
    }

    static var repoContentURL: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 {
            root.deleteLastPathComponent()
        }
        return root.appendingPathComponent("Content/onboarding.json")
    }

    @Test("The shipped JSON decodes")
    func decodesShippedFile() throws {
        let content = try Self.repoContent()
        #expect(content.version >= 2)
        #expect(content.slides.count == 4)
        #expect(content.reviews.cards.count == 3)
    }

    @Test("The shipped copy matches the sample used by previews and snapshots")
    func sampleMatchesShippedCopy() throws {
        let content = try Self.repoContent()
        #expect(content.hook.headline == OnboardingContent.sample.hook.headline)
        #expect(content.hook.subheadline == OnboardingContent.sample.hook.subheadline)
        #expect(content.hook.primaryCTA == OnboardingContent.sample.hook.primaryCTA)
        #expect(content.hook.secondaryCTA == OnboardingContent.sample.hook.secondaryCTA)
        #expect(content.signIn == OnboardingContent.sample.signIn)
        #expect(content.slides == OnboardingContent.sample.slides)
        #expect(content.reviews.title == OnboardingContent.sample.reviews.title)
    }

    @Test("The hook headline is exactly the reference claim, in Quran terms")
    func hookCopyIsExact() throws {
        let hook = try Self.repoContent().hook
        #expect(
            hook.headline.plainText
                == "The average Muslim will spend 2+ hours today scrolling social media."
        )
        #expect(hook.subheadline == "Let's give some of that time back to Allah.")
        #expect(hook.headline.filter { $0.style == .boldItalic }.map(\.text) == ["2+ hours today"])
    }

    @Test("Slide ids line up with the snapshot ids the manifest routes to")
    func slideIDsMatchSteps() throws {
        let ids = try Self.repoContent().slides.map(\.id)
        #expect(ids == ["onboarding-slide1", "onboarding-slide2", "onboarding-slide3", "onboarding-slide4"])
    }

    @Test("No slide body promises transliteration — CLAUDE.md rule 5 forbids it")
    func noTransliteration() throws {
        let content = try Self.repoContent()
        let copy = (content.slides.map(\.body) + content.slides.map(\.title)).joined(separator: " ")
        #expect(!copy.lowercased().contains("transliterat"))
    }

    @Test("Every screen that shows a number is still flagged as a placeholder")
    func placeholdersStayFlagged() throws {
        let content = try Self.repoContent()
        #expect(content.hook.placeholder)
        #expect(content.reviews.placeholder)
        #expect(content.reviews.cards.filter { !$0.placeholder }.isEmpty)
    }

    @Test("Recover access is a mailto, not a web flow")
    func recoverIsMailto() throws {
        let url = try #require(Self.repoContent().signIn.recoverURL)
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.contains("support@quranscroller.com"))
        #expect(url.absoluteString.contains("subject="))
    }

    @Test("Loading from a bundle without the resource reports notFound")
    func missingResourceThrows() {
        #expect(throws: OnboardingContent.LoadError.notFound) {
            try OnboardingContent.load(from: Bundle(for: BundleMarker.self))
        }
    }
}

/// Only here so `Bundle(for:)` has a class in the test bundle to anchor on.
private final class BundleMarker {}
