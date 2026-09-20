import Foundation

/// One JSON file per concern. Splitting them means a corrupt or half-written file costs the
/// user one thing (say, their notes) instead of everything, and the widget can read the two
/// files it cares about without decoding the rest.
public enum UserStateFile: String, CaseIterable, Sendable {
    case streak
    case progress
    case library
    case notes
    case plan
    case prefs

    public var filename: String {
        "\(rawValue).json"
    }
}

/// Where `UserStore` keeps its files. Injectable so tests get a scratch directory and the app
/// and the widget share the App Group container.
public protocol UserStateFileStore: Sendable {
    /// Nil when the file has never been written.
    func read(_ file: UserStateFile) throws -> Data?
    func write(_ data: Data, to file: UserStateFile) throws
    func remove(_ file: UserStateFile) throws
}

public extension UserStateFileStore {
    func removeAll() throws {
        for file in UserStateFile.allCases {
            try remove(file)
        }
    }
}

/// Resolves the directory the app and the widget share.
public enum UserStateLocation {
    /// The App Group both the app and the widget extension are entitled to.
    public static let appGroupIdentifier = "group.com.quranscroller"

    /// The App Group container's `UserState` folder, falling back to Application Support when
    /// the group is unavailable — which is the case in host unit tests and command-line tools.
    public static func defaultDirectory(
        groupIdentifier: String = appGroupIdentifier,
        fileManager: FileManager = .default
    ) -> URL {
        if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            return container.appendingPathComponent("UserState", isDirectory: true)
        }
        return applicationSupportDirectory(fileManager: fileManager)
    }

    /// `~/Library/Application Support/ScrollTheQuran/UserState`.
    public static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("ScrollTheQuran", isDirectory: true)
            .appendingPathComponent("UserState", isDirectory: true)
    }
}

/// The real store: one file per concern in a directory, written atomically.
///
/// A write goes to a uniquely named temp file in the same directory and is then renamed over
/// the destination, so a crash (or a widget reading mid-write) either sees the whole old file
/// or the whole new one — never a truncated one. Temp files left behind by a crash are named
/// `.<concern>-<uuid>.tmp`, do not match any `UserStateFile`, and are ignored on load; `load()`
/// sweeps them away.
public struct DirectoryUserStateFileStore: UserStateFileStore {
    public let directory: URL

    /// `FileManager.default`'s file operations are safe to call from any thread, and the store
    /// holds no other mutable state, so this is `Sendable` by construction.
    private var fileManager: FileManager {
        .default
    }

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for file: UserStateFile) -> URL {
        directory.appendingPathComponent(file.filename, isDirectory: false)
    }

    public func read(_ file: UserStateFile) throws -> Data? {
        let url = url(for: file)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func write(_ data: Data, to file: UserStateFile) throws {
        let destination = url(for: file)
        let temporary = directory.appendingPathComponent(".\(file.rawValue)-\(UUID().uuidString).tmp", isDirectory: false)
        do {
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    public func remove(_ file: UserStateFile) throws {
        let url = url(for: file)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    /// Deletes `.tmp` leftovers from an interrupted write. Returns how many it removed.
    @discardableResult
    public func sweepTemporaryFiles() -> Int {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return 0 }
        var removed = 0
        for name in names where name.hasSuffix(".tmp") {
            let url = directory.appendingPathComponent(name, isDirectory: false)
            if (try? fileManager.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        return removed
    }
}

/// An in-memory store for tests, SwiftUI previews and the `--screenshot` fixture routes.
/// Also counts writes, which is how the debounce is asserted.
public final class MemoryUserStateFileStore: UserStateFileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [UserStateFile: Data] = [:]
    private var writeCounts: [UserStateFile: Int] = [:]

    public init(seed: [UserStateFile: Data] = [:]) {
        files = seed
    }

    public func read(_ file: UserStateFile) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return files[file]
    }

    public func write(_ data: Data, to file: UserStateFile) throws {
        lock.lock()
        defer { lock.unlock() }
        files[file] = data
        writeCounts[file, default: 0] += 1
    }

    public func remove(_ file: UserStateFile) throws {
        lock.lock()
        defer { lock.unlock() }
        files[file] = nil
    }

    /// How many times this concern has been written.
    public func writeCount(_ file: UserStateFile) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return writeCounts[file] ?? 0
    }

    public var totalWrites: Int {
        lock.lock()
        defer { lock.unlock() }
        return writeCounts.values.reduce(0, +)
    }

    public func resetWriteCounts() {
        lock.lock()
        defer { lock.unlock() }
        writeCounts = [:]
    }
}
