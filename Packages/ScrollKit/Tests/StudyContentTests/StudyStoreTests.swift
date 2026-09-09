import Foundation
import QuranData
@testable import StudyContent
import Testing

@Test("Every ayah of every fixture surah resolves to a study")
func everyFixtureAyahResolves() throws {
    let store = try bundledStore()
    let surahs = try bundledSurahs()
    for number in fixtureSurahs {
        let count = surahs[number - 1].ayahCount
        for ayah in 1 ... count {
            let verse = VerseRef(surah: number, ayah: ayah)
            #expect(store.hasStudy(for: verse), "\(verse.key) has no unit in passages.json")
            let study = try #require(store.study(for: verse), "\(verse.key) resolves to no study")
            #expect(study.surah == number)
            #expect(study.start <= ayah && ayah <= study.end, "\(verse.key) is outside \(study.key)")
            #expect(!study.title.isEmpty)
            #expect(!study.keyTerms.isEmpty)
        }
    }
}

@Test("The fixture units tile their surah exactly, with no gap and no overlap")
func fixtureUnitsTileTheirSurah() throws {
    let store = try bundledStore()
    let surahs = try bundledSurahs()
    for number in fixtureSurahs {
        let units = store.studies(inSurah: number)
        #expect(!units.isEmpty)
        var next = 1
        for unit in units {
            #expect(unit.start == next, "surah \(number) jumps at \(unit.key)")
            next = unit.end + 1
        }
        #expect(next - 1 == surahs[number - 1].ayahCount, "surah \(number) stops short")
    }
}

@Test("A surah with no shard resolves to nil instead of crashing, and is not retried")
func missingSurahsResolveToNil() throws {
    let store = try bundledStore()
    for verse in [VerseRef(surah: 2, ayah: 255), VerseRef(surah: 18, ayah: 10), VerseRef(surah: 114, ayah: 1)] {
        #expect(!store.hasStudy(for: verse))
        #expect(store.study(for: verse) == nil)
    }
    #expect(store.study(forKey: "2:255") == nil)
    #expect(store.study(forKey: "not a key") == nil)
    // Nothing above should have pulled a shard off disk.
    #expect(store.shardLoadCount == 0)
    #expect(store.cachedSurahs.isEmpty)
}

@Test("An ayah mapped to a unit whose shard file is missing still resolves to nil")
func missingShardFileIsSurvivable() throws {
    let loader = InMemoryContentLoader(json: [
        "study/passages.json": #"{ "shards": { "2": "study/surah_002.json" }, "units": { "2:255": "2:255" } }"#,
    ])
    let store = try StudyStore(loader: loader)
    #expect(store.hasStudy(for: VerseRef(surah: 2, ayah: 255)))
    #expect(store.study(for: VerseRef(surah: 2, ayah: 255)) == nil)
    #expect(store.study(for: VerseRef(surah: 2, ayah: 255)) == nil)
    #expect(store.shardLoadCount == 0)
    // The missing shard is remembered, so the second lookup did not read again.
    #expect(loader.readLog.filter { $0 == "study/surah_002.json" }.count == 1)
}

@Test("hasStudy answers from passages.json without loading any shard")
func hasStudyDoesNotLoadShards() throws {
    let loader = syntheticLoader(surahs: [1, 2, 3])
    let store = try StudyStore(loader: loader)
    loader.resetReadLog()
    for surah in 1 ... 3 {
        #expect(store.hasStudy(for: VerseRef(surah: surah, ayah: 1)))
        #expect(store.containsUnit("\(surah):1"))
    }
    #expect(loader.readLog.isEmpty)
    #expect(store.shardLoadCount == 0)
}

@Test("Shards load lazily and only once while they stay cached")
func shardsLoadOnceWhileCached() throws {
    let loader = syntheticLoader(surahs: [1, 2])
    let store = try StudyStore(loader: loader)
    loader.resetReadLog()
    for _ in 0 ..< 5 {
        #expect(store.study(for: VerseRef(surah: 1, ayah: 1))?.key == "1:1")
    }
    #expect(store.shardLoadCount == 1)
    #expect(loader.readLog == ["study/surah_001.json"])
}

@Test("The shard cache keeps four surahs and evicts the least recently used")
func shardCacheEvictsLeastRecentlyUsed() throws {
    let loader = syntheticLoader(surahs: Array(1 ... 6))
    let store = try StudyStore(loader: loader)
    #expect(StudyStore.shardCacheLimit == 4)

    for surah in 1 ... 4 {
        store.preload(surah: surah)
    }
    #expect(store.cachedSurahs == [1, 2, 3, 4])

    store.preload(surah: 5)
    #expect(store.cachedSurahs == [2, 3, 4, 5], "surah 1 should have been evicted")

    // Touching 3 makes it the most recent, so 2 goes first on the next miss.
    store.preload(surah: 3)
    #expect(store.cachedSurahs == [2, 4, 5, 3])
    store.preload(surah: 6)
    #expect(store.cachedSurahs == [4, 5, 3, 6])

    #expect(store.shardLoadCount == 6)
    // Surah 1 was evicted, so asking again re-reads it.
    #expect(store.study(for: VerseRef(surah: 1, ayah: 1))?.key == "1:1")
    #expect(store.shardLoadCount == 7)
    #expect(store.cachedSurahs == [5, 3, 6, 1])
}

@Test("The cache limit is configurable and still evicts oldest first")
func shardCacheLimitIsConfigurable() throws {
    let store = try StudyStore(loader: syntheticLoader(surahs: Array(1 ... 4)), shardCacheLimit: 2)
    for surah in 1 ... 3 {
        store.preload(surah: surah)
    }
    #expect(store.cachedSurahs == [2, 3])
    store.evictAll()
    #expect(store.cachedSurahs.isEmpty)
}

@Test("study(forKey:) takes unit keys and single ayat inside a unit alike")
func lookupByKeyAcceptsBothShapes() throws {
    let store = try bundledStore()
    #expect(store.study(forKey: "1:5-7")?.title == "Guide us on the straight path")
    #expect(store.study(forKey: "1:6")?.key == "1:5-7")
    #expect(store.study(forKey: "112:1-4")?.themeId == "tawhid")
    #expect(store.study(forKey: "103:1-3")?.surah == 103)
    #expect(store.study(for: PassageRef(surah: 1, start: 2, end: 4))?.key == "1:2-4")
    #expect(store.unitKey(for: VerseRef(surah: 103, ayah: 2)) == "103:1-3")
    // An ayah number past the end of a real shard is a miss, not a crash.
    #expect(store.study(forKey: "1:99") == nil)
}

@Test("passages.json decodes from the bare ayah-to-unit map as well as the wrapped one")
func passageIndexAcceptsBothShapes() throws {
    let bare = #"{ "1:1": "1:1", "1:2": "1:2-4", "version": "ignored" }"#
    let index = try JSONDecoder().decode(PassageIndex.self, from: Data(bare.utf8))
    #expect(index.units.count == 2)
    #expect(index.unitKey(for: VerseRef(surah: 1, ayah: 2)) == "1:2-4")
    #expect(index.shardPath(surah: 1) == "study/surah_001.json")
    #expect(index.shardPath(surah: 103) == "study/surah_103.json")
    #expect(index.coveredSurahs == [1])
}

@Test("A shard decodes from a bare array of units as well as the wrapped object")
func shardAcceptsBothShapes() throws {
    let bare = "[\(syntheticUnit(key: "5:1")), \(syntheticUnit(key: "5:2-3"))]"
    let shard = try JSONDecoder().decode(StudyShard.self, from: Data(bare.utf8))
    #expect(shard.surah == 5)
    #expect(shard.units.count == 2)
    #expect(shard.byKey["5:2-3"]?.end == 3)
}

@Test("An empty store answers nil for everything without throwing")
func emptyStoreIsUsable() {
    let store = StudyStore.empty()
    #expect(!store.hasStudy(for: VerseRef(surah: 1, ayah: 1)))
    #expect(store.study(for: VerseRef(surah: 1, ayah: 1)) == nil)
    #expect(store.studies(inSurah: 1).isEmpty)
    #expect(store.unitKeys.isEmpty)
}
