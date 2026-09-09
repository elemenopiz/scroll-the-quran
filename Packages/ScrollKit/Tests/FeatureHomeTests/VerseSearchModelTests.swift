@testable import FeatureHome
import Foundation
import QuranData
import Testing

@MainActor
@Suite("Verse search wheel")
struct VerseSearchModelTests {
    private func model(_ mode: VerseSearchMode = .advanced) throws -> VerseSearchModel {
        try VerseSearchModel(index: HomeTestContent.surahIndex(), mode: mode)
    }

    /// A wheel only ever changes one column at a time, so the tests drive it that way:
    /// the surah column first, then the ayah columns against the new surah's options.
    private func spin(_ model: VerseSearchModel, surah: Int, ayah: Int? = nil, to: Int? = nil) {
        model.selection = [surah - 1] + Array(model.selection.dropFirst())
        if let ayah {
            var next = model.selection
            next[1] = ayah - 1
            model.selection = next
        }
        if let to, model.selection.count > 2 {
            var next = model.selection
            next[2] = to - model.ayah
            model.selection = next
        }
    }

    @Test("Basic has two columns, Advanced three")
    func columnCounts() throws {
        #expect(try model(.basic).columnOptions.count == 2)
        #expect(try model(.advanced).columnOptions.count == 3)
    }

    @Test("the ayah column is exactly as long as the selected surah")
    func ayahColumnFollowsSurah() throws {
        let model = try model()
        spin(model, surah: 2)
        #expect(model.surah == 2)
        #expect(model.ayahNumbers.count == 286)
        spin(model, surah: 114)
        #expect(model.ayahNumbers.count == 6)
    }

    @Test("changing surah resets the ayah instead of keeping an out-of-range one")
    func surahChangeResetsAyah() throws {
        let model = try model()
        spin(model, surah: 2, ayah: 255)
        #expect(model.verse == VerseRef(surah: 2, ayah: 255))
        spin(model, surah: 114)
        #expect(model.verse == VerseRef(surah: 114, ayah: 1))
    }

    @Test("the last-ayah column starts at the first ayah, so a range never inverts")
    func rangeNeverInverts() throws {
        let model = try model()
        spin(model, surah: 2, ayah: 255)
        #expect(model.toAyahNumbers.first == "255")
        spin(model, surah: 2, ayah: 255, to: 257)
        #expect(model.passage.key == "2:255-257")
        // The last column lists ayat from the first one upward, so moving the first ayah
        // carries the range with it rather than letting it invert.
        var next = model.selection
        next[1] = 259 // ayah 260, third column left where it was
        model.selection = next
        #expect(model.passage.key == "2:260-262")
        #expect(model.toAyah >= model.ayah)
        // Pushing the first ayah to the end of the surah pins the last ayah to it.
        next = model.selection
        next[1] = 285 // ayah 286, the last of Al-Baqarah
        model.selection = next
        #expect(model.passage.key == "2:286")
    }

    @Test("Basic collapses the passage to a single ayah")
    func basicIsOneAyah() throws {
        let model = try model(.advanced)
        spin(model, surah: 2, ayah: 255, to: 257)
        #expect(model.studyKey == "2:255-257")
        model.mode = .basic
        #expect(model.studyKey == "2:255")
        #expect(model.selection.count == 2)
    }

    @Test("an out-of-range selection is clamped rather than trapped")
    func clamping() throws {
        let model = try model()
        model.selection = [9999, 9999, 9999]
        #expect(model.surah == 114)
        #expect(model.ayah == 1)
        #expect(model.toAyah == 1)
        model.selection = [-3, -3, -3]
        #expect(model.surah == 1)
        #expect(model.ayah == 1)
    }

    @Test("an ayah index past the end of the surah clamps to its last ayah")
    func ayahClampsWithinSurah() throws {
        let model = try model()
        spin(model, surah: 114)
        model.selection = [113, 400, 0]
        #expect(model.verse == VerseRef(surah: 114, ayah: 6))
    }

    @Test("the reference label names the surah")
    func referenceLabel() throws {
        let model = try model()
        spin(model, surah: 2, ayah: 255)
        #expect(model.referenceLabel == "Al-Baqarah 2:255")
        spin(model, surah: 2, ayah: 255, to: 257)
        #expect(model.referenceLabel == "Al-Baqarah 2:255-257")
    }
}
