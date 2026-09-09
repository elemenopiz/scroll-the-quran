import Foundation

/// Everything `StudyContent` reads lives under the app's `Content/` folder reference, addressed
/// by a path relative to that folder (`"study/passages.json"`, `"discover.json"`, `"themes.json"`).
/// The indirection exists so host tests can point at the repo's `Content/` directory and so
/// previews can hand in fixtures without touching the disk.
public protocol StudyContentLoading: Sendable {
    func data(at relativePath: String) throws -> Data
}

public enum StudyContentError: Error, Equatable, CustomStringConvertible {
    case missing(String)
    case malformed(String, reason: String)

    public var description: String {
        switch self {
        case let .missing(path):
            "No content at \(path)"
        case let .malformed(path, reason):
            "Content at \(path) is malformed: \(reason)"
        }
    }
}

/// Reads from a directory on disk — the repo's `Content/` under `swift test`.
public struct DirectoryContentLoader: StudyContentLoading {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func data(at relativePath: String) throws -> Data {
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudyContentError.missing(relativePath)
        }
        return try Data(contentsOf: url)
    }
}

/// Reads from a bundle whose resources include the `Content` folder reference.
public struct BundleContentLoader: StudyContentLoading {
    public let bundle: Bundle
    public let subdirectory: String

    public init(bundle: Bundle = .main, subdirectory: String = "Content") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    public func data(at relativePath: String) throws -> Data {
        guard let root = bundle.resourceURL else { throw StudyContentError.missing(relativePath) }
        let url = root.appendingPathComponent(subdirectory).appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudyContentError.missing(relativePath)
        }
        return try Data(contentsOf: url)
    }
}

/// Fixtures held in memory: previews, `--screenshot` routes, and tests that need to count reads.
public final class InMemoryContentLoader: StudyContentLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data]
    private var reads: [String] = []

    public init(files: [String: Data] = [:]) {
        self.files = files
    }

    public convenience init(json: [String: String]) {
        self.init(files: json.mapValues { Data($0.utf8) })
    }

    public func put(_ data: Data, at relativePath: String) {
        lock.lock()
        defer { lock.unlock() }
        files[relativePath] = data
    }

    /// Every path read so far, in order — including repeats. Lets tests prove laziness and eviction.
    public var readLog: [String] {
        lock.lock()
        defer { lock.unlock() }
        return reads
    }

    public func resetReadLog() {
        lock.lock()
        defer { lock.unlock() }
        reads = []
    }

    public func data(at relativePath: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        reads.append(relativePath)
        guard let data = files[relativePath] else { throw StudyContentError.missing(relativePath) }
        return data
    }
}
