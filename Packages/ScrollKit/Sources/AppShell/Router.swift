import Foundation
import QuranData

/// The four tabs, in on-screen order (left to right).
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case community
    case discover
    case home
    case quran

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .community: "Community"
        case .discover: "Discover"
        case .home: "Home"
        case .quran: "The Quran"
        }
    }

    public var systemImage: String {
        switch self {
        case .community: "person.3"
        case .discover: "sparkles"
        case .home: "house"
        case .quran: "book"
        }
    }

    /// Stable identifier for XCUITest layout specs and taps.
    public var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}

/// Navigation seam between features. Features never know about each other; they
/// ask the router. `TabRootModel` is the Phase 1 implementation; deep links
/// (`scrollthequran://verse/2/255`) resolve through the same protocol.
@MainActor
public protocol Router: AnyObject {
    func selectTab(_ tab: AppTab)
    func open(verse: VerseRef)
    /// Opens Deep Study on a study unit key (`"2:255"`, `"94:5-6"`) — the id
    /// `Content/discover.json` and `Content/study/*` use.
    func openDeepStudy(key: String)
}

public extension Router {
    /// Convenience for callers that already hold a `PassageRef`.
    func openDeepStudy(passage: PassageRef) {
        openDeepStudy(key: passage.key)
    }
}

/// Deep-link parsing for the `scrollthequran` URL scheme.
public enum DeepLink: Equatable, Sendable {
    case verse(VerseRef)
    case study(PassageRef)
    case tab(AppTab)

    public static let scheme = "scrollthequran"

    /// `scrollthequran://verse/2/255`, `scrollthequran://study/94:5-6` (or the split
    /// `study/94/5-6`), `scrollthequran://tab/home`.
    public init?(url: URL) {
        guard url.scheme == DeepLink.scheme else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "verse":
            guard let verse = DeepLink.verse(from: path) else { return nil }
            self = .verse(verse)
        case "study":
            guard let passage = DeepLink.passage(from: path) else { return nil }
            self = .study(passage)
        case "tab":
            guard path.count == 1, let tab = AppTab(rawValue: path[0]) else { return nil }
            self = .tab(tab)
        default:
            return nil
        }
    }

    /// `verse/<surah>/<ayah>`.
    private static func verse(from path: [String]) -> VerseRef? {
        guard path.count == 2, let surah = Int(path[0]), let ayah = Int(path[1]),
              surah >= 1, ayah >= 1 else { return nil }
        return VerseRef(surah: surah, ayah: ayah)
    }

    /// `study/<key>` is the widget and share form; `study/<surah>/<range>` is kept because
    /// the Phase 1 tests and any already-shared link use it.
    private static func passage(from path: [String]) -> PassageRef? {
        switch path.count {
        case 1: PassageRef(key: path[0])
        case 2: PassageRef(key: "\(path[0]):\(path[1])")
        default: nil
        }
    }
}
