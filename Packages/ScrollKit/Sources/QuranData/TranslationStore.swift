import Foundation
import Observation

/// One row of `Content/quran/translations.json`. The `copyright` and `attribution` strings are
/// shown verbatim in the Translation sheet — the licences require it.
public struct TranslationInfo: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    /// Short badge on the reader's translation pill, e.g. `"ITANI"`.
    public let abbrev: String
    public let name: String
    public let translator: String
    public let language: String
    public let year: Int?
    public let copyright: String
    public let attribution: String
    public let licence: String
    /// Path relative to `Content/`, e.g. `"quran/itani.json"`.
    public let file: String
    public let isDefault: Bool
    public let bundled: Bool
    public let offline: Bool

    public init(
        id: String,
        abbrev: String,
        name: String,
        translator: String,
        language: String = "en",
        year: Int? = nil,
        copyright: String,
        attribution: String,
        licence: String,
        file: String,
        isDefault: Bool = false,
        bundled: Bool = true,
        offline: Bool = true
    ) {
        self.id = id
        self.abbrev = abbrev
        self.name = name
        self.translator = translator
        self.language = language
        self.year = year
        self.copyright = copyright
        self.attribution = attribution
        self.licence = licence
        self.file = file
        self.isDefault = isDefault
        self.bundled = bundled
        self.offline = offline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let copyright = try container.decode(String.self, forKey: .copyright)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            abbrev: container.decode(String.self, forKey: .abbrev),
            name: container.decode(String.self, forKey: .name),
            translator: container.decode(String.self, forKey: .translator),
            language: container.decodeIfPresent(String.self, forKey: .language) ?? "en",
            year: container.decodeIfPresent(Int.self, forKey: .year),
            copyright: copyright,
            attribution: container.decodeIfPresent(String.self, forKey: .attribution) ?? copyright,
            licence: container.decode(String.self, forKey: .licence),
            file: container.decode(String.self, forKey: .file),
            isDefault: container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false,
            bundled: container.decodeIfPresent(Bool.self, forKey: .bundled) ?? true,
            offline: container.decodeIfPresent(Bool.self, forKey: .offline) ?? true
        )
    }
}

/// The Arabic Uthmani text is not a translation, so it sits beside the list.
public struct ArabicEditionInfo: Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let file: String
    public let copyright: String
    public let attribution: String
    public let licence: String

    public static let tanzilFallback = ArabicEditionInfo(
        id: "arabic-uthmani",
        name: "Uthmani (Hafs)",
        file: "quran/arabic-uthmani.json",
        copyright: "Quran text from Tanzil.net",
        attribution: "Quran text (Uthmani) from Tanzil.net, licensed CC BY 3.0.",
        licence: "CC BY 3.0"
    )
}

/// `Content/quran/translations.json`.
public struct TranslationRegistry: Codable, Sendable {
    public let version: Int
    public let defaultID: String
    public let translations: [TranslationInfo]
    public let arabic: ArabicEditionInfo?

    public var arabicEdition: ArabicEditionInfo {
        arabic ?? .tanzilFallback
    }

    public var defaultTranslation: TranslationInfo? {
        translations.first(where: { $0.id == defaultID })
            ?? translations.first(where: { $0.isDefault })
            ?? translations.first
    }

    public subscript(id: String) -> TranslationInfo? {
        translations.first(where: { $0.id == id })
    }
}

/// Reads the bundled verse text: one English translation at a time plus the muted Arabic layer.
///
/// Files are loaded lazily and kept for the life of the store — a translation is ~800 KB of
/// strings, and the reader pages through a surah at a time.
///
///     let store = try TranslationStore()
///     store.text(for: VerseRef(surah: 2, ayah: 255))       // selected translation
///     store.text(for: ref, translation: "pickthall")       // a specific one
///     store.arabic(for: ref)                               // Uthmani line above the English
@Observable
public final class TranslationStore {
    public let registry: TranslationRegistry
    public let index: SurahIndex

    /// Which translation the reader is showing. Persisted by `UserState` as `Prefs.translationId`.
    public var selectedID: String

    @ObservationIgnored private let locator: ContentLocator
    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private var texts: [String: [String]] = [:]

    public init(
        registry: TranslationRegistry,
        index: SurahIndex,
        locator: ContentLocator = .shared,
        selectedID: String? = nil
    ) {
        self.registry = registry
        self.index = index
        self.locator = locator
        let requested = selectedID.flatMap { registry[$0]?.id }
        self.selectedID = requested ?? registry.defaultTranslation?.id ?? registry.defaultID
    }

    /// Loads `quran/translations.json` and `quran/surahs.json`.
    public convenience init(locator: ContentLocator = .shared, selectedID: String? = nil) throws {
        try self.init(
            registry: locator.decode(TranslationRegistry.self, from: "quran/translations.json"),
            index: SurahIndex(locator: locator),
            locator: locator,
            selectedID: selectedID
        )
    }

    public var translations: [TranslationInfo] {
        registry.translations
    }

    public var selected: TranslationInfo? {
        registry[selectedID]
    }

    /// Ignores an id that is not in the registry, so a stale preference cannot blank the reader.
    public func select(_ id: String) {
        guard registry[id] != nil else { return }
        selectedID = id
    }

    public func info(for id: String) -> TranslationInfo? {
        registry[id]
    }

    // MARK: - Text

    /// The English text of an ayah, in `translation` or in the selected translation.
    public func text(for verse: VerseRef, translation: String? = nil) -> String? {
        let id = translation ?? selectedID
        guard let position = index.globalIndex(of: verse), let verses = try? verses(of: id) else { return nil }
        return verses.indices.contains(position) ? verses[position] : nil
    }

    /// The Arabic Uthmani line shown above the English. Nil when the Arabic file is missing.
    public func arabic(for verse: VerseRef) -> String? {
        guard let position = index.globalIndex(of: verse) else { return nil }
        guard let verses = try? load(id: registry.arabicEdition.id, file: registry.arabicEdition.file) else { return nil }
        return verses.indices.contains(position) ? verses[position] : nil
    }

    /// Every ayah of a passage, in reading order.
    public func texts(for passage: PassageRef, translation: String? = nil) -> [String] {
        passage.verses.compactMap { text(for: $0, translation: translation) }
    }

    public func arabic(for passage: PassageRef) -> [String] {
        passage.verses.compactMap { arabic(for: $0) }
    }

    /// The whole flat array of a translation, loading it on first use.
    public func verses(of id: String) throws -> [String] {
        guard let info = registry[id] else { throw QuranDataError.unknownTranslation(id) }
        return try load(id: info.id, file: info.file)
    }

    /// Drops the cached arrays. The reader calls this on a memory warning.
    public func purge() {
        lock.lock()
        defer { lock.unlock() }
        texts.removeAll()
    }

    private func load(id: String, file: String) throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = texts[id] {
            return cached
        }
        let verses = try locator.decode([String].self, from: file)
        guard verses.count == SurahIndex.totalAyat else {
            throw QuranDataError.wrongVerseCount(id: id, expected: SurahIndex.totalAyat, actual: verses.count)
        }
        texts[id] = verses
        return verses
    }
}
