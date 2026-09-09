import Foundation

/// Finds the bundled `Content/` tree.
///
/// The app ships `Content/` as a folder reference, so at runtime the files sit under
/// `Bundle.main.resourceURL/Content/…`. Host tests (`swift test`) have no app bundle, so they
/// point `SCROLLKIT_CONTENT_DIR` at the repository's `Content/` directory instead — or build a
/// locator with explicit roots.
///
/// Paths handed to a locator are relative to `Content/`, e.g. `"quran/surahs.json"`.
public struct ContentLocator: Sendable {
    /// Environment variable read by ``ContentLocator/init()``. Points at a `Content/` directory.
    public static let environmentKey = "SCROLLKIT_CONTENT_DIR"

    /// Searched in order; the first root that has the file wins.
    public let roots: [URL]

    public init(roots: [URL]) {
        self.roots = roots
    }

    /// `SCROLLKIT_CONTENT_DIR` first, then the main bundle's `Content` folder, then the
    /// bundle's resource root (so a flattened bundle still resolves).
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

    /// The default locator. Resolved once; the environment does not change under a running app.
    public static let shared = ContentLocator()

    /// The first existing file for `relativePath`, or nil.
    public func url(for relativePath: String) -> URL? {
        let fileManager = FileManager.default
        for root in roots {
            let candidate = root.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    public func data(for relativePath: String) throws -> Data {
        guard let url = url(for: relativePath) else {
            throw ContentLocatorError.notFound(relativePath: relativePath, roots: roots.map(\.path))
        }
        return try Data(contentsOf: url)
    }

    public func decode<T: Decodable>(_ type: T.Type, from relativePath: String) throws -> T {
        try JSONDecoder().decode(type, from: data(for: relativePath))
    }
}

public enum ContentLocatorError: Error, CustomStringConvertible, Equatable {
    case notFound(relativePath: String, roots: [String])

    public var description: String {
        switch self {
        case let .notFound(relativePath, roots):
            "Content/\(relativePath) is not in any of: \(roots.joined(separator: ", ")). "
                + "Set \(ContentLocator.environmentKey) to the repository's Content directory for host tests."
        }
    }
}
