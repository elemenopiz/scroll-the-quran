import Foundation
import QuranData
@testable import StudyContent
import Testing

/// The Unicode blocks the content rules mean by "Arabic script".
private let arabicBlocks: [ClosedRange<UInt32>] = [
    0x0600 ... 0x06FF, 0x0750 ... 0x077F, 0xFB50 ... 0xFDFF, 0xFE70 ... 0xFEFF,
]

private extension String {
    var containsArabicScript: Bool {
        unicodeScalars.contains { scalar in arabicBlocks.contains { $0.contains(scalar.value) } }
    }
}

private func fixtureShards() throws -> [StudyShard] {
    try fixtureShardPaths.map { try JSONDecoder().decode(StudyShard.self, from: contentData($0)) }
}

@Test("The hand-written shards cover every ayah of their surah exactly once")
func fixturesCoverTheirSurahs() throws {
    let surahs = try bundledSurahs()
    for (number, shard) in try zip(fixtureSurahs, fixtureShards()) {
        #expect(shard.surah == number)
        var covered: [Int] = []
        for unit in shard.units {
            #expect(unit.surah == number, "\(unit.key) is filed under the wrong surah")
            covered.append(contentsOf: unit.start ... unit.end)
        }
        #expect(covered == Array(1 ... surahs[number - 1].ayahCount), "surah \(number) coverage has a gap or overlap")
    }
}

@Test("Every fixture unit fills all nine Deep Study sections")
func fixtureUnitsAreComplete() throws {
    for shard in try fixtureShards() {
        for unit in shard.units {
            #expect(unit.populatedSections == StudySection.displayOrder, "\(unit.key) leaves a section empty")
            #expect(!unit.title.isEmpty)
            #expect(!unit.theme.isEmpty)
            #expect(!unit.themeId.isEmpty)
            #expect(unit.tier >= 1)
            #expect(unit.meaning.count > 200, "\(unit.key) meaning is too thin")
            #expect(unit.keyTerms.count >= 3, "\(unit.key) needs at least three key terms")
            #expect(unit.keyTerms.allSatisfy { !$0.arabic.isEmpty && !$0.gloss.isEmpty && !$0.note.isEmpty })
            #expect(unit.crossReferences.count >= 2, "\(unit.key) needs at least two cross references")
            #expect(unit.meta.reviewed, "\(unit.key) is not marked reviewed")
        }
    }
}

@Test("Key terms carry Arabic script and the English prose carries none")
func fixtureKeyTermsAreArabicScript() throws {
    for shard in try fixtureShards() {
        for unit in shard.units {
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
}

@Test("Every reference in the fixtures points at an ayah that exists")
func fixtureReferencesAreInBounds() throws {
    let surahs = try bundledSurahs()
    func check(_ key: String, from unit: String) throws {
        let parsed = try #require(PassageRef(key: key), "\(unit) has an unparseable reference \(key)")
        #expect((1 ... 114).contains(parsed.surah), "\(unit) points at no such surah in \(key)")
        #expect(parsed.end <= surahs[parsed.surah - 1].ayahCount, "\(unit) reference \(key) runs past the end of its surah")
    }
    for shard in try fixtureShards() {
        for unit in shard.units {
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
}

@Test("passages.json maps every fixture ayah to a unit that exists")
func passageMapIsConsistent() throws {
    let index = try JSONDecoder().decode(PassageIndex.self, from: contentData("study/passages.json"))
    let surahs = try bundledSurahs()

    #expect(index.shards.keys.sorted() == fixtureSurahs)
    #expect(index.coveredSurahs == Set(fixtureSurahs))
    #expect(index.units.count == fixtureSurahs.reduce(0) { $0 + surahs[$1 - 1].ayahCount })

    var known: Set<String> = []
    for surah in fixtureSurahs {
        let path = index.shardPath(surah: surah)
        try known.formUnion(JSONDecoder().decode(StudyShard.self, from: contentData(path)).units.map(\.key))
    }
    #expect(Set(index.units.values) == known)
    #expect(index.unitKey(for: VerseRef(surah: 1, ayah: 6)) == "1:5-7")
    #expect(index.unitKey(for: VerseRef(surah: 103, ayah: 2)) == "103:1-3")
    #expect(index.unitKey(for: VerseRef(surah: 112, ayah: 3)) == "112:1-4")
    #expect(index.shardPath(surah: 103) == "study/surah_103.json")
}

@Test("The honorific is spelled the same way everywhere it appears")
func honorificIsConsistent() throws {
    for shard in try fixtureShards() {
        for unit in shard.units {
            for section in StudySection.displayOrder {
                let prose = unit.prose(for: section) ?? ""
                guard prose.contains("Prophet Muhammad") else { continue }
                #expect(
                    prose.contains("the Prophet Muhammad, peace be upon him"),
                    "\(unit.key) \(section.rawValue) names the Prophet without the honorific"
                )
            }
        }
    }
}
