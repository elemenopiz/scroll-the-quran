import Foundation
import QuranData
import StudyContent

/// Everything a verse surface needs to draw one passage, resolved once out of the
/// stores so the views stay free of lookups.
///
/// `arabic` is the muted layer (CLAUDE.md rule 5) and is `nil` when the Uthmani file
/// is missing — the English never depends on it.
public struct PassagePresentation: Equatable, Sendable {
    public let passage: PassageRef
    /// `"Al-Fatihah 1:5-7"` — the serif line under the theme chip.
    public let reference: String
    /// The joined Uthmani lines, or nil.
    public let arabic: String?
    /// The joined English of the passage, without quotation marks.
    public let english: String
    /// The short badge under the reference, e.g. `"CLEAR"`.
    public let translationTag: String
    /// The licence line the translation requires, for share and copy.
    public let attribution: String

    public init(
        passage: PassageRef,
        reference: String,
        arabic: String?,
        english: String,
        translationTag: String,
        attribution: String = ""
    ) {
        self.passage = passage
        self.reference = reference
        self.arabic = arabic
        self.english = english
        self.translationTag = translationTag
        self.attribution = attribution
    }

    /// The English wrapped the way the reference app draws it, in straight quotes.
    public var quoted: String {
        english.isEmpty ? "" : "\"\(english)\""
    }

    /// Resolves a passage against the stores. Returns a usable value even when a piece
    /// is missing: an unknown surah degrades to the bare key, missing Arabic to `nil`.
    public static func make(
        for passage: PassageRef,
        translations: TranslationStore?,
        translationID: String? = nil
    ) -> PassagePresentation {
        guard let translations else {
            return PassagePresentation(
                passage: passage,
                reference: passage.key,
                arabic: nil,
                english: "",
                translationTag: ""
            )
        }
        let id = translationID ?? translations.selectedID
        let info = translations.info(for: id)
        let surah = translations.index.surah(passage.surah)
        let arabic = translations.arabic(for: passage).joined(separator: " ")
        return PassagePresentation(
            passage: passage,
            reference: surah?.reference(for: passage) ?? passage.key,
            arabic: arabic.isEmpty ? nil : arabic,
            english: translations.texts(for: passage, translation: id).joined(separator: " "),
            translationTag: info?.abbrev ?? "",
            attribution: info?.attribution ?? ""
        )
    }

    public static func make(
        forKey key: String,
        translations: TranslationStore?,
        translationID: String? = nil
    ) -> PassagePresentation? {
        guard let passage = PassageRef(key: key) else { return nil }
        return make(for: passage, translations: translations, translationID: translationID)
    }
}
