import Foundation
import QuranData
@testable import StudyContent
import Testing

@Test("themes.json loads with unique ids and non-empty ref lists")
func themesLoadCleanly() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    #expect(themes.count >= 15)
    #expect(themes.ids.count == themes.count, "themes.json repeats an id")
    for theme in themes.themes {
        #expect(!theme.id.isEmpty)
        #expect(!theme.title.isEmpty)
        #expect(!theme.refs.isEmpty, "\(theme.id) lists no refs")
        #expect(theme.passages.count == theme.refs.count, "\(theme.id) has a ref that does not parse")
    }
}

@Test("Every theme ref points at an ayah that exists")
func themeRefsAreInBounds() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    let surahs = try bundledSurahs()
    for theme in themes.themes {
        for passage in theme.passages {
            #expect((1 ... 114).contains(passage.surah), "\(theme.id) has no such surah in \(passage.key)")
            #expect(passage.end <= surahs[passage.surah - 1].ayahCount, "\(theme.id) ref \(passage.key) runs past the surah")
        }
    }
}

@Test("Themes are found by id and by the ayat they list")
func themesResolveBothWays() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    #expect(themes.theme(id: "tawhid")?.title == "Oneness of God")
    #expect(themes.theme(id: "time")?.title == "Time and what lasts")
    #expect(themes.theme(id: "not-a-theme") == nil)

    #expect(themes.theme(for: VerseRef(surah: 112, ayah: 2))?.id == "tawhid")
    #expect(themes.theme(for: VerseRef(surah: 103, ayah: 3))?.id == "time")
    #expect(themes.theme(forKey: "1:5-7")?.id == "guidance")
    #expect(themes.theme(for: VerseRef(surah: 55, ayah: 60)) == nil)
}

@Test("A ranged ref indexes every ayah inside it, and an ayah in two themes lists both")
func rangedRefsExpandAndStack() {
    let themes = ThemeIndex(themes: [
        Theme(id: "patience", title: "Patience", refs: ["2:155-157"]),
        Theme(id: "trials", title: "Trials", refs: ["2:156", "2:286"]),
    ])
    #expect(themes.themes(for: VerseRef(surah: 2, ayah: 155)).map(\.id) == ["patience"])
    #expect(themes.themes(for: VerseRef(surah: 2, ayah: 156)).map(\.id) == ["patience", "trials"])
    #expect(themes.themes(for: VerseRef(surah: 2, ayah: 157)).map(\.id) == ["patience"])
    #expect(themes.themes(for: VerseRef(surah: 2, ayah: 158)).isEmpty)
    #expect(themes.themes(forKey: "2:155-157").map(\.id) == ["patience", "trials"])
    #expect(themes.themes(forKey: "nonsense").isEmpty)
    #expect(ThemeIndex.empty.themes(for: VerseRef(surah: 2, ayah: 156)).isEmpty)
}

@Test("Every fixture study points at a theme themes.json defines")
func fixtureThemeIDsExist() throws {
    let store = try bundledStore()
    let themes = try ThemeIndex(loader: bundledContent)
    for surah in fixtureSurahs {
        for study in store.studies(inSurah: surah) {
            let theme = try #require(themes.theme(id: study.themeId), "\(study.key) has unknown theme \(study.themeId)")
            #expect(theme.title == study.theme, "\(study.key) theme title drifted from themes.json")
        }
    }
}
