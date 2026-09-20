import Foundation
import Testing
@testable import UserState

@Suite("Persistence")
struct PersistenceTests {
    @Test("Each concern is its own JSON file")
    func fileNames() {
        #expect(UserStateFile.allCases.map(\.filename).sorted() ==
            ["library.json", "notes.json", "plan.json", "prefs.json", "progress.json", "streak.json"])
    }

    @Test("A write lands in the file and leaves no temp file behind")
    func atomicWriteLeavesNoTemporaryFiles() throws {
        let directory = TemporaryDirectory()
        let store = try DirectoryUserStateFileStore(directory: directory.url)
        try store.write(Data(#"{"a":1}"#.utf8), to: .prefs)
        try store.write(Data(#"{"a":2}"#.utf8), to: .prefs)

        #expect(directory.fileNames == ["prefs.json"])
        #expect(directory.text("prefs.json") == #"{"a":2}"#)
        #expect(try store.read(.prefs) == Data(#"{"a":2}"#.utf8))
    }

    @Test("Reading a file that was never written returns nil, not an error")
    func readingAMissingFileReturnsNil() throws {
        let directory = TemporaryDirectory()
        let store = try DirectoryUserStateFileStore(directory: directory.url)
        #expect(try store.read(.notes) == nil)
        try store.remove(.notes) // also a no-op
    }

    @Test("A temp file left behind by a crash mid-write is not mistaken for the real file")
    func crashLeftoverTemporaryFileIsIgnored() throws {
        let directory = TemporaryDirectory()
        let store = try DirectoryUserStateFileStore(directory: directory.url)
        try store.write(Data(#"{"translationId":"itani"}"#.utf8), to: .prefs)

        // The crash: a half-written temp file, never renamed.
        directory.write("{\"translationId\":\"half-writ", to: ".prefs-6D1F.tmp")

        #expect(try store.read(.prefs) == Data(#"{"translationId":"itani"}"#.utf8))
        #expect(directory.fileNames.contains(".prefs-6D1F.tmp"))

        #expect(store.sweepTemporaryFiles() == 1)
        #expect(directory.fileNames == ["prefs.json"])
        #expect(try store.read(.prefs) == Data(#"{"translationId":"itani"}"#.utf8))
    }

    @Test("Removing a file, then all of them, leaves the directory empty")
    func removeAndRemoveAll() throws {
        let directory = TemporaryDirectory()
        let store = try DirectoryUserStateFileStore(directory: directory.url)
        for file in UserStateFile.allCases {
            try store.write(Data("{}".utf8), to: file)
        }
        #expect(directory.fileNames.count == 6)
        try store.remove(.notes)
        #expect(directory.fileNames.count == 5)
        try store.removeAll()
        #expect(directory.fileNames.isEmpty)
    }

    @Test("The store creates its directory, including missing parents")
    func createsItsDirectory() throws {
        let directory = TemporaryDirectory()
        let nested = directory.url.appendingPathComponent("a/b/UserState", isDirectory: true)
        let store = try DirectoryUserStateFileStore(directory: nested)
        try store.write(Data("{}".utf8), to: .plan)
        #expect(FileManager.default.fileExists(atPath: nested.appendingPathComponent("plan.json").path))
    }

    @Test("The default directory is the App Group container's UserState folder")
    func defaultDirectoryPrefersTheAppGroup() {
        let directory = TemporaryDirectory()
        let fileManager = FakeAppGroupFileManager(container: directory.url)
        let resolved = UserStateLocation.defaultDirectory(fileManager: fileManager)
        #expect(resolved == directory.url
            .appendingPathComponent("group.com.quranscroller", isDirectory: true)
            .appendingPathComponent("UserState", isDirectory: true))
        #expect(UserStateLocation.appGroupIdentifier == "group.com.quranscroller")
    }

    @Test("Without the App Group, the default directory falls back to Application Support")
    func defaultDirectoryFallsBackToApplicationSupport() {
        let fileManager = NoAppGroupFileManager()
        let resolved = UserStateLocation.defaultDirectory(fileManager: fileManager)
        #expect(resolved == UserStateLocation.applicationSupportDirectory(fileManager: fileManager))
        #expect(resolved.pathComponents.suffix(2) == ["ScrollTheQuran", "UserState"])
    }

    @Test("The in-memory store keeps files apart and counts writes")
    func memoryStoreCountsWrites() throws {
        let store = MemoryUserStateFileStore()
        try store.write(Data("{}".utf8), to: .prefs)
        try store.write(Data("{}".utf8), to: .prefs)
        try store.write(Data("{}".utf8), to: .notes)
        #expect(store.writeCount(.prefs) == 2)
        #expect(store.writeCount(.notes) == 1)
        #expect(store.writeCount(.streak) == 0)
        #expect(store.totalWrites == 3)
        try store.remove(.prefs)
        #expect(try store.read(.prefs) == nil)
        #expect(try store.read(.notes) != nil)
    }
}
