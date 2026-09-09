@testable import FeatureReader
import Foundation
import QuranData
import UserState

/// Repo root, walked up from this file: Tests/FeatureReaderTests -> Tests -> ScrollKit -> Packages -> root.
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

/// Host tests have no app bundle, so they read `Content/` straight out of the repository.
enum TestContent {
    static let locator = ContentLocator(roots: [repoRoot.appendingPathComponent("Content", isDirectory: true)])

    static func index() throws -> SurahIndex {
        try SurahIndex(locator: locator)
    }

    static func translations(selecting id: String? = nil) throws -> TranslationStore {
        try TranslationStore(locator: locator, selectedID: id)
    }

    @MainActor
    static func userStore() -> UserStore {
        UserStore(fileStore: MemoryUserStateFileStore(), debounce: .milliseconds(1))
    }

    @MainActor
    static func model(surah: Int = 2, startAyah: Int? = nil) throws -> ReaderModel {
        try ReaderModel(
            index: index(),
            translations: translations(),
            user: userStore(),
            hints: EphemeralReaderHintStore(),
            surah: surah,
            startAyah: startAyah
        )
    }
}

/// A fixed source of made-up verse text, so pagination tests do not depend on `Content/`.
extension ReaderPagination.Source {
    static func fixture(arabic: String? = "عَرَبِيّ", english: @escaping (VerseRef) -> String) -> Self {
        ReaderPagination.Source(arabic: { _ in arabic }, english: { english($0) })
    }
}

/// SplitMix64: a deterministic generator, so the "is the dice uniform?" test is not flaky.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
