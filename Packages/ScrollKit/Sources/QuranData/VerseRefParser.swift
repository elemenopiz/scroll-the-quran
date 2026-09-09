import Foundation

/// Turns the strings people type, deep-link, and store into a ``VerseRef`` or ``PassageRef``.
///
/// Understood, with or without a surah name:
///
///     "2:255"              "94:5-6"          "2.255"        "2:255–256" (en dash)
///     "Al-Baqarah 255"     "Al-Baqarah 2:255"                "Surah Al-Baqarah 255-256"
///     "The Cow 255"        "an nas 1"        "112"          (a whole surah)
///
/// Give the parser a ``SurahIndex`` and it also rejects out-of-range ayat and resolves names;
/// without one it still parses the numeric forms.
public struct VerseRefParser: Sendable {
    public let index: SurahIndex?

    public init(index: SurahIndex? = nil) {
        self.index = index
    }

    /// Numeric-only parsing, for call sites that have no index handy.
    public static let numeric = VerseRefParser()

    /// A single ayah. `"94:5-6"` yields its first ayah; use ``passage(_:)`` to keep the range.
    public func verse(_ input: String) -> VerseRef? {
        guard let passage = passage(input) else { return nil }
        return VerseRef(surah: passage.surah, ayah: passage.start)
    }

    /// A passage. A bare surah reference (`"112"`, `"Al-Ikhlas"`) becomes the whole surah,
    /// which needs an index to know how long it is.
    public func passage(_ input: String) -> PassageRef? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let (namePart, numberPart) = Self.split(trimmed)
        var named: Surah?
        if let namePart, !namePart.isEmpty {
            guard let match = index?.surah(named: namePart) else { return nil }
            named = match
        }

        guard let numbers = Self.numbers(in: numberPart) else {
            // "Al-Baqarah" on its own.
            guard let named, numberPart.isEmpty else { return nil }
            return validated(surah: named.number, start: 1, end: named.ayahCount)
        }
        // "2.255" is the same reference as "2:255"; without a separator two numbers mean a range.
        let separated = numberPart.contains(":") || numberPart.contains(".")

        if let named {
            return passage(inside: named, numbers: numbers, separated: separated)
        }
        return passage(numbers: numbers, separated: separated)
    }

    /// `"2:255"`, `"2:255-256"`, or a bare surah number.
    private func passage(numbers: [Int], separated: Bool) -> PassageRef? {
        switch numbers.count {
        case 1:
            // "112" — the whole surah.
            guard let surah = index?.surah(numbers[0]) else { return nil }
            return validated(surah: surah.number, start: 1, end: surah.ayahCount)
        case 2:
            guard separated else { return nil }
            return validated(surah: numbers[0], start: numbers[1], end: numbers[1])
        case 3:
            guard separated else { return nil }
            return validated(surah: numbers[0], start: numbers[1], end: numbers[2])
        default:
            return nil
        }
    }

    /// `"Al-Baqarah 255"`, `"Al-Baqarah 255-256"`, `"Al-Baqarah 2:255"`, `"Al-Baqarah 2:255-256"`.
    /// When the reference repeats the surah number it has to agree with the name.
    private func passage(inside surah: Surah, numbers: [Int], separated: Bool) -> PassageRef? {
        switch (numbers.count, separated) {
        case (1, _):
            return validated(surah: surah.number, start: numbers[0], end: numbers[0])
        case (2, true):
            guard numbers[0] == surah.number else { return nil }
            return validated(surah: surah.number, start: numbers[1], end: numbers[1])
        case (2, false):
            return validated(surah: surah.number, start: numbers[0], end: numbers[1])
        case (3, true):
            guard numbers[0] == surah.number else { return nil }
            return validated(surah: surah.number, start: numbers[1], end: numbers[2])
        default:
            return nil
        }
    }

    /// A range must not run backwards, and — when there is an index — must be inside the surah.
    /// Without an index the ayah counts are unknowable, so any positive number is accepted.
    private func validated(surah: Int, start: Int, end: Int) -> PassageRef? {
        guard surah >= 1, start >= 1, end >= start else { return nil }
        let passage = PassageRef(surah: surah, start: start, end: end)
        guard let index else { return passage }
        return index.contains(passage) ? passage : nil
    }

    /// `"Al-Baqarah 2:255"` -> `("Al-Baqarah", "2:255")`; `"2:255"` -> `(nil, "2:255")`.
    /// The split happens at the last run of letters, so `"1"` and `"al-imran 3"` both work.
    private static func split(_ input: String) -> (name: String?, numbers: String) {
        let scalars = Array(input)
        var boundary = scalars.count
        while boundary > 0, Self.isNumberSide(scalars[boundary - 1]) {
            boundary -= 1
        }
        guard boundary > 0 else { return (nil, input) }
        let name = String(scalars[0 ..< boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
        let numbers = String(scalars[boundary...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return numbers.isEmpty ? (name, "") : (name, numbers)
    }

    private static func isNumberSide(_ character: Character) -> Bool {
        character.isNumber || character.isWhitespace || ":.-–—".contains(character)
    }

    /// The positive integers in `"2:255-256"`, in order. Nil when it is not a reference at all.
    private static func numbers(in text: String) -> [Int]? {
        var numbers: [Int] = []
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                numbers.append(Int(current) ?? 0)
                current = ""
            }
        }
        if !current.isEmpty {
            numbers.append(Int(current) ?? 0)
        }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 >= 1 }), numbers.count <= 3 else { return nil }
        return numbers
    }
}

public extension VerseRefParser {
    /// `"2:255"` only. Convenience for deep links and stored keys, which are always numeric.
    static func verse(key: String) -> VerseRef? {
        VerseRef(key: key)
    }

    /// `"94:5-6"` and `"2:255"` only.
    static func passage(key: String) -> PassageRef? {
        PassageRef(key: key)
    }
}
