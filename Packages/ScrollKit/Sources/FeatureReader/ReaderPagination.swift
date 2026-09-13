import Foundation
import QuranData

/// Builds the page list for one surah. Pure: it takes the text it needs as closures, so the
/// whole reader page model is testable without a bundle, a store or a view.
public enum ReaderPagination {
    /// Text lookups the reader needs, so the builder does not depend on `TranslationStore`.
    public struct Source {
        public let arabic: (VerseRef) -> String?
        public let english: (VerseRef) -> String?

        public init(
            arabic: @escaping (VerseRef) -> String?,
            english: @escaping (VerseRef) -> String?
        ) {
            self.arabic = arabic
            self.english = english
        }
    }

    /// Every page of `surah`, in reading order: the opening page, one or more pages per ayah,
    /// then the handoff sentinel when another surah follows.
    ///
    /// - The Arabic of ayah 1 has any Bismillah prefix removed (`ArabicText.stripBasmala`);
    ///   the Bismillah itself is shown once, on the opening page.
    /// - A long ayah is split by `VersePaginator`; only the first slice carries the Arabic,
    ///   and every slice of a split ayah is captioned `"(n/total)"`.
    public static func pages(
        for surah: Surah,
        source: Source,
        maxWords: Int = VersePaginator.defaultMaxWords,
        hasFollowingSurah: Bool = true
    ) -> [ReaderPage] {
        var pages: [ReaderPage] = [opening(for: surah, source: source)]

        for ayah in 1 ... max(1, surah.ayahCount) {
            let verse = VerseRef(surah: surah.number, ayah: ayah)
            guard let english = source.english(verse), !english.isEmpty else { continue }
            let arabic = source.arabic(verse).map { ArabicText.stripBasmala($0, verse: verse) }
            let tier = VerseSizeTier(text: english)
            let slices = VersePaginator.pages(text: english, maxWords: maxWords)
            for (offset, slice) in slices.enumerated() {
                pages.append(
                    ReaderPage(
                        id: ReaderPageID(surah: surah.number, ayah: ayah, part: offset),
                        kind: .verse,
                        arabic: offset == 0 ? arabic : nil,
                        english: slice,
                        reference: surah.reference(for: ayah),
                        caption: VersePaginator.caption(page: offset + 1, of: slices.count),
                        tier: tier,
                        // Phase 4n: the card is on **every** verse page, continuation slices
                        // included, as the original is — it is the verse menu's tap target,
                        // not a decoration on the surah's first page. The handoff sentinel
                        // keeps none: it is on screen for one frame and has no ayah to act on.
                        showsLogoCard: true
                    )
                )
            }
        }

        if hasFollowingSurah {
            pages.append(handoff(for: surah))
        }
        return pages
    }

    /// The surah's page 0: the logo card, and for the 112 surahs that open with one, the
    /// Bismillah as the muted Arabic line above its English.
    public static func opening(for surah: Surah, source: Source) -> ReaderPage {
        let opensWithBasmala = ArabicText.expectsBasmalaPrefix(surah: surah.number, ayah: 1)
        return ReaderPage(
            id: .opening(surah: surah.number),
            kind: .opening,
            arabic: opensWithBasmala ? ArabicText.basmala : nil,
            english: opensWithBasmala ? basmalaEnglish(source: source) : "",
            reference: surah.name,
            tier: .large,
            showsLogoCard: true
        )
    }

    /// The trailing page. Scrolling onto it is what triggers the move to the next surah.
    public static func handoff(for surah: Surah) -> ReaderPage {
        ReaderPage(
            id: ReaderPageID(surah: surah.number, ayah: surah.ayahCount + 1, part: 0),
            kind: .handoff,
            arabic: nil,
            english: "",
            reference: surah.name,
            tier: .large
        )
    }

    /// The Bismillah's English, taken from the selected translation's 1:1 so the wording
    /// follows whichever translation the reader is on, with the canonical text as a fallback.
    static func basmalaEnglish(source: Source) -> String {
        let fromTranslation = source.english(VerseRef(surah: 1, ayah: 1))
        guard let fromTranslation, !fromTranslation.isEmpty else { return ArabicText.basmalaEnglish }
        return fromTranslation
    }
}

public extension ReaderPagination.Source {
    /// The live source: the bundled Arabic and the store's selected translation.
    static func store(_ store: TranslationStore) -> Self {
        // The store caches whole translations, so these closures are cheap after the first hit.
        let selected = store.selectedID
        return ReaderPagination.Source(
            arabic: { [weak store] verse in store?.arabic(for: verse) },
            english: { [weak store] verse in store?.text(for: verse, translation: selected) }
        )
    }
}
