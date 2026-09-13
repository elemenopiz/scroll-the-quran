import DesignSystem
import QuranData
import StudyContent
import SwiftUI

/// Routing seam for `--screenshot discover` and `--screenshot deepstudy#<section>`.
///
/// `ScreenRoute` lives in `AppShell`, which imports this module, so the route arrives
/// here already split into its two halves: the screen id and the optional `#anchor`.
/// The exact AppShell call is in this module's README note in the task report.
public enum DiscoverScreens {
    /// The screen ids this module answers to.
    public static let screenIDs = ["discover", "discover-reflection", "deepstudy"]

    /// Whether `screen(id:anchor:…)` will render something for this id.
    public static func handles(_ id: String) -> Bool {
        screenIDs.contains(id)
    }

    /// Builds the screen for a route.
    ///
    /// - Parameters:
    ///   - id: `"discover"` or `"deepstudy"` — `ScreenRoute.screen.rawValue`.
    ///   - anchor: the `#…` half, e.g. `"apply-it"`. Ignored for `discover`.
    ///   - key: which study to open for `deepstudy`. Defaults to the day's first card.
    @MainActor
    public static func screen(
        id: String,
        anchor: String? = nil,
        feed: DiscoverFeed,
        themes: ThemeIndex = .empty,
        studies: StudyStore? = nil,
        today: Date = Date(),
        key: String? = nil
    ) -> some View {
        DiscoverRouteView(
            id: id,
            anchor: anchor,
            feed: feed,
            themes: themes,
            studies: studies,
            today: today,
            key: key
        )
    }

    /// The card a bare `deepstudy` route opens: the first card of the day that actually
    /// has a unit, so the screenshot is never the empty state by accident.
    public static func defaultStudyKey(feed: DiscoverFeed, studies: StudyStore?, today: Date) -> String? {
        let keys = feed.items(on: today).map(\.key)
        guard let studies else { return keys.first }
        return keys.first { studies.study(forKey: $0) != nil } ?? keys.first
    }
}

/// The concrete view behind `DiscoverScreens.screen(id:…)`.
@MainActor
public struct DiscoverRouteView: View {
    private let id: String
    private let anchor: String?
    private let feed: DiscoverFeed
    private let themes: ThemeIndex
    private let studies: StudyStore?
    private let today: Date
    private let key: String?

    public init(
        id: String,
        anchor: String? = nil,
        feed: DiscoverFeed,
        themes: ThemeIndex = .empty,
        studies: StudyStore? = nil,
        today: Date = Date(),
        key: String? = nil
    ) {
        self.id = id
        self.anchor = anchor
        self.feed = feed
        self.themes = themes
        self.studies = studies
        self.today = today
        self.key = key
    }

    public var body: some View {
        switch id {
        case "deepstudy":
            deepStudy
        default:
            DiscoverView(
                feed: feed,
                themes: themes,
                today: today,
                initialKey: key,
                startIndex: DiscoverLaunchIndex.value ?? 0,
                // Read off the process rather than taken from `id`: `TabRoot` builds the
                // Discover tab as plain `"discover"` whatever the route is, and `TabRoot`
                // belongs to the shell. Same seam `--discover-index` already uses.
                startsOnReflection: id == DiscoverLaunchStart.reflectionRoute
                    || DiscoverLaunchStart.startsOnReflection
            )
        }
    }



    @ViewBuilder
    private var deepStudy: some View {
        let resolvedKey = key ?? DiscoverScreens.defaultStudyKey(feed: feed, studies: studies, today: today)
        if let resolvedKey, let study = studies?.study(forKey: resolvedKey) {
            DeepStudyView(
                study: study,
                themeTitle: themes.theme(forKey: resolvedKey)?.title,
                anchor: StudyAnchor.section(for: anchor)
            )
        } else {
            StudyComingSoonCard(reference: resolvedKey ?? "")
        }
    }
}


/// `--discover-index N`, parsed once out of the process arguments.
///
/// It makes the Nth card of the day's feed the *first* page, so a snapshot run can prove
/// the fixed slots hold for a one-ayah unit and for the longest one and not only for
/// whatever the seed puts first — and every such capture frames the card the same way.
/// Read here rather than in `AppShell`'s `LaunchOptions` because the feed lives in this
/// module and `FeatureDiscover` cannot import the shell.
enum DiscoverLaunchIndex {
    static let flag = "--discover-index"

    static let value: Int? = parse(ProcessInfo.processInfo.arguments)

    static func parse(_ arguments: [String]) -> Int? {
        guard let position = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: position)
        guard next < arguments.endIndex else { return nil }
        return Int(arguments[next])
    }
}

/// `--screenshot discover-reflection`, parsed once out of the process arguments.
///
/// The route makes the day's first REFLECTION card page 0 of the pager, which is the only
/// way to frame it the way every other capture is framed: the interleave puts it at
/// position 4, and landing there with `scrollPosition(id:)` leaves the pager mid-page.
///
/// Read here rather than in `AppShell`'s `LaunchOptions` for the same reason
/// `DiscoverLaunchIndex` is: `TabRoot` renders the Discover tab as the bare `"discover"`
/// screen whatever the `--screenshot` route says, and the shell is not this task's to edit.
enum DiscoverLaunchStart {
    static let flag = "--screenshot"
    static let reflectionRoute = "discover-reflection"

    static let startsOnReflection: Bool = parse(ProcessInfo.processInfo.arguments)

    static func parse(_ arguments: [String]) -> Bool {
        guard let position = arguments.firstIndex(of: flag) else { return false }
        let next = arguments.index(after: position)
        guard next < arguments.endIndex else { return false }
        return arguments[next] == reflectionRoute
    }
}
