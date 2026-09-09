import Foundation
import QuranData

/// One entry of `Content/themes.json`: a title and the ayah ranges that belong to it.
/// Themes carry no prose — the commentary lives in `Content/study`.
public struct Theme: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let refs: [String]
    public let blurb: String?

    public init(id: String, title: String, refs: [String], blurb: String? = nil) {
        self.id = id
        self.title = title
        self.refs = refs
        self.blurb = blurb
    }

    /// The refs that parse, as passages.
    public var passages: [PassageRef] {
        refs.compactMap { PassageRef(key: $0) }
    }
}

/// `Content/themes.json`, indexed both ways: theme id -> theme, and ayah -> the themes that
/// list it.
public struct ThemeIndex: Hashable, Sendable {
    public let themes: [Theme]

    private let byID: [String: Theme]
    /// Ayah key -> the ids of the themes covering it, in `themes` order.
    private let byVerse: [String: [String]]

    public init(themes: [Theme]) {
        self.themes = themes
        byID = Dictionary(themes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var verses: [String: [String]] = [:]
        for theme in themes {
            for passage in theme.passages {
                for verse in passage.verses where !(verses[verse.key]?.contains(theme.id) ?? false) {
                    verses[verse.key, default: []].append(theme.id)
                }
            }
        }
        byVerse = verses
    }

    public init(loader: StudyContentLoading, path: String = "themes.json") throws {
        try self.init(themes: JSONDecoder().decode(ThemeFile.self, from: loader.data(at: path)).themes)
    }

    public static let empty = ThemeIndex(themes: [])

    public var ids: Set<String> {
        Set(byID.keys)
    }

    public var count: Int {
        themes.count
    }

    public func theme(id: String) -> Theme? {
        byID[id]
    }

    /// Every theme that lists this ayah, in file order.
    public func themes(for verse: VerseRef) -> [Theme] {
        (byVerse[verse.key] ?? []).compactMap { byID[$0] }
    }

    /// The first theme listing this ayah — the one the app labels a card with.
    public func theme(for verse: VerseRef) -> Theme? {
        themes(for: verse).first
    }

    /// Every theme touching any ayah of a passage, in file order, without repeats.
    public func themes(for passage: PassageRef) -> [Theme] {
        var seen: Set<String> = []
        var found: [Theme] = []
        for verse in passage.verses {
            for id in byVerse[verse.key] ?? [] where seen.insert(id).inserted {
                if let theme = byID[id] {
                    found.append(theme)
                }
            }
        }
        return found
    }

    /// Resolves `"2:255"` or `"2:155-157"`.
    public func themes(forKey key: String) -> [Theme] {
        guard let passage = PassageRef(key: key) else { return [] }
        return themes(for: passage)
    }

    public func theme(forKey key: String) -> Theme? {
        themes(forKey: key).first
    }
}

/// The on-disk wrapper around the theme list, as `Tools/content-gen/themes.mjs` writes it:
/// `{source, themes: [{id, title, blurb, refs}]}`.
public struct ThemeFile: Codable, Hashable, Sendable {
    public let version: Int?
    /// Where the list came from — provenance the generator records, shown nowhere.
    public let source: String?
    public let themes: [Theme]

    public init(version: Int? = nil, source: String? = nil, themes: [Theme]) {
        self.version = version
        self.source = source
        self.themes = themes
    }
}
