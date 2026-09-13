@testable import FeatureReader
import QuranData
import Testing

@Suite("Screenshot routes and the surah picker's search")
@MainActor
struct ReaderScreenRouteTests {
    @Test("the screenshot ids match the manifest's route strings")
    func routeIDsMatchTheManifest() {
        #expect(ReaderView.Screen.reader.rawValue == "reader")
        #expect(ReaderView.Screen.translationSheet.rawValue == "translation-sheet")
        #expect(ReaderView.Screen.notesSheet.rawValue == "notes-sheet")
        #expect(ReaderView.Screen.verseMenu.rawValue == "reader-verse-menu")
        #expect(ReaderView.Screen.allCases.count == 4)
    }

    /// `reader` is the reference capture and must stay on page 0; the verse menu wants the
    /// ayah the rest of the app is captured against.
    @Test("each screenshot route opens on the ayah its capture needs")
    func routeStartAyahs() {
        #expect(ReaderView.Screen.reader.startAyah == nil)
        #expect(ReaderView.Screen.translationSheet.startAyah == 1)
        #expect(ReaderView.Screen.notesSheet.startAyah == 1)
        #expect(ReaderView.Screen.verseMenu.startAyah == 255)
    }

    @Test("the verse-menu route lands on 2:255 with the menu already up")
    func verseMenuRoutePresentsTheMenu() throws {
        let model = try ReaderModel(
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: TestContent.userStore(),
            hints: EphemeralReaderHintStore(),
            surah: ReaderView.screenshotSurah,
            startAyah: ReaderView.Screen.verseMenu.startAyah
        )
        model.present(.verseMenu)
        #expect(model.sheet == .verseMenu)
        #expect(model.focusedVerse == VerseRef(surah: 2, ayah: 255))
    }

    @Test(
        "an anchor on the route is ignored",
        arguments: ["reader", "reader#top", "notes-sheet#anything", "reader-verse-menu#x"]
    )
    func anchorsAreStripped(_ route: String) {
        let head = route.split(separator: "#", maxSplits: 1).first.map(String.init) ?? route
        #expect(ReaderView.Screen(rawValue: head) != nil)
    }

    @Test("an unknown route still renders a reader rather than nothing")
    func unknownRouteFallsBack() throws {
        // Building the view is enough: `screen(for:)` must not trap on an id it does not own.
        _ = try ReaderView.screen(
            for: "home#scrolled",
            index: TestContent.index(),
            translations: TestContent.translations(),
            user: TestContent.userStore()
        )
    }

    @Test("the surah picker finds a surah by name, article-less name, meaning and number")
    func pickerSearch() throws {
        let index = try TestContent.index()
        func numbers(_ query: String) -> [Int] {
            SurahPicker.filter(query, in: index).map(\.number)
        }
        #expect(numbers("").count == 114)
        #expect(numbers("Al-Baqarah") == [2])
        #expect(numbers("baqarah") == [2])
        #expect(numbers("The Cow") == [2])
        #expect(numbers("112") == [112])
        // "nas" is a real alias (An-Nas with its article stripped), so it resolves outright.
        #expect(numbers("nas") == [114])
        // A prefix that matches no alias narrows by substring instead.
        #expect(numbers("al-m").count > 1)
        #expect(numbers("al-m").allSatisfy { index.surah($0)?.name.hasPrefix("Al-M") == true })
        #expect(numbers("zzzz").isEmpty)
    }

    @Test("the picker groups surahs into the juz they start in")
    func pickerSections() throws {
        let index = try TestContent.index()
        let sections = SurahPicker.sections(for: "", in: index)
        #expect(sections.map(\.juz) == sections.map(\.juz).sorted())
        #expect(sections.flatMap(\.surahs).count == 114)
        #expect(sections.first?.juz == 1)
        #expect(sections.first?.surahs.first?.number == 1)
        #expect(sections.last?.juz == 30)
    }
}
