import Observation
import QuranData
import SwiftUI

/// Owns tab selection and the pending deep link. Conforms to `Router`, so features
/// can navigate without knowing what is on the other side.
@MainActor
@Observable
public final class TabRootModel: Router {
    public var selection: AppTab
    public private(set) var pendingVerse: VerseRef?
    public private(set) var pendingStudy: PassageRef?

    public init(selection: AppTab = .home) {
        self.selection = selection
    }

    public func selectTab(_ tab: AppTab) {
        selection = tab
    }

    public func open(verse: VerseRef) {
        pendingVerse = verse
        selection = .quran
    }

    public func openDeepStudy(passage: PassageRef) {
        pendingStudy = passage
        selection = .discover
    }

    public func handle(_ link: DeepLink) {
        switch link {
        case let .verse(ref): open(verse: ref)
        case let .study(ref): openDeepStudy(passage: ref)
        case let .tab(tab): selectTab(tab)
        }
    }

    public func consumePendingVerse() -> VerseRef? {
        defer { pendingVerse = nil }
        return pendingVerse
    }

    public func consumePendingStudy() -> PassageRef? {
        defer { pendingStudy = nil }
        return pendingStudy
    }
}

/// The four-tab shell: Community, Discover, Home, The Quran.
@MainActor
public struct TabRoot: View {
    @State private var model: TabRootModel

    public init(model: TabRootModel? = nil) {
        _model = State(initialValue: model ?? TabRootModel())
    }

    public var body: some View {
        TabView(selection: $model.selection) {
            ForEach(AppTab.allCases) { tab in
                PlaceholderScreen(
                    screenID: tab.screenID,
                    title: tab.title,
                    systemImage: tab.systemImage
                )
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .tint(Color.primary)
        .environment(\.router, model)
        .accessibilityIdentifier("tabroot")
    }
}

public extension AppTab {
    /// Screen id shown by the Phase 1 placeholder for this tab.
    var screenID: String {
        switch self {
        case .community: "community"
        case .discover: "discover"
        case .home: "home"
        case .quran: "reader"
        }
    }
}

private struct RouterKey: EnvironmentKey {
    static let defaultValue: (any Router)? = nil
}

public extension EnvironmentValues {
    /// The active `Router`, injected by `TabRoot`.
    var router: (any Router)? {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}

#Preview("TabRoot") {
    TabRoot()
}
