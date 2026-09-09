import Foundation
import QuranData
import Testing
@testable import UserState

@Suite("ReadProgress and BitSet6236")
struct ReadProgressTests {
    @Test("The bitset covers exactly the 6,236 ayat in 98 words")
    func bitsetCoversTheWholeQuran() {
        #expect(BitSet6236.bitCount == 6236)
        #expect(BitSet6236.wordCount == 98)
        #expect(ReadProgress.totalVerses == 6236)
    }

    @Test("Scattered bits round-trip through base64 JSON, boundaries included")
    func bitsetRoundTripsThroughJSON() throws {
        var progress = ReadProgress()
        let marked = [0, 1, 63, 64, 261, 4095, 6234, 6235]
        for index in marked {
            progress.markRead(globalIndex: index)
        }

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(ReadProgress.self, from: data)
        #expect(decoded.bits.setIndices == marked)
        #expect(decoded == progress)
        // 98 words = 784 bytes, so the file is a constant ~1 KB however much is read.
        #expect(progress.bits.data.count == 784)
    }

    @Test("Out-of-range indices are ignored rather than trapping")
    func outOfRangeIndicesAreIgnored() {
        var progress = ReadProgress()
        let below = progress.markRead(globalIndex: -1)
        let justPastTheEnd = progress.markRead(globalIndex: 6236)
        let wildlyPastTheEnd = progress.markRead(globalIndex: 999_999)
        #expect(below == false)
        #expect(justPastTheEnd == false)
        #expect(wildlyPastTheEnd == false)
        #expect(progress.isRead(globalIndex: -1) == false)
        #expect(progress.readCount == 0)
    }

    @Test("Marking the same ayah twice counts once")
    func markingTwiceCountsOnce() {
        var progress = ReadProgress()
        let firstMark = progress.markRead(globalIndex: 261)
        let secondMark = progress.markRead(globalIndex: 261)
        #expect(firstMark)
        #expect(secondMark == false)
        #expect(progress.readCount == 1)
    }

    @Test("A verse is marked through its surah's span, and only its own surah's")
    func marksThroughTheSurahSpan() {
        var progress = ReadProgress()
        // Ayat al-Kursi: 2:255 is global index 261.
        progress.markRead(VerseRef(surah: 2, ayah: 255), in: .alBaqarah)
        #expect(progress.isRead(globalIndex: 261))
        #expect(progress.isRead(VerseRef(surah: 2, ayah: 255), in: .alBaqarah))
        let otherSurah = progress.markRead(VerseRef(surah: 3, ayah: 1), in: .alBaqarah)
        let pastTheLastAyah = progress.markRead(VerseRef(surah: 2, ayah: 287), in: .alBaqarah)
        #expect(otherSurah == false)
        #expect(pastTheLastAyah == false)
        #expect(progress.readCount == 1)
    }

    @Test("Nothing read reads 0%, one ayah reads <1%")
    func percentLabelUsesTheLessThanOneRule() {
        var progress = ReadProgress()
        #expect(progress.percentLabel == "0%")
        progress.markRead(globalIndex: 0)
        #expect(progress.percentLabel == "<1%")
        #expect(progress.percent > 0)
    }

    @Test("The <1% label holds right up to one percent of the Quran")
    func percentLabelBoundaryAtOnePercent() {
        var progress = ReadProgress()
        for index in 0 ..< 62 {
            progress.markRead(globalIndex: index)
        }
        #expect(progress.percentLabel == "<1%", "62 of 6,236 is 0.99%")
        progress.markRead(globalIndex: 62)
        #expect(progress.percentLabel == "1%", "63 of 6,236 is 1.01%")
    }

    @Test("Percentages round to whole numbers and stop at 99% until the last ayah")
    func percentLabelRoundsAndCapsBeforeCompletion() {
        var progress = ReadProgress()
        for index in 0 ..< 3118 {
            progress.markRead(globalIndex: index)
        }
        #expect(progress.percentLabel == "50%")

        for index in 3118 ..< 6235 {
            progress.markRead(globalIndex: index)
        }
        #expect(progress.readCount == 6235)
        #expect(progress.percentLabel == "99%", "99.98% must not print as 100% while an ayah is unread")

        progress.markRead(globalIndex: 6235)
        #expect(progress.percentLabel == "100%")
    }

    @Test("Home's verse count line reads 'n of 6,236 verses'")
    func versesReadLabelIsGrouped() {
        var progress = ReadProgress()
        #expect(progress.versesReadLabel == "0 of 6,236 verses")
        for index in 0 ..< 1234 {
            progress.markRead(globalIndex: index)
        }
        #expect(progress.versesReadLabel == "1,234 of 6,236 verses")
    }

    @Test("A surah counts as complete only when every one of its ayat is read")
    func surahCompletion() {
        var progress = ReadProgress()
        let fatiha = SurahSpan.alFatiha
        for ayah in 1 ... 6 {
            progress.markRead(VerseRef(surah: 1, ayah: ayah), in: fatiha)
        }
        #expect(progress.readCount(in: fatiha) == 6)
        #expect(progress.isComplete(fatiha) == false)
        #expect(abs(progress.completion(in: fatiha) - 6.0 / 7.0) < 0.0001)

        progress.markRead(VerseRef(surah: 1, ayah: 7), in: fatiha)
        #expect(progress.isComplete(fatiha))
        #expect(progress.completion(in: fatiha) == 1)
        #expect(progress.completedSurahs(among: [fatiha, .alBaqarah]) == [1])
    }

    @Test("Marking a whole surah read does not spill into the next one")
    func markingAWholeSurahStaysInBounds() {
        var progress = ReadProgress()
        progress.markReadAll(in: .alFatiha)
        #expect(progress.readCount == 7)
        #expect(progress.readCount(in: .alBaqarah) == 0)
        #expect(progress.isRead(globalIndex: 7) == false)
    }

    @Test("Unmarking and resetting clear the bits again")
    func unmarkAndReset() {
        var progress = ReadProgress()
        progress.markReadAll(in: .alFatiha)
        let unmarked = progress.markUnread(globalIndex: 3)
        #expect(unmarked)
        #expect(progress.readCount == 6)
        progress.reset()
        #expect(progress.readCount == 0)
        #expect(progress.bits.isEmpty)
    }

    @Test("A short or oversized bits blob decodes without crashing")
    func tolerantOfBadlySizedData() throws {
        let short = BitSet6236(data: Data([0b0000_0101]))
        #expect(short.setIndices == [0, 2])
        let oversized = BitSet6236(data: Data(repeating: 0xFF, count: 900))
        #expect(oversized.count == 6236, "bits past the last ayah are dropped")
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(BitSet6236.self, from: Data("\"not base64!!\"".utf8))
        }
    }

    @Test("A span maps ayat to global indices and rejects the ones it does not own")
    func surahSpanIndexMaths() {
        let baqarah = SurahSpan.alBaqarah
        #expect(baqarah.globalIndex(ofAyah: 1) == 7)
        #expect(baqarah.globalIndex(ofAyah: 255) == 261)
        #expect(baqarah.globalIndex(ofAyah: 0) == nil)
        #expect(baqarah.globalIndex(ofAyah: 287) == nil)
        #expect(baqarah.globalIndex(of: VerseRef(surah: 1, ayah: 1)) == nil)
        #expect(baqarah.range == 7 ..< 293)
    }
}
