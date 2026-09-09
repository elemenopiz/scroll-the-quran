import Foundation
import QuranData
@testable import StudyContent
import Testing

@Test("Every ayah an authored unit covers resolves to that unit")
func everyAuthoredAyahResolves() throws {
    let store = try bundledStore()
    for shard in try syncedShards() {
        for unit in shard.units {
            for verse in unit.verses {
                #expect(store.hasStudy(for: verse), "\(verse.key) has no study although \(unit.key) covers it")
                let study = try #require(store.study(for: verse), "\(verse.key) resolves to no study")
                #expect(study.key == unit.key)
                #expect(study.surah == shard.surah)
                #expect(!study.title.isEmpty)
                #expect(!study.keyTerms.isEmpty)
            }
        }
    }
}

@Test("hasStudy means a study exists, not merely that passages.json maps the ayah")
func hasStudyMeansTheStudyExists() throws {
    let store = try bundledStore()
    // Surah 2 has a shard, but only some of its units are authored: 2:6 is segmented into
    // "2:6-7", which no study covers yet.
    let unauthored = VerseRef(surah: 2, ayah: 6)
    #expect(store.unitKey(for: unauthored) == "2:6-7", "the reader's segmentation lookup is unchanged")
    #expect(!store.hasStudy(for: unauthored))
    #expect(store.study(for: unauthored) == nil)
    #expect(!store.containsUnit("2:6-7"))

    // Surahs with no shard at all are still fully segmented, and still have no study.
    for verse in [VerseRef(surah: 18, ayah: 10), VerseRef(surah: 103, ayah: 2), VerseRef(surah: 114, ayah: 1)] {
        #expect(store.unitKey(for: verse) != nil, "\(verse.key) should still belong to a unit")
        #expect(!store.hasStudy(for: verse))
        #expect(store.study(for: verse) == nil)
    }
    #expect(store.study(forKey: "not a key") == nil)
    #expect(!store.containsUnit("not a key"))

    // And an authored one is true both ways.
    #expect(store.hasStudy(for: VerseRef(surah: 2, ayah: 255)))
    #expect(store.containsUnit("2:255"))
}

@Test("unitKeys stays the segmentation; studyKeys is what has been authored")
func unitKeysAndStudyKeysDiffer() throws {
    let store = try bundledStore()
    #expect(store.unitKeys.count >= 3000, "passages.json defines every unit, authored or not")
    let authored = try syncedStudies().map(\.key)
    for surah in try syncedSurahs() {
        let keys = store.studyKeys(inSurah: surah)
        #expect(!keys.isEmpty)
        #expect(keys.isSubset(of: store.unitKeys), "surah \(surah) has a study outside the segmentation")
        #expect(keys == Set(authored.filter { PassageRef(key: $0)?.surah == surah }))
    }
    #expect(store.studyKeys(inSurah: 114).isEmpty)
    #expect(store.unitKeys.count > authored.count)
}

@Test("The authored units of a surah come back in ayah order")
func studiesInSurahAreOrdered() throws {
    let store = try bundledStore()
    for shard in try syncedShards() {
        let units = store.studies(inSurah: shard.surah)
        #expect(units.map(\.key) == shard.units.map(\.key), "surah \(shard.surah) came back out of order")
        var next = 0
        for unit in units {
            #expect(unit.start > next, "surah \(shard.surah) overlaps at \(unit.key)")
            next = unit.end
        }
    }
    #expect(store.studies(inSurah: 114).isEmpty)
}

@Test("An ayah mapped to a unit whose shard file is missing still resolves to nil")
func missingShardFileIsSurvivable() throws {
    let loader = InMemoryContentLoader(json: [
        "study/passages.json": #"{ "2:255": "2:255" }"#,
    ])
    let store = try StudyStore(loader: loader)
    #expect(store.unitKey(for: VerseRef(surah: 2, ayah: 255)) == "2:255")
    #expect(!store.hasStudy(for: VerseRef(surah: 2, ayah: 255)))
    #expect(store.study(for: VerseRef(surah: 2, ayah: 255)) == nil)
    #expect(store.study(for: VerseRef(surah: 2, ayah: 255)) == nil)
    #expect(store.shardLoadCount == 0)
    // The missing shard is remembered, so only the first question read anything.
    #expect(loader.readLog.filter { $0 == "study/surah_002.json" }.count == 1)
}

@Test("hasStudy reads a surah's shard once and remembers its keys past eviction")
func hasStudyCachesTheKeyIndex() throws {
    let loader = syntheticLoader(surahs: [1, 2, 3], unauthored: ["4:1"])
    let store = try StudyStore(loader: loader)
    loader.resetReadLog()

    for _ in 0 ..< 3 {
        for surah in 1 ... 3 {
            #expect(store.hasStudy(for: VerseRef(surah: surah, ayah: 1)))
            #expect(store.containsUnit("\(surah):1"))
        }
        // Segmented but never authored: no shard exists for surah 4.
        #expect(store.unitKey(for: VerseRef(surah: 4, ayah: 1)) == "4:1")
        #expect(!store.hasStudy(for: VerseRef(surah: 4, ayah: 1)))
    }
    #expect(store.shardLoadCount == 3)
    #expect(loader.readLog.count == 4, "each of the four surahs should have been read exactly once")

    // Dropping the shards keeps the key index, so the existence questions stay free.
    store.evictAll()
    loader.resetReadLog()
    #expect(store.hasStudy(for: VerseRef(surah: 1, ayah: 1)))
    #expect(!store.hasStudy(for: VerseRef(surah: 4, ayah: 1)))
    #expect(loader.readLog.isEmpty)
    #expect(store.shardLoadCount == 3)
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
    // Surah 1 was evicted, so asking for its content again re-reads it.
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
    #expect(store.study(forKey: "1:1-7")?.title == "The Prayer That Opens Everything")
    #expect(store.study(forKey: "1:6")?.key == "1:1-7")
    #expect(store.study(forKey: "2:255")?.themeId == "protection-and-refuge")
    #expect(store.study(for: PassageRef(surah: 2, start: 1, end: 5))?.key == "2:1-5")
    #expect(store.unitKey(for: VerseRef(surah: 2, ayah: 3)) == "2:1-5")
    // An ayah number past the end of a real surah is a miss, not a crash.
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

    let wrapped = #"{ "shards": { "1": "study/one.json" }, "units": { "1:1": "1:1" } }"#
    let mapped = try JSONDecoder().decode(PassageIndex.self, from: Data(wrapped.utf8))
    #expect(mapped.shardPath(surah: 1) == "study/one.json")
    #expect(mapped.unitKeys == ["1:1"])
}

@Test("A shard decodes from the assembler's studies key, a units key, and a bare array")
func shardAcceptsEveryShape() throws {
    let assembled = try JSONDecoder().decode(
        StudyShard.self,
        from: Data(syntheticShard(surah: 5, keys: ["5:1", "5:2"]).utf8)
    )
    #expect(assembled.surah == 5)
    #expect(assembled.promptVersion == "t1")
    #expect(assembled.generatedAt == "2026-09-09T00:00:00.000Z")
    #expect(assembled.keys == ["5:1", "5:2"])

    let wrapped = "{ \"surah\": 5, \"units\": [\(syntheticUnit(key: "5:1"))] }"
    #expect(try JSONDecoder().decode(StudyShard.self, from: Data(wrapped.utf8)).units.count == 1)

    let bare = "[\(syntheticUnit(key: "5:1")), \(syntheticUnit(key: "5:2-3"))]"
    let shard = try JSONDecoder().decode(StudyShard.self, from: Data(bare.utf8))
    #expect(shard.surah == 5)
    #expect(shard.units.count == 2)
    #expect(shard.byKey["5:2-3"]?.end == 3)
    #expect(shard.promptVersion.isEmpty)
}

@Test("An empty store answers nil for everything without throwing")
func emptyStoreIsUsable() {
    let store = StudyStore.empty()
    #expect(!store.hasStudy(for: VerseRef(surah: 1, ayah: 1)))
    #expect(store.study(for: VerseRef(surah: 1, ayah: 1)) == nil)
    #expect(store.studies(inSurah: 1).isEmpty)
    #expect(store.studyKeys(inSurah: 1).isEmpty)
    #expect(store.unitKeys.isEmpty)
}
