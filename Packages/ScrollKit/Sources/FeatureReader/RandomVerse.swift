import Foundation
import QuranData

/// The dice in the reader toolbar: a verse picked **uniformly over all 6,236 ayat**, not
/// uniformly over surahs (which would make Al-Kawthar as likely as Al-Baqarah) and not
/// uniformly over a curated list.
public enum RandomVerse {
    /// A global index in `0 ..< total`, uniform.
    public static func globalIndex(
        using generator: inout some RandomNumberGenerator,
        total: Int = SurahIndex.totalAyat
    ) -> Int {
        guard total > 0 else { return 0 }
        return Int.random(in: 0 ..< total, using: &generator)
    }

    /// A uniformly random ayah. Nil only when the index is empty.
    public static func pick(
        in index: SurahIndex,
        using generator: inout some RandomNumberGenerator
    ) -> VerseRef? {
        let total = index.surahs.reduce(0) { $0 + $1.ayahCount }
        guard total > 0 else { return nil }
        return index.verse(atGlobalIndex: globalIndex(using: &generator, total: total))
    }

    /// The live call site.
    public static func pick(in index: SurahIndex) -> VerseRef? {
        var generator = SystemRandomNumberGenerator()
        return pick(in: index, using: &generator)
    }
}
