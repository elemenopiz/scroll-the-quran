import Foundation
import QuranData
import UserState

/// One day's ayah, resolved from the bundled content. Shared by the widget extension and
/// by the app (which renders `--screenshot widget-gallery` from the same views).
public struct VerseWidgetContent: Equatable, Sendable {
    /// The verse being shown.
    public let verse: VerseRef
    /// `"Al-Baqarah 2:255"`.
    public let reference: String
    /// The muted Arabic Uthmani line. Nil when the Arabic edition is missing.
    public let arabic: String?
    /// The English translation — the reading text.
    public let english: String

    public init(verse: VerseRef, reference: String, arabic: String?, english: String) {
        self.verse = verse
        self.reference = reference
        self.arabic = arabic
        self.english = english
    }

    /// The fixture the previews and the gallery use when the bundle is unreachable.
    public static let placeholder = VerseWidgetContent(
        verse: VerseRef(surah: 1, ayah: 1),
        reference: "Al-Fatiha 1:1",
        arabic: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
        english: "In the name of God, the Gracious, the Merciful."
    )

    /// The deep link a tap follows: `scrollthequran://verse/2/255`.
    public var url: URL? {
        URL(string: "scrollthequran://verse/\(verse.surah)/\(verse.ayah)")
    }
}

/// Picks the day's ayah and reads its text out of the app bundle.
///
/// The verse is `discover.json`'s item at `dayOfYear % count` — the same file the Discover
/// feed is built from, so the widget and the app are never quoting different content — unless
/// the reader has pinned one with `Prefs.widgetVerseRef`, which is written into the App Group
/// by the app and read back here.
///
/// Nothing here touches the network, and every failure degrades to `placeholder` rather than
/// blanking the widget.
public enum VerseWidgetSource {
    /// The shape of `Content/discover.json` this needs. Decoded locally rather than through
    /// `StudyContent` so the extension links one small module less.
    private struct FeedFile: Decodable {
        struct Item: Decodable {
            let surah: Int
            let start: Int
        }

        let items: [Item]
    }

    /// The pinned verse, if the reader chose one, otherwise the day's feed pick.
    public static func verse(
        on date: Date,
        calendar: Calendar = .current,
        pinned: VerseRef? = nil,
        items: [VerseRef]? = nil
    ) -> VerseRef? {
        if let pinned {
            return pinned
        }
        let pool = items ?? feedVerses()
        guard !pool.isEmpty else { return nil }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[((dayOfYear % pool.count) + pool.count) % pool.count]
    }

    /// Every feed item's opening ayah, in file order. Loaded once per process.
    public static func feedVerses(locator: ContentLocator = .shared) -> [VerseRef] {
        if let cached = cache {
            return cached
        }
        let loaded: [VerseRef] = if let file = try? locator.decode(FeedFile.self, from: "discover.json") {
            file.items.map { VerseRef(surah: $0.surah, ayah: $0.start) }
        } else {
            []
        }
        cache = loaded
        return loaded
    }

    private nonisolated(unsafe) static var cache: [VerseRef]?

    /// The full entry for a date: pick the verse, then read its text.
    public static func content(
        on date: Date,
        calendar: Calendar = .current,
        pinned: VerseRef? = nil,
        translations: TranslationStore? = nil
    ) -> VerseWidgetContent {
        guard let verse = verse(on: date, calendar: calendar, pinned: pinned ?? pinnedVerse()),
              let store = translations ?? sharedTranslations(),
              let english = store.text(for: verse),
              let surah = store.index.surah(verse.surah)
        else { return .placeholder }

        return VerseWidgetContent(
            verse: verse,
            reference: "\(surah.name) \(verse.surah):\(verse.ayah)",
            arabic: store.arabic(for: verse).map { ArabicText.stripBasmala($0, verse: verse) },
            english: english
        )
    }

    /// The reader's pinned verse, written by the app into the shared App Group container.
    ///
    /// `prefs.json` is read directly rather than through `UserStore`: the timeline provider
    /// is not on the main actor, and this is one small file, read-only, with no need for the
    /// store's debounced writer. `UserStore` writes it atomically (temp file plus rename), so
    /// a read can never see a half-written file.
    public static func pinnedVerse(
        directory: URL = UserStateLocation.defaultDirectory()
    ) -> VerseRef? {
        let url = directory.appendingPathComponent(UserStateFile.prefs.filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Prefs.self, from: data))?.widgetVerseRef
    }

    /// One store for the life of the widget process; a translation is ~800 KB of strings.
    private static func sharedTranslations() -> TranslationStore? {
        if let store = translationCache {
            return store
        }
        let store = try? TranslationStore(locator: .shared)
        translationCache = store
        return store
    }

    private nonisolated(unsafe) static var translationCache: TranslationStore?
}
