import Foundation
import QuranData
@testable import StudyContent
import Testing

// These run against `Content/` exactly as `sync-study-content.mjs --prune` leaves it: the
// pipeline's output is the source of truth, so a failure here means either the sync was not run
// or the Swift side has drifted from what `Tools/content-gen` writes.

/// The Unicode blocks the content rules mean by "Arabic script".
private let arabicBlocks: [ClosedRange<UInt32>] = [
    0x0600 ... 0x06FF, 0x0750 ... 0x077F, 0xFB50 ... 0xFDFF, 0xFE70 ... 0xFEFF,
]

private extension String {
    var containsArabicScript: Bool {
        unicodeScalars.contains { scalar in arabicBlocks.contains { $0.contains(scalar.value) } }
    }
}

@Test("Every synced shard decodes in the assembler's shape, filed under its own surah")
func syncedShardsAreWellFormed() throws {
    let surahs = try syncedSurahs()
    #expect(!surahs.isEmpty, "Content/study has no shards — run sync-study-content.mjs --prune")
    let ayahCounts = try bundledSurahs()

    for (number, shard) in try zip(surahs, syncedShards()) {
        #expect(shard.surah == number, "surah_\(number) is filed as surah \(shard.surah)")
        #expect(!shard.units.isEmpty, "surah \(number) has an empty shard")
        #expect(shard.promptVersion == "p1", "surah \(number) was generated under '\(shard.promptVersion)'")
        #expect(!shard.generatedAt.isEmpty)
        #expect(shard.keys.count == shard.units.count, "surah \(number) repeats a unit key")

        var next = 0
        for unit in shard.units {
            #expect(unit.surah == number, "\(unit.key) is filed under the wrong surah")
            #expect(unit.passage.key == unit.key, "\(unit.key) disagrees with its own surah/start/end")
            #expect(unit.start > next, "surah \(number) units overlap or are unsorted at \(unit.key)")
            #expect(unit.end <= ayahCounts[number - 1].ayahCount, "\(unit.key) runs past the end of its surah")
            next = unit.end
        }
    }
}

@Test("Every synced unit fills all nine Deep Study sections")
func syncedUnitsAreComplete() throws {
    let studies = try syncedStudies()
    #expect(studies.count >= 40, "only \(studies.count) units are synced")
    for unit in studies {
        #expect(unit.populatedSections == StudySection.displayOrder, "\(unit.key) leaves a section empty")
        #expect(!unit.title.isEmpty)
        #expect(!unit.theme.isEmpty)
        #expect(!unit.themeId.isEmpty)
        #expect(StudyTier.allCases.contains(unit.tier))
        #expect(unit.meaning.count > 200, "\(unit.key) meaning is too thin")
        #expect(unit.keyTerms.count >= 3, "\(unit.key) needs at least three key terms")
        #expect(unit.keyTerms.allSatisfy { !$0.arabic.isEmpty && !$0.gloss.isEmpty && !$0.note.isEmpty })
        #expect(unit.crossReferences.count >= 2, "\(unit.key) needs at least two cross references")
        #expect(!unit.meta.model.isEmpty, "\(unit.key) records no model")
        #expect(unit.meta.promptVersion == "p1", "\(unit.key) records prompt version '\(unit.meta.promptVersion)'")
    }
}

@Test("Everything authored so far is a Discover-tier unit, and the tier is the schema's string")
func syncedUnitsAreDiscoverTier() throws {
    #expect(try syncedStudies().allSatisfy { $0.tier == .discover }, "wave 1 is the Discover slice only")
    // The tier really is read from the string rather than defaulted, and an unrecognised one
    // still decodes rather than failing the shard around it.
    let odd = "{ \"surah\": 9, \"studies\": [\(syntheticUnit(key: "9:1", tier: "gold"))] }"
    let decoded = try JSONDecoder().decode(StudyShard.self, from: Data(odd.utf8))
    #expect(decoded.units.first?.tier == .standard)
}

@Test("Key terms carry Arabic script and the English prose carries none")
func syncedKeyTermsAreArabicScript() throws {
    for unit in try syncedStudies() {
        for term in unit.keyTerms {
            #expect(term.arabic.containsArabicScript, "\(unit.key) key term '\(term.arabic)' is not Arabic script")
            #expect(!term.gloss.containsArabicScript, "\(unit.key) gloss should be English")
            #expect(!term.note.containsArabicScript, "\(unit.key) note should be English")
        }
        for section in StudySection.displayOrder {
            let prose = unit.prose(for: section) ?? ""
            #expect(!prose.containsArabicScript, "\(unit.key) \(section.rawValue) has Arabic script in prose")
        }
        #expect(!unit.title.containsArabicScript)
        #expect(!unit.theme.containsArabicScript)
        #expect(unit.crossReferences.allSatisfy { !$0.why.containsArabicScript })
    }
}

@Test("Every reference in the synced content points at an ayah that exists")
func syncedReferencesAreInBounds() throws {
    let surahs = try bundledSurahs()
    func check(_ key: String, from unit: String) throws {
        let parsed = try #require(PassageRef(key: key), "\(unit) has an unparseable reference \(key)")
        #expect((1 ... 114).contains(parsed.surah), "\(unit) points at no such surah in \(key)")
        #expect(
            parsed.end <= surahs[parsed.surah - 1].ayahCount,
            "\(unit) reference \(key) runs past the end of its surah"
        )
    }
    for unit in try syncedStudies() {
        try check(unit.key, from: unit.key)
        for reference in unit.crossReferences {
            try check(reference.ref, from: unit.key)
        }
        for reference in unit.exploreFurther {
            try check(reference, from: unit.key)
        }
        #expect(!unit.exploreFurther.contains(unit.key), "\(unit.key) links to itself")
    }
}

@Test("passages.json segments the whole Quran, authored or not")
func passagesCoverTheWholeQuran() throws {
    let index = try bundledPassageIndex()
    let surahs = try bundledSurahs()
    let total = surahs.reduce(0) { $0 + $1.ayahCount }
    #expect(total == 6236)
    #expect(index.units.count == total, "passages.json maps \(index.units.count) of \(total) ayat")
    #expect(index.coveredSurahs == Set(1 ... 114))
    #expect(index.unitKeys.count < total, "the segmentation should group ayat into fewer units")
    #expect(index.unitKeys.count >= 3000)

    // Every ayah of every unit maps back to that unit, and every unit key is a real passage.
    for key in index.unitKeys {
        let passage = try #require(PassageRef(key: key), "\(key) is not a passage key")
        #expect(passage.end <= surahs[passage.surah - 1].ayahCount, "unit \(key) runs past its surah")
        for verse in passage.verses where index.unitKey(for: verse) != key {
            Issue.record("\(verse.key) does not map back to \(key)")
        }
    }

    // The file carries no shard table, so paths come from the convention.
    #expect(index.shards.isEmpty)
    #expect(index.shardPath(surah: 2) == "study/surah_002.json")
    #expect(index.unitKey(for: VerseRef(surah: 1, ayah: 6)) == "1:1-7")
    #expect(index.unitKey(for: VerseRef(surah: 2, ayah: 255)) == "2:255")
    #expect(index.unitKey(for: VerseRef(surah: 114, ayah: 1)) == "114:1-6")
}

@Test("Every authored unit is a unit the segmentation defines")
func syncedStudiesAgreeWithPassages() throws {
    let index = try bundledPassageIndex()
    for unit in try syncedStudies() {
        #expect(index.unitKeys.contains(unit.key), "\(unit.key) is not a unit in passages.json")
        for verse in unit.verses where index.unitKey(for: verse) != unit.key {
            Issue.record("\(verse.key) is not mapped to \(unit.key)")
        }
    }
}

@Test("A unit that names the Prophet carries the honorific, spelled the one way")
func honorificIsConsistent() throws {
    // `validate.mjs` applies this per unit, over all its prose at once: the first naming of the
    // Prophet is followed by "(peace be upon him)", and that is the only spelling used.
    for unit in try syncedStudies() {
        let prose = StudySection.displayOrder.compactMap { unit.prose(for: $0) }.joined(separator: " ")
            + " " + unit.keyTerms.map(\.note).joined(separator: " ")
            + " " + unit.crossReferences.map(\.why).joined(separator: " ")
        guard prose.contains("Muhammad") else { continue }
        #expect(
            prose.contains("Muhammad (peace be upon him)"),
            "\(unit.key) names Muhammad without the honorific"
        )
        for variant in ["PBUH", "pbuh", "(saw)", "ﷺ", ", peace be upon him,"] {
            #expect(!prose.contains(variant), "\(unit.key) spells the honorific as '\(variant)'")
        }
    }
}
