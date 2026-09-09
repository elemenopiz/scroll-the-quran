import Foundation
@testable import StudyContent

/// Repo root, walked up from this file: Tests/StudyContentTests -> Tests -> ScrollKit -> Packages -> root.
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

/// The repo's real `Content/` folder — the same files the app bundles, written by
/// `node Tools/content-gen/sync-study-content.mjs --prune`.
let bundledContent = DirectoryContentLoader(root: repoRoot.appendingPathComponent("Content"))

func contentData(_ path: String) throws -> Data {
    try bundledContent.data(at: path)
}

/// The surahs that currently ship a shard, read off disk rather than hard-coded: the pipeline
/// adds shards wave by wave and these tests must not need editing when it does.
func syncedSurahs() throws -> [Int] {
    let studyDirectory = repoRoot.appendingPathComponent("Content/study")
    let names = try FileManager.default.contentsOfDirectory(atPath: studyDirectory.path)
    return names
        .compactMap { name in
            guard name.hasPrefix("surah_"), name.hasSuffix(".json") else { return nil }
            return Int(name.dropFirst("surah_".count).dropLast(".json".count))
        }
        .sorted()
}

func syncedShardPaths() throws -> [String] {
    try syncedSurahs().map { PassageIndex.defaultShardPath(surah: $0) }
}

/// Every shard in `Content/study`, decoded.
func syncedShards() throws -> [StudyShard] {
    try syncedShardPaths().map { try JSONDecoder().decode(StudyShard.self, from: contentData($0)) }
}

/// Every authored unit across every shard.
func syncedStudies() throws -> [Study] {
    try syncedShards().flatMap(\.units)
}

struct SurahMeta: Decodable {
    let number: Int
    let name: String
    let ayahCount: Int
}

func bundledSurahs() throws -> [SurahMeta] {
    try JSONDecoder().decode([SurahMeta].self, from: contentData("quran/surahs.json"))
}

func bundledStore() throws -> StudyStore {
    try StudyStore(loader: bundledContent)
}

func bundledPassageIndex() throws -> PassageIndex {
    try JSONDecoder().decode(PassageIndex.self, from: contentData("study/passages.json"))
}

func bundledDiscoverFile() throws -> DiscoverFile {
    try JSONDecoder().decode(DiscoverFile.self, from: contentData("discover.json"))
}

// MARK: - Synthetic content

/// A minimal but complete unit, in the shape `assemble.mjs` writes, used to build synthetic
/// shards for the cache, feed and decoding tests.
func syntheticUnit(key: String, title: String = "Synthetic", tier: String = "standard") -> String {
    """
    {
      "key": "\(key)", "theme": "Testing", "themeId": "testing", "title": "\(title)", "tier": "\(tier)",
      "meaning": "Meaning of \(key).", "historicalContext": "Context of \(key).",
      "keyTerms": [{ "arabic": "\u{0635}\u{0628}\u{0631}", "gloss": "patience", "note": "Note." }],
      "lifeInProphetsTime": "Then.", "didYouKnow": "Fact.", "theologicalSignificance": "Why.",
      "crossReferences": [{ "ref": "2:153", "why": "Because." }],
      "applyIt": "Do this.", "exploreFurther": ["2:153"],
      "meta": { "model": "test", "promptVersion": "t1", "generatedAt": "2026-09-09", "reviewed": true }
    }
    """
}

/// A shard in the pipeline's shape, carrying the given single-ayah units.
func syntheticShard(surah: Int, keys: [String]) -> String {
    """
    {
      "surah": \(surah), "promptVersion": "t1", "generatedAt": "2026-09-09T00:00:00.000Z",
      "studies": [\(keys.map { syntheticUnit(key: $0) }.joined(separator: ", "))]
    }
    """
}

/// A loader holding one single-ayah unit per surah in `surahs`, plus a passages map that — like
/// the real one — also maps ayat that have no study.
func syntheticLoader(surahs: [Int], unauthored: [String] = []) -> InMemoryContentLoader {
    var mappings = surahs.map { "\"\($0):1\": \"\($0):1\"" }
    mappings += unauthored.map { "\"\($0)\": \"\($0)\"" }
    var files = ["study/passages.json": "{ \(mappings.joined(separator: ", ")) }"]
    for surah in surahs {
        files[PassageIndex.defaultShardPath(surah: surah)] = syntheticShard(surah: surah, keys: ["\(surah):1"])
    }
    return InMemoryContentLoader(json: files)
}
