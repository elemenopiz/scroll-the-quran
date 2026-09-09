import Foundation
import QuranData

/// Saved verses, saved Deep Study passages and likes — everything the Library screen lists.
///
/// Saves are ordered most-recent-first (the Library shows them that way); likes are a set
/// because only the heart's on/off state matters. All three encode as key strings
/// (`"2:255"`, `"94:5-6"`) so the JSON stays readable and small.
public struct Library: Hashable, Codable, Sendable {
    public private(set) var savedVerses: [VerseRef]
    public private(set) var savedStudies: [PassageRef]
    public private(set) var likedVerses: Set<VerseRef>

    public init(savedVerses: [VerseRef] = [], savedStudies: [PassageRef] = [], likedVerses: Set<VerseRef> = []) {
        self.savedVerses = savedVerses
        self.savedStudies = savedStudies
        self.likedVerses = likedVerses
    }

    public var isEmpty: Bool {
        savedVerses.isEmpty && savedStudies.isEmpty && likedVerses.isEmpty
    }

    // MARK: Verses

    public func isSaved(_ verse: VerseRef) -> Bool {
        savedVerses.contains(verse)
    }

    /// Saves or unsaves. Returns the state after the toggle.
    @discardableResult
    public mutating func toggleSaved(_ verse: VerseRef) -> Bool {
        if let index = savedVerses.firstIndex(of: verse) {
            savedVerses.remove(at: index)
            return false
        }
        savedVerses.insert(verse, at: 0)
        return true
    }

    public mutating func save(_ verse: VerseRef) {
        guard !savedVerses.contains(verse) else { return }
        savedVerses.insert(verse, at: 0)
    }

    public mutating func unsave(_ verse: VerseRef) {
        savedVerses.removeAll { $0 == verse }
    }

    // MARK: Studies

    public func isSaved(_ passage: PassageRef) -> Bool {
        savedStudies.contains(passage)
    }

    @discardableResult
    public mutating func toggleSaved(_ passage: PassageRef) -> Bool {
        if let index = savedStudies.firstIndex(of: passage) {
            savedStudies.remove(at: index)
            return false
        }
        savedStudies.insert(passage, at: 0)
        return true
    }

    // MARK: Likes

    public func isLiked(_ verse: VerseRef) -> Bool {
        likedVerses.contains(verse)
    }

    @discardableResult
    public mutating func toggleLiked(_ verse: VerseRef) -> Bool {
        if likedVerses.contains(verse) {
            likedVerses.remove(verse)
            return false
        }
        likedVerses.insert(verse)
        return true
    }

    public mutating func reset() {
        savedVerses = []
        savedStudies = []
        likedVerses = []
    }

    // MARK: Codable — arrays of key strings, unparseable entries dropped.

    private enum CodingKeys: String, CodingKey {
        case savedVerses, savedStudies, likedVerses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let verses = try container.decodeIfPresent([String].self, forKey: .savedVerses) ?? []
        let studies = try container.decodeIfPresent([String].self, forKey: .savedStudies) ?? []
        let likes = try container.decodeIfPresent([String].self, forKey: .likedVerses) ?? []
        savedVerses = verses.compactMap(VerseRef.init(key:))
        savedStudies = studies.compactMap(PassageRef.init(key:))
        likedVerses = Set(likes.compactMap(VerseRef.init(key:)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(savedVerses.map(\.key), forKey: .savedVerses)
        try container.encode(savedStudies.map(\.key), forKey: .savedStudies)
        try container.encode(likedVerses.map(\.key).sorted(), forKey: .likedVerses)
    }
}
