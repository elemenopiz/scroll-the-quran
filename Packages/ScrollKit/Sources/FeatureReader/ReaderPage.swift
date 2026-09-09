import DesignSystem
import Foundation
import QuranData

/// Identity of one reader page. The reader pages **per surah**, so a page is addressed by
/// its surah, the ayah it shows, and which continuation slice of that ayah it is.
///
/// Two ayah numbers are reserved: `0` is the surah's opening page (the logo card and, where
/// the surah has one, the Bismillah), and `ayahCount + 1` is the trailing sentinel that hands
/// over to the next surah.
public struct ReaderPageID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let surah: Int
    public let ayah: Int
    /// 0-based continuation slice inside the ayah (`VersePaginator`).
    public let part: Int

    public init(surah: Int, ayah: Int, part: Int = 0) {
        self.surah = surah
        self.ayah = ayah
        self.part = part
    }

    public static func opening(surah: Int) -> ReaderPageID {
        ReaderPageID(surah: surah, ayah: 0, part: 0)
    }

    public var verse: VerseRef? {
        ayah >= 1 ? VerseRef(surah: surah, ayah: ayah) : nil
    }

    public var description: String {
        "\(surah):\(ayah)#\(part)"
    }
}

/// What a page is for. The three kinds share one layout — logo card, verse block, reference
/// line — so the reader can page between them without any change of shape.
public enum ReaderPageKind: String, Hashable, Sendable {
    /// Page 0: the logo card, plus the Bismillah for the 112 surahs that open with one.
    case opening
    /// An ayah, or one continuation slice of a long one.
    case verse
    /// The last page: scrolling onto it advances to the next surah.
    case handoff
}

/// One rendered page of the reader.
public struct ReaderPage: Identifiable, Hashable, Sendable {
    public let id: ReaderPageID
    public let kind: ReaderPageKind
    /// The muted Arabic line (CLAUDE.md rule 5). Only ever on the first slice of an ayah:
    /// a continuation page carries English only, so the Arabic is never shown twice.
    public let arabic: String?
    public let english: String
    /// The line under the verse: `"Al-Baqarah 2:255"`, or the surah name on an opening page.
    public let reference: String
    /// `"(2/3)"` when the ayah was split, nil otherwise.
    public let caption: String?
    /// Drives the type ramp; always the tier of the *whole* ayah, not of this slice.
    public let tier: VerseSizeTier
    public let showsLogoCard: Bool

    public init(
        id: ReaderPageID,
        kind: ReaderPageKind,
        arabic: String?,
        english: String,
        reference: String,
        caption: String? = nil,
        tier: VerseSizeTier = .large,
        showsLogoCard: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.arabic = arabic
        self.english = english
        self.reference = reference
        self.caption = caption
        self.tier = tier
        self.showsLogoCard = showsLogoCard
    }

    /// The ayah this page belongs to, or nil for the opening page and the handoff sentinel.
    public var verse: VerseRef? {
        kind == .verse ? id.verse : nil
    }

    /// Which rail segment lights up while this page is showing. The opening page borrows
    /// ayah 1's segment, which is what the reference capture shows.
    public var railAyah: Int {
        switch kind {
        case .opening: 1
        case .verse: id.ayah
        case .handoff: max(1, id.ayah - 1)
        }
    }

    /// The verse the reader would share, save or annotate from here.
    public var actionableVerse: VerseRef? {
        switch kind {
        case .verse: id.verse
        case .opening, .handoff: nil
        }
    }
}

/// English point size per size tier. `VerseText` owns the actual numbers (measured from the
/// references); this is only the tier → size mapping, so the reader never hard-codes a size.
public enum ReaderTypeRamp {
    /// 40 words or fewer read at the full 23 pt reader size; 41–90 step down to the Deep Study
    /// 20 pt; anything longer takes the Discover 16 pt so a 110-word slice still fits a page.
    public static func size(for tier: VerseSizeTier) -> VerseText.Size {
        switch tier {
        case .large: .reader
        case .medium: .deepStudy
        case .small: .discover
        }
    }

    /// The English point size a tier resolves to.
    public static func englishPointSize(for tier: VerseSizeTier) -> CGFloat {
        size(for: tier).english
    }
}
