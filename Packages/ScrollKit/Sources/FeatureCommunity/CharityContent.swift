import Foundation

/// Where `Content/charities.json` is read from.
///
/// The app ships `Content/` as a folder reference, so at runtime the file sits at
/// `Bundle.main.resourceURL/Content/charities.json`. Host tests have no app bundle, so they
/// point `SCROLLKIT_CONTENT_DIR` at the repository's `Content/` directory or hand in a fixture.
/// The same indirection `StudyContent` uses, kept local so `FeatureCommunity` stays on its two
/// declared dependencies.
public protocol CharityContentLoading: Sendable {
    func data(at relativePath: String) throws -> Data
}

public enum CharityContentError: Error, Equatable, CustomStringConvertible {
    case missing(String, searched: [String])
    case malformed(String, reason: String)

    public var description: String {
        switch self {
        case let .missing(path, searched):
            "No content at \(path); searched \(searched.joined(separator: ", "))"
        case let .malformed(path, reason):
            "Content at \(path) is malformed: \(reason)"
        }
    }
}

/// Reads from the first root that has the file: `SCROLLKIT_CONTENT_DIR`, then the main bundle's
/// `Content` folder, then the bundle's resource root (so a flattened bundle still resolves).
public struct BundledCharityContent: CharityContentLoading {
    /// Environment variable that overrides the bundle, for host tests and command-line tools.
    public static let environmentKey = "SCROLLKIT_CONTENT_DIR"

    public let roots: [URL]

    public init(roots: [URL]) {
        self.roots = roots
    }

    public init(environment: [String: String] = ProcessInfo.processInfo.environment, bundle: Bundle = .main) {
        var roots: [URL] = []
        if let override = environment[Self.environmentKey], !override.isEmpty {
            roots.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        for base in [bundle.resourceURL, bundle.bundleURL].compactMap(\.self) {
            roots.append(base.appendingPathComponent("Content", isDirectory: true))
            roots.append(base)
        }
        self.init(roots: roots)
    }

    public func data(at relativePath: String) throws -> Data {
        for root in roots {
            let candidate = root.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try Data(contentsOf: candidate)
            }
        }
        throw CharityContentError.missing(relativePath, searched: roots.map(\.path))
    }
}

/// A fixture held in memory: previews, `--screenshot` routes and tests.
public struct InMemoryCharityContent: CharityContentLoading {
    private let files: [String: Data]

    public init(files: [String: Data]) {
        self.files = files
    }

    public init(json: String, at relativePath: String = CharityCatalog.contentPath) {
        self.init(files: [relativePath: Data(json.utf8)])
    }

    public func data(at relativePath: String) throws -> Data {
        guard let data = files[relativePath] else {
            throw CharityContentError.missing(relativePath, searched: Array(files.keys))
        }
        return data
    }
}

public extension CharityCatalog {
    /// Path inside `Content/`.
    static let contentPath = "charities.json"

    /// Decodes the catalog, turning a decoding failure into a `CharityContentError` that names
    /// the file — a malformed `charities.json` should be readable in a crash report, not a
    /// bare `keyNotFound`.
    static func load(from loader: some CharityContentLoading, path: String = contentPath) throws -> CharityCatalog {
        let data = try loader.data(at: path)
        do {
            return try JSONDecoder().decode(CharityCatalog.self, from: data)
        } catch {
            throw CharityContentError.malformed(path, reason: String(describing: error))
        }
    }

    /// The catalog the app renders, or an empty one when the file is missing or malformed. The
    /// Community tab degrades to its copy and no organisations rather than crashing the app.
    static func loadOrEmpty(from loader: some CharityContentLoading = BundledCharityContent()) -> CharityCatalog {
        (try? load(from: loader)) ?? .empty
    }

    static let empty = CharityCatalog(
        givenTotalUSD: 0,
        headline: defaultHeadline,
        subline: defaultSubline,
        voteTitle: defaultVoteTitle,
        voteBody: defaultVoteBody,
        organisations: []
    )
}
