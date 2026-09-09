import Foundation
import QuranData
@testable import StudyContent
import Testing

@Test("themes.json loads with unique ids and non-empty ref lists")
func themesLoadCleanly() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    // themes.mjs refuses to write fewer than 40.
    #expect(themes.count >= 40)
    #expect(themes.ids.count == themes.count, "themes.json repeats an id")
    for theme in themes.themes {
        #expect(!theme.id.isEmpty)
        #expect(!theme.title.isEmpty)
        #expect(theme.blurb?.isEmpty == false, "\(theme.id) has no blurb")
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
            #expect(
                passage.end <= surahs[passage.surah - 1].ayahCount,
                "\(theme.id) ref \(passage.key) runs past the surah"
            )
        }
    }
}

@Test("Themes are found by id and by the ayat they list")
func themesResolveBothWays() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    #expect(themes.theme(id: "sincerity")?.title == "Sincerity")
    #expect(themes.theme(id: "time-and-life")?.title == "Time and the Brevity of Life")
    #expect(themes.theme(id: "not-a-theme") == nil)

    #expect(themes.theme(for: VerseRef(surah: 112, ayah: 2))?.id == "sincerity")
    #expect(themes.theme(for: VerseRef(surah: 2, ayah: 153))?.id == "patience-in-trials")
    #expect(themes.theme(forKey: "1:6-7")?.id == "guidance")
    // 103:1-3 is listed by two themes, in file order.
    #expect(themes.themes(for: VerseRef(surah: 103, ayah: 3)).map(\.id) == ["patience-in-trials", "time-and-life"])
    // An ayah no theme lists.
    #expect(themes.theme(for: VerseRef(surah: 2, ayah: 6)) == nil)
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

@Test("Every synced study points at a theme themes.json defines, with the same title")
func syncedThemeIDsExist() throws {
    let themes = try ThemeIndex(loader: bundledContent)
    for study in try syncedStudies() {
        let theme = try #require(themes.theme(id: study.themeId), "\(study.key) has unknown theme \(study.themeId)")
        #expect(theme.title == study.theme, "\(study.key) theme title drifted from themes.json")
    }
}
