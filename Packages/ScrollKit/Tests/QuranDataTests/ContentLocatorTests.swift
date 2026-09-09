import Foundation
@testable import QuranData
import Testing

@Test("A locator finds files under the roots it is given, in order")
func locatorSearchesItsRootsInOrder() throws {
    let locator = ContentLocator(roots: [
        repoRoot.appendingPathComponent("Reference", isDirectory: true),
        TestContent.contentDirectory,
    ])
    #expect(locator.url(for: "quran/surahs.json") != nil)
    #expect(locator.url(for: "manifest.json") != nil, "the first root should still be searched")
    let registry = try locator.data(for: "quran/translations.json")
    #expect(!registry.isEmpty)
}

@Test("A missing file names the roots that were searched")
func missingFilesReportTheRoots() {
    let locator = ContentLocator(roots: [TestContent.contentDirectory])
    #expect(locator.url(for: "quran/nothing.json") == nil)
    #expect(throws: ContentLocatorError.self) { try locator.data(for: "quran/nothing.json") }
    let error = ContentLocatorError.notFound(relativePath: "quran/nothing.json", roots: ["/tmp"])
    #expect(error.description.contains("SCROLLKIT_CONTENT_DIR"))
}

@Test("SCROLLKIT_CONTENT_DIR wins over the bundle, which is how host tests find Content/")
func environmentOverrideIsSearchedFirst() throws {
    let locator = ContentLocator(
        environment: [ContentLocator.environmentKey: TestContent.contentDirectory.path],
        bundle: .main
    )
    #expect(locator.roots.first?.path == TestContent.contentDirectory.path)
    #expect(locator.url(for: "quran/surahs.json") != nil)

    let store = try TranslationStore(locator: locator)
    #expect(store.text(for: VerseRef(surah: 1, ayah: 1))?.isEmpty == false)

    // An empty value is ignored, leaving only the bundle roots.
    let bundleOnly = ContentLocator(environment: [ContentLocator.environmentKey: ""], bundle: .main)
    #expect(bundleOnly.roots.allSatisfy { $0.path != TestContent.contentDirectory.path })
}
