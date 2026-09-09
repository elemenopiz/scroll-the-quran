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

/// The repo's real `Content/` folder — the same files the app bundles.
let bundledContent = DirectoryContentLoader(root: repoRoot.appendingPathComponent("Content"))

func contentData(_ path: String) throws -> Data {
    try bundledContent.data(at: path)
}

/// The surahs that ship a hand-written study fixture.
let fixtureSurahs = [1, 103, 112]

let fixtureShardPaths = ["study/surah_001.json", "study/surah_103.json", "study/surah_112.json"]

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

// MARK: - Synthetic content

/// A minimal but complete unit, used to build synthetic shards for cache and feed tests.
func syntheticUnit(key: String, title: String = "Synthetic") -> String {
    """
    {
      "key": "\(key)", "theme": "Testing", "themeId": "testing", "title": "\(title)", "tier": 2,
      "meaning": "Meaning of \(key).", "historicalContext": "Context of \(key).",
      "keyTerms": [{ "arabic": "\u{0635}\u{0628}\u{0631}", "gloss": "patience", "note": "Note." }],
      "lifeInProphetsTime": "Then.", "didYouKnow": "Fact.", "theologicalSignificance": "Why.",
      "crossReferences": [{ "ref": "2:153", "why": "Because." }],
      "applyIt": "Do this.", "exploreFurther": ["2:153"],
      "meta": { "model": "test", "promptVersion": "t1", "generatedAt": "2026-09-09", "reviewed": true }
    }
    """
}

/// A loader holding one single-ayah unit per surah in `surahs`, plus the matching passages map.
func syntheticLoader(surahs: [Int]) -> InMemoryContentLoader {
    let units = surahs.map { "\"\($0):1\": \"\($0):1\"" }.joined(separator: ", ")
    let shards = surahs.map { "\"\($0)\": \"\(PassageIndex.defaultShardPath(surah: $0))\"" }
        .joined(separator: ", ")
    var files = [
        "study/passages.json": "{ \"shards\": { \(shards) }, \"units\": { \(units) } }",
    ]
    for surah in surahs {
        files[PassageIndex.defaultShardPath(surah: surah)] =
            "{ \"surah\": \(surah), \"units\": [\(syntheticUnit(key: "\(surah):1"))] }"
    }
    return InMemoryContentLoader(json: files)
}
