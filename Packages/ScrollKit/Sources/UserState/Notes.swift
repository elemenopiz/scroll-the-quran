import Foundation
import QuranData

/// One note, attached to a verse or a study passage by its key (`"2:255"`, `"94:5-6"`).
public struct Note: Hashable, Codable, Sendable, Identifiable {
    public let key: String
    public var text: String
    public var updatedAt: Date

    public var id: String {
        key
    }

    public init(key: String, text: String, updatedAt: Date) {
        self.key = key
        self.text = text
        self.updatedAt = updatedAt
    }
}

/// The user's notes, keyed by verse or passage key.
public struct Notes: Hashable, Codable, Sendable {
    public private(set) var byKey: [String: Note]

    public init(byKey: [String: Note] = [:]) {
        self.byKey = byKey
    }

    public var count: Int {
        byKey.count
    }

    public var isEmpty: Bool {
        byKey.isEmpty
    }

    public func note(for key: String) -> Note? {
        byKey[key]
    }

    public func note(for verse: VerseRef) -> Note? {
        byKey[verse.key]
    }

    public func note(for passage: PassageRef) -> Note? {
        byKey[passage.key]
    }

    public func text(for key: String) -> String {
        byKey[key]?.text ?? ""
    }

    /// Writes a note. Whitespace-only text deletes it, which is what the notes sheet does
    /// when the user clears the field. Returns true when anything changed.
    @discardableResult
    public mutating func set(_ text: String, for key: String, now: Date) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return byKey.removeValue(forKey: key) != nil
        }
        if byKey[key]?.text == trimmed {
            return false
        }
        byKey[key] = Note(key: key, text: trimmed, updatedAt: now)
        return true
    }

    @discardableResult
    public mutating func set(_ text: String, for verse: VerseRef, now: Date) -> Bool {
        set(text, for: verse.key, now: now)
    }

    @discardableResult
    public mutating func set(_ text: String, for passage: PassageRef, now: Date) -> Bool {
        set(text, for: passage.key, now: now)
    }

    @discardableResult
    public mutating func remove(for key: String) -> Bool {
        byKey.removeValue(forKey: key) != nil
    }

    /// Newest first — the order the Library lists notes in.
    public var recent: [Note] {
        byKey.values.sorted { lhs, rhs in
            lhs.updatedAt == rhs.updatedAt ? lhs.key < rhs.key : lhs.updatedAt > rhs.updatedAt
        }
    }

    public mutating func reset() {
        byKey = [:]
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case byKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        byKey = try container.decodeIfPresent([String: Note].self, forKey: .byKey) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(byKey, forKey: .byKey)
    }
}
