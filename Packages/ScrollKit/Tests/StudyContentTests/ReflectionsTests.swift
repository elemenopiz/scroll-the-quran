import Foundation
@testable import StudyContent
import Testing

private func bundledReflectionsFile() throws -> ReflectionsFile {
    try JSONDecoder().decode(ReflectionsFile.self, from: contentData("reflections.json"))
}

private func bundledReflections() throws -> ReflectionStore {
    try ReflectionStore(loader: bundledContent)
}

private func bundledThemeIDs() throws -> Set<String> {
    try ThemeIndex(loader: bundledContent).ids
}

private func words(_ text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
}

@Test("reflections.json decodes the build script's shape, provenance and all")
func reflectionsFileDecodes() throws {
    let file = try bundledReflectionsFile()
    #expect(file.version == 1)
    #expect(file.generatedBy == "Tools/content-gen/build-reflections.mjs")
    #expect(file.generatedAt?.isEmpty == false)
    #expect(file.count == file.items.count, "the recorded count disagrees with the list")
}

@Test("The feed ships at least 120 reflections")
func reflectionsCount() throws {
    let store = try bundledReflections()
    #expect(store.count >= 120, "only \(store.count) reflections ship")
    #expect(!store.isEmpty)
}

@Test("Reflection ids are unique and every one resolves")
func reflectionIDsAreUnique() throws {
    let file = try bundledReflectionsFile()
    let store = try bundledReflections()
    #expect(Set(file.items.map(\.id)).count == file.items.count, "two entries share an id")
    #expect(store.count == file.items.count, "the store dropped an entry")
    for item in file.items {
        #expect(store.reflection(id: item.id)?.text == item.text, "\(item.id) does not resolve")
    }
}

@Test("Every theme a reflection names exists in themes.json")
func reflectionThemesResolve() throws {
    let ids = try bundledThemeIDs()
    let store = try bundledReflections()
    for reflection in store.items {
        #expect(!reflection.themes.isEmpty, "\(reflection.id) is filed under no theme")
        for theme in reflection.themes {
            #expect(ids.contains(theme), "\(reflection.id) names unknown theme \"\(theme)\"")
        }
    }
    // The catalogue promises every theme at least three cards, so the Discover UI can pair a
    // reflection with any theme it is showing.
    for theme in ids {
        #expect(store.reflections(theme: theme).count >= 3, "theme \"\(theme)\" has too few reflections")
    }
}

@Test("Every reflection carries a checkable source and its own rendering")
func reflectionsAreSourced() throws {
    let store = try bundledReflections()
    for reflection in store.items {
        #expect(!reflection.text.isEmpty)
        #expect(!reflection.attribution.isEmpty, "\(reflection.id) has no attribution line")
        #expect(!reflection.source.work.isEmpty, "\(reflection.id) names no work")
        #expect(!reflection.source.locator.isEmpty, "\(reflection.id) has no locator")
        #expect(reflection.source.translator == "own", "\(reflection.id) is not our own rendering")
        #expect(reflection.confidence == "high", "\(reflection.id) ships below high confidence")
        #expect(reflection.source.citation.hasPrefix(reflection.source.work))
        let count = words(reflection.text)
        #expect(count >= 10 && count <= 45, "\(reflection.id) is \(count) words")
    }
}

@Test("The card prints the honorific in words, and only for the Prophet")
func reflectionAttributionStyle() throws {
    let store = try bundledReflections()
    for reflection in store.items {
        #expect(!reflection.attribution.contains("ﷺ"), "\(reflection.id) uses the honorific glyph")
        #expect(!reflection.text.contains("Allah"), "\(reflection.id) says Allah in English prose")
    }
    let prophet = store.items.filter { $0.attribution == "The Prophet Muhammad (peace be upon him)" }
    #expect(prophet.count >= 40, "only \(prophet.count) hadith ship")
    for reflection in store.items where reflection.attribution != "The Prophet Muhammad (peace be upon him)" {
        #expect(
            !reflection.attribution.localizedCaseInsensitiveContains("peace be upon him"),
            "\(reflection.id) gives the honorific to someone else",
        )
    }
}

@Test("No one but the Prophet supplies more than twelve cards")
func reflectionPerPersonMaximum() throws {
    let store = try bundledReflections()
    var counts: [String: Int] = [:]
    for reflection in store.items where reflection.attribution != "The Prophet Muhammad (peace be upon him)" {
        counts[reflection.attribution, default: 0] += 1
    }
    for (person, count) in counts {
        #expect(count <= 12, "\(person) has \(count) reflections")
    }
}

@Test("Arabic, where a card carries it, is Arabic script and never a transliteration")
func reflectionArabicIsScript() throws {
    let arabic = CharacterSet(charactersIn: Unicode.Scalar(0x0600)! ... Unicode.Scalar(0x06FF)!)
    let store = try bundledReflections()
    for reflection in store.items {
        #expect(
            reflection.text.rangeOfCharacter(from: arabic) == nil,
            "\(reflection.id) puts Arabic in the English line",
        )
        guard let term = reflection.arabic else { continue }
        #expect(term.rangeOfCharacter(from: arabic) != nil, "\(reflection.id) has no Arabic in \"arabic\"")
        #expect(
            term.rangeOfCharacter(from: .letters.subtracting(arabic)) == nil,
            "\(reflection.id) transliterates in \"arabic\"",
        )
    }
}

@Test("The same seed always replays the same order")
func reflectionOrderIsDeterministic() throws {
    let store = try bundledReflections()
    #expect(store.ids(seed: 257) == store.ids(seed: 257))
    #expect(store.ids(seed: 257) != store.ids(seed: 258), "two seeds gave the same order")
    #expect(Set(store.ids(seed: 257)) == Set(store.items.map(\.id)), "the shuffle lost or repeated a card")
    #expect(store.items(seed: 1).count == store.count)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
    let ordinal = try #require(calendar.ordinality(of: .day, in: .year, for: day))
    #expect(store.items(on: day, calendar: calendar).map(\.id) == store.ids(seed: ordinal))
}

@Test("A store built by hand behaves like the bundled one")
func reflectionStoreDeduplicates() {
    let source = Reflection.Source(work: "Sahih Muslim", locator: "2699")
    let one = Reflection(id: "b", text: "Two.", attribution: "X", source: source, themes: ["hope"])
    let two = Reflection(id: "a", text: "One.", attribution: "X", source: source, themes: ["hope", "light"])
    let store = ReflectionStore(items: [one, two, one])
    #expect(store.count == 2, "the duplicate id survived")
    #expect(store.items.map(\.id) == ["a", "b"], "the base order is not by id")
    #expect(store.reflections(theme: "hope").map(\.id) == ["a", "b"])
    #expect(store.reflections(theme: "light").map(\.id) == ["a"])
    #expect(store.reflection(id: "missing") == nil)
    #expect(ReflectionStore.empty.isEmpty)
    #expect(source.citation == "Sahih Muslim 2699")
    // A chapter locator needs the comma a number does not.
    let chapter = Reflection.Source(work: "Sahih Muslim", locator: "the Book of Faith")
    #expect(chapter.citation == "Sahih Muslim, the Book of Faith")
    #expect(Reflection.Source(work: "Nahj al-Balagha", locator: "").citation == "Nahj al-Balagha")
}
