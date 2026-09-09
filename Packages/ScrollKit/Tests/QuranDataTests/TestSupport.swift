import Foundation
@testable import QuranData

/// Repo root, walked up from this file: Tests/QuranDataTests -> Tests -> ScrollKit -> Packages -> root.
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

/// Host tests have no app bundle, so they read `Content/` straight out of the repository.
enum TestContent {
    static let contentDirectory = repoRoot.appendingPathComponent("Content", isDirectory: true)

    static let locator = ContentLocator(roots: [contentDirectory])

    static func data(_ relativePath: String) throws -> Data {
        try locator.data(for: relativePath)
    }

    static func index() throws -> SurahIndex {
        try SurahIndex(locator: locator)
    }

    static func store(selecting id: String? = nil) throws -> TranslationStore {
        try TranslationStore(locator: locator, selectedID: id)
    }

    static func verses(_ file: String) throws -> [String] {
        try locator.decode([String].self, from: "quran/\(file)")
    }
}

/// The Arabic blocks: script, supplement, presentation forms A and B.
private let arabicBlocks: [ClosedRange<UInt32>] = [
    0x0600 ... 0x06FF, 0x0750 ... 0x077F, 0x08A0 ... 0x08FF,
    0xFB50 ... 0xFDFF, 0xFE70 ... 0xFEFF,
]

extension String {
    var containsArabicScript: Bool {
        unicodeScalars.contains { scalar in arabicBlocks.contains { $0.contains(scalar.value) } }
    }

    var wordCount: Int {
        split(whereSeparator: \.isWhitespace).count
    }
}
