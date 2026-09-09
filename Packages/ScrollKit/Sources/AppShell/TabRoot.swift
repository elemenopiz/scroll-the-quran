import DesignSystem
import FeatureCommunity
import FeatureDiscover
import FeatureReader
import Observation
import QuranData
import StudyContent
import SwiftUI
import UserState

/// Owns tab selection and the pending deep link. Conforms to `Router`, so features
/// can navigate without knowing what is on the other side.
@MainActor
@Observable
public final class TabRootModel: Router {
    public var selection: AppTab
    public private(set) var pendingVerse: VerseRef?
    public private(set) var pendingStudy: PassageRef?
    /// The Deep Study unit presented over the tab bar, if any. Drives a full-screen cover.
    public var deepStudyKey: String?
    /// The `#anchor` the presented Deep Study should scroll to (`"apply-it"`).
    public var deepStudyAnchor: String?
    /// The passage whose note sheet should be raised, if any.
    public var noteKey: String?

    public init(
        selection: AppTab = .home,
        deepStudyKey: String? = nil,
        deepStudyAnchor: String? = nil
    ) {
        self.selection = selection
        self.deepStudyKey = deepStudyKey
        self.deepStudyAnchor = deepStudyAnchor
    }

    public func selectTab(_ tab: AppTab) {
        selection = tab
    }

    public func open(verse: VerseRef) {
        pendingVerse = verse
        deepStudyKey = nil
        selection = .quran
    }

    public func openDeepStudy(key: String) {
        pendingStudy = PassageRef(key: key)
        deepStudyAnchor = nil
        deepStudyKey = key
        selection = .discover
    }

    public func openNote(key: String) {
        noteKey = key
    }

    public func handle(_ link: DeepLink) {
        switch link {
        case let .verse(ref): open(verse: ref)
        case let .study(ref): openDeepStudy(key: ref.key)
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
///
/// Every tab is a real feature view. The stores come from the one `AppEnvironment` built at
/// launch and are injected once, here, so no feature reaches for a singleton:
/// `TranslationStore`, `StudyStore` and `UserStore` as observable environment values, the
/// entitlement bridge and the two navigation actions (`openPassage`, `openNote`) as
/// environment keys.
///
/// The `ReaderModel` is owned by this view rather than by `ReaderView`: a deep link mutates
/// the model that is already on screen (`open(verse:)`), and a parent-owned model paginates
/// the surah once instead of once per parent render.
///
/// `route` is the `--screenshot` route when there is one. It only changes *where inside a
/// tab* the shell lands — `translation-sheet` is the reader with its sheet already up — so a
/// capture goes through the same views a finger would reach.
@MainActor
public struct TabRoot: View {
    private let env: AppEnvironment
    private let route: ScreenRoute?
    @State private var model: TabRootModel
    @State private var reader: ReaderModel

    public init(env: AppEnvironment, model: TabRootModel? = nil, route: ScreenRoute? = nil) {
        self.env = env
        self.route = route
        _model = State(initialValue: model ?? TabRootModel(selection: route?.tab ?? .home))
        _reader = State(
            initialValue: ReaderModel(
                index: env.index,
                translations: env.translations,
                user: env.user,
                surah: 1,
                restoringSavedPosition: true
            )
        )
    }

    public var body: some View {
        TabView(selection: $model.selection) {
            CommunityView(store: env.user)
                .tabItem { Label(AppTab.community.title, systemImage: AppTab.community.systemImage) }
                .tag(AppTab.community)

            DiscoverScreens.screen(
                id: "discover",
                feed: env.feed,
                themes: env.themes,
                studies: env.studies,
                today: env.today
            )
            .tabItem { Label(AppTab.discover.title, systemImage: AppTab.discover.systemImage) }
            .tag(AppTab.discover)

            HomeScreenProvider.screen(id: homeRouteID, anchor: homeAnchor, env: env)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            quranTab
                .tabItem { Label(AppTab.quran.title, systemImage: AppTab.quran.systemImage) }
                .tag(AppTab.quran)
        }
        .tint(Color.textPrimary)
        .appStores(env, router: model)
        .fullCover(item: $model.deepStudyKey.identifiable) { key in
            deepStudy(key: key.value)
        }
        .onChange(of: model.pendingVerse) { _, verse in
            guard let verse else { return }
            reader.open(verse: verse)
            _ = model.consumePendingVerse()
        }
        .onChange(of: model.noteKey) { _, key in
            guard let key, let passage = PassageRef(key: key) else { return }
            model.noteKey = nil
            model.selection = .quran
            reader.open(verse: VerseRef(surah: passage.surah, ayah: passage.start))
            reader.present(.notes)
        }
        .task {
            // A deep link can arrive before this view exists (a cold launch from the widget).
            if let verse = model.consumePendingVerse() {
                reader.open(verse: verse)
            }
        }
        .accessibilityIdentifier("tabroot")
    }

    // MARK: - Tabs

    /// The reader, or the reader with the sheet a `--screenshot` route asked for.
    @ViewBuilder
    private var quranTab: some View {
        if let route, ReaderView.Screen(rawValue: route.screen.rawValue) != nil {
            ReaderView.screen(
                for: route.rawValue,
                index: env.index,
                translations: env.translations,
                user: env.user
            )
        } else {
            ReaderView(model: reader)
        }
    }

    private var homeRouteID: String {
        guard let id = route?.screen.rawValue, HomeScreenProvider.screenIDs.contains(id) else {
            return "home"
        }
        return id
    }

    private var homeAnchor: String? {
        homeRouteID == route?.screen.rawValue ? route?.anchor : nil
    }

    @ViewBuilder
    private func deepStudy(key: String) -> some View {
        DiscoverScreens.screen(
            id: "deepstudy",
            anchor: model.deepStudyAnchor,
            feed: env.feed,
            themes: env.themes,
            studies: env.studies,
            today: env.today,
            key: key
        )
        .appStores(env, router: model)
    }
}

// MARK: - Store injection

public extension View {
    /// Injects every store and navigation action a feature view reads out of the
    /// environment. One place, so a sheet or a full-screen cover — which starts a fresh
    /// environment — gets exactly the same set.
    ///
    /// `openPassage` and `openNote` are how `FeatureDiscover` navigates: it sits on the
    /// wrong side of the dependency arrow to know about `Router`, so the shell hands it
    /// closures instead.
    @MainActor
    func appStores(_ env: AppEnvironment, router: TabRootModel? = nil) -> some View {
        environment(env.translations)
            .environment(env.studies)
            .environment(env.user)
            .environment(\.appToday, env.today)
            .environment(\.entitlements, env.discoverEntitlements)
            .environment(\.router, router)
            .environment(\.openPassage, OpenPassageAction { passage in
                router?.open(verse: VerseRef(surah: passage.surah, ayah: passage.start))
            })
            .environment(\.openNote, OpenNoteAction { key in
                router?.openNote(key: key)
            })
    }
}

/// Wraps an optional `String` binding as an optional `Identifiable` so it can drive
/// `fullScreenCover(item:)`.
struct IdentifiableString: Identifiable, Hashable {
    let value: String
    var id: String { value }
}

extension Binding where Value == String? {
    var identifiable: Binding<IdentifiableString?> {
        Binding<IdentifiableString?>(
            get: { wrappedValue.map(IdentifiableString.init(value:)) },
            set: { wrappedValue = $0?.value }
        )
    }
}

public extension AppTab {
    /// Screen id this tab's route resolves to.
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
