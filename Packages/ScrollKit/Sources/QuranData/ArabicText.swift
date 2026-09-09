import Foundation

/// Operations on the bundled Uthmani Arabic that the render layer needs but that must not
/// change the stored text: Tanzil's terms require the file to stay verbatim, so anything the
/// UI wants to hide is hidden **at render time**, here.
///
/// The only such rule today is the Basmala (CLAUDE.md, "Basmala rule"): Uthmani editions
/// prefix ayah 1 of every surah except 1 (where it *is* ayah 1) and 9 (which has none) with
/// `بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ`. The reader shows that Bismillah once, on the
/// surah's page 0, and never inside the verse-1 line.
public enum ArabicText {
    /// The Bismillah as the bundled Uthmani edition spells it (identical to ayah 1:1).
    public static let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    /// The English of the Bismillah, matching the default translation's rendering of 1:1.
    public static let basmalaEnglish = "In the name of God, the Gracious, the Merciful"

    /// Surahs whose ayah 1 never carries the prefix: 1 spells it out as ayah 1, 9 has none.
    public static let surahsWithoutBasmalaPrefix: Set<Int> = [1, 9]

    /// True when this ayah is the one an Uthmani edition may prefix with the Bismillah.
    public static func expectsBasmalaPrefix(surah: Int, ayah: Int) -> Bool {
        ayah == 1 && surah >= 1 && surah <= SurahIndex.surahCount && !surahsWithoutBasmalaPrefix.contains(surah)
    }

    public static func expectsBasmalaPrefix(_ verse: VerseRef) -> Bool {
        expectsBasmalaPrefix(surah: verse.surah, ayah: verse.ayah)
    }

    /// True when `text` opens with the Bismillah, in any of its Uthmani spellings.
    public static func hasBasmalaPrefix(_ text: String) -> Bool {
        basmalaPrefixLength(of: text) != nil
    }

    /// `text` with a leading Bismillah removed, or `text` unchanged when there is none.
    ///
    /// Spelling-insensitive: the comparison runs on the *letter skeleton* (harakat, sukun,
    /// the superscript alef, pause marks and tatweel folded away, and every alef form folded
    /// to bare alef), so `بِسْمِ`, `بِسۡمِ` and the undecorated `بسم` all match.
    public static func stripBasmala(_ text: String) -> String {
        guard let length = basmalaPrefixLength(of: text) else { return text }
        return String(text.dropFirst(length)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The verse-1 form of ``stripBasmala(_:)``: only ayah 1 of surahs 2–114 except 9 can
    /// carry the prefix, so no other ayah is ever touched — not even one that happens to
    /// open with the same words.
    public static func stripBasmala(_ text: String, surah: Int, ayah: Int) -> String {
        guard expectsBasmalaPrefix(surah: surah, ayah: ayah) else { return text }
        return stripBasmala(text)
    }

    public static func stripBasmala(_ text: String, verse: VerseRef) -> String {
        stripBasmala(text, surah: verse.surah, ayah: verse.ayah)
    }

    // MARK: - Skeleton matching

    /// How many `Character`s of `text` (including the whitespace after them) make up a
    /// leading Bismillah, or nil when the text does not start with one.
    static func basmalaPrefixLength(of text: String) -> Int? {
        let target = skeleton(basmala)
        guard !target.isEmpty else { return nil }

        var matched: [Character] = []
        var consumed = 0
        for character in text {
            consumed += 1
            let letters = skeleton(String(character))
            guard !letters.isEmpty else {
                // Whitespace and marks between letters: absorbed, they carry no skeleton.
                continue
            }
            matched.append(contentsOf: letters)
            guard matched.count <= target.count, target.starts(with: matched) else { return nil }
            if matched.count == target.count {
                // Swallow the separator that follows the prefix so the verse does not start
                // with a space.
                var end = text.index(text.startIndex, offsetBy: consumed)
                while end < text.endIndex, text[end].isWhitespace {
                    end = text.index(after: end)
                    consumed += 1
                }
                return consumed
            }
        }
        return nil
    }

    /// The bare consonant skeleton: diacritics, Quranic annotation marks, tatweel and
    /// whitespace removed, and every alef variant folded to `ا`.
    static func skeleton(_ text: String) -> [Character] {
        var letters: [Character] = []
        for scalar in text.unicodeScalars {
            if isIgnorable(scalar) {
                continue
            }
            guard let folded = Unicode.Scalar(foldedAlef(scalar.value)) else { continue }
            letters.append(Character(folded))
        }
        return letters
    }

    /// Combining harakat, sukun, the superscript alef, the Quranic annotation block
    /// (pause marks, small letters), tatweel, and anything that is not a letter.
    static func isIgnorable(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0610 ... 0x061A, // Arabic honorific and Quranic signs
             0x064B ... 0x065F, // harakat, sukun, shadda, and the extended set
             0x0670, // superscript alef
             0x06D6 ... 0x06ED, // small high/low marks, sajdah, pause marks
             0x0640: // tatweel
            true
        default:
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.punctuationCharacters.contains(scalar)
        }
    }

    /// Alef with hamza/madda, and alef wasla, all read as plain alef.
    static func foldedAlef(_ value: UInt32) -> UInt32 {
        switch value {
        case 0x0622, 0x0623, 0x0625, 0x0671, 0x0672, 0x0673, 0x0675: 0x0627
        default: value
        }
    }
}
