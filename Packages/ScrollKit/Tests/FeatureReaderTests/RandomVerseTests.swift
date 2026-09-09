import Foundation
@testable import FeatureReader
import QuranData
import Testing

@Suite("The dice picks uniformly over all 6,236 ayat")
struct RandomVerseTests {
    @Test("every draw is a real ayah, and long surahs come up in proportion to their length")
    func drawsAreValidAndProportional() throws {
        let index = try TestContent.index()
        var generator = SeededGenerator(seed: 0xC0FF_EE12)
        var bySurah: [Int: Int] = [:]
        let draws = 60_000

        for _ in 0 ..< draws {
            let verse = try #require(RandomVerse.pick(in: index, using: &generator))
            #expect(index.contains(verse))
            bySurah[verse.surah, default: 0] += 1
        }

        // Al-Baqarah is 286/6236 = 4.59 % of the Quran; expect that share within 15 % relative.
        let baqarah = try #require(index.surah(2))
        let expected = Double(draws) * Double(baqarah.ayahCount) / Double(SurahIndex.totalAyat)
        let observed = Double(bySurah[2] ?? 0)
        #expect(abs(observed - expected) / expected < 0.15, "surah 2 drawn \(observed) times, expected ~\(expected)")

        // Every surah should have shown up at least once in 60k draws; the rarest is 3 ayat.
        #expect(bySurah.count == SurahIndex.surahCount)
    }

    @Test("the global index is uniform across the range")
    func globalIndexIsUniform() {
        var generator = SeededGenerator(seed: 99)
        let buckets = 16
        let draws = 160_000
        var counts = Array(repeating: 0, count: buckets)
        for _ in 0 ..< draws {
            let index = RandomVerse.globalIndex(using: &generator)
            #expect(index >= 0 && index < SurahIndex.totalAyat)
            counts[min(buckets - 1, index * buckets / SurahIndex.totalAyat)] += 1
        }
        let expected = Double(draws) / Double(buckets)
        for count in counts {
            #expect(abs(Double(count) - expected) / expected < 0.06)
        }
    }

    @Test("the first and last ayah of the Quran are both reachable")
    func endsAreReachable() throws {
        let index = try TestContent.index()
        var generator = SeededGenerator(seed: 7)
        var sawFirst = false
        var sawLast = false
        for _ in 0 ..< 400_000 where !(sawFirst && sawLast) {
            guard let verse = RandomVerse.pick(in: index, using: &generator) else { continue }
            if verse == VerseRef(surah: 1, ayah: 1) { sawFirst = true }
            if verse == VerseRef(surah: 114, ayah: 6) { sawLast = true }
        }
        #expect(sawFirst)
        #expect(sawLast)
    }

    @Test("an empty index yields nothing rather than crashing")
    func emptyIndexIsSafe() throws {
        let empty = try SurahIndex(surahs: [])
        var generator = SeededGenerator(seed: 1)
        #expect(RandomVerse.pick(in: empty, using: &generator) == nil)
    }
}
