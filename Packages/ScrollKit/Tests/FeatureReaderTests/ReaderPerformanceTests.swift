@testable import FeatureReader
import Foundation
import QuranData
import Testing
import UserState

/// "Al-Baqarah opens in under 400 ms" (the brief's budget), measured where the reader can
/// actually be held to it: building the model and its 287 pages against warm stores.
///
/// The one-off cost of decoding a translation file is `TranslationStore`'s, not the reader's,
/// and is paid once per app run rather than per surah, so it is warmed before the clock starts.
@Suite("Reader performance")
@MainActor
struct ReaderPerformanceTests {
    static let budget = Duration.milliseconds(400)

    /// The longest surah, 286 ayat, several of which split into continuation pages.
    @Test("opening Al-Baqarah stays inside the 400 ms budget")
    func openingAlBaqarahIsFast() throws {
        let index = try TestContent.index()
        let translations = try TestContent.translations()
        let user = TestContent.userStore()
        warm(translations)

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let model = ReaderModel(
                index: index,
                translations: translations,
                user: user,
                hints: EphemeralReaderHintStore(),
                surah: 2
            )
            // Touch the output so the work cannot be optimised away.
            precondition(model.pages.count > 286)
        }
        #expect(elapsed < Self.budget, "opening Al-Baqarah took \(elapsed)")
    }

    @Test("switching translation re-paginates Al-Baqarah inside the same budget")
    func switchingTranslationIsFast() throws {
        let index = try TestContent.index()
        let translations = try TestContent.translations()
        let model = ReaderModel(
            index: index,
            translations: translations,
            user: TestContent.userStore(),
            hints: EphemeralReaderHintStore(),
            surah: 2
        )
        warm(translations)
        _ = try translations.verses(of: "pickthall")

        let clock = ContinuousClock()
        let elapsed = clock.measure { model.selectTranslation("pickthall") }
        #expect(elapsed < Self.budget, "re-paginating took \(elapsed)")
    }

    @Test("paging through the whole of Al-Baqarah does no per-page loading")
    func pagingIsAllocationFree() throws {
        let model = try TestContent.model(surah: 2)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for page in model.pages {
                model.currentPageID = page.id
                _ = model.currentPage
                _ = model.railAyah
            }
        }
        // 287 page changes; anything that re-read the store would be orders of magnitude slower.
        #expect(elapsed < Self.budget, "paging through the surah took \(elapsed)")
    }

    /// Pulls the selected translation and the Arabic into the store's cache.
    private func warm(_ translations: TranslationStore) {
        _ = translations.text(for: VerseRef(surah: 1, ayah: 1))
        _ = translations.arabic(for: VerseRef(surah: 1, ayah: 1))
    }
}
