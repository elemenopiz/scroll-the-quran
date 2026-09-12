import Commerce
import DesignSystem
import FeatureCommunity
import FeatureDiscover
import FeatureHome
import FeaturePaywall
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
public final class TabRootModel: Router, HomeNavigation {
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

    /// `HomeNavigation`: a plan day is a list of passage keys in reading order. The reader
    /// pages a surah at a time, so it opens on the first ayah of the first passage — where a
    /// reader would start — rather than trying to stitch the whole day into one scroll.
    public func openReader(refs: [String]) {
        guard let first = refs.lazy.compactMap(PassageRef.init(key:)).first else { return }
        open(verse: VerseRef(surah: first.surah, ayah: first.start))
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

    public init(env: AppEnvironment, model: TabRootModel? = nil, route: ScreenRoute? = nil) {
        self.env = env
        self.route = route
        _model = State(initialValue: model ?? TabRootModel(selection: route?.tab ?? .home))
    }

    /// The Quran tab's model, owned by the environment so it survives — and is built by —
    /// something other than a view initialiser that re-runs on every update.
    private var reader: ReaderModel {
        env.reader
    }

    public var body: some View {
        TabView(selection: $model.selection) {
            CommunityView(store: env.user)
                .tabItem {
                    Label(
                        AppTab.community.title,
                        systemImage: AppTab.community.tabSymbol(selected: model.selection == .community)
                    )
                }
                .tag(AppTab.community)

            DiscoverScreens.screen(
                id: "discover",
                feed: env.feed,
                themes: env.themes,
                studies: env.studies,
                today: env.today
            )
            .tabItem {
                Label(
                    AppTab.discover.title,
                    systemImage: AppTab.discover.tabSymbol(selected: model.selection == .discover)
                )
            }
            .tag(AppTab.discover)

            HomeScreenProvider.screen(id: homeRouteID, anchor: homeAnchor, env: env, navigation: model)
                .tabItem {
                    Label(
                        AppTab.home.title,
                        systemImage: AppTab.home.tabSymbol(selected: model.selection == .home)
                    )
                }
                .tag(AppTab.home)

            quranTab
                .tabItem {
                    Label(
                        AppTab.quran.title,
                        systemImage: AppTab.quran.tabSymbol(selected: model.selection == .quran)
                    )
                }
                .tag(AppTab.quran)
        }
        .tint(Color.textPrimary)
        // Unselected tabs draw the outline symbol, as the reference does; the selected
        // one asks for its filled name through `AppTab.tabSymbol(selected:)`. Without
        // this the tab bar fills every icon in both states.
        .outlineTabSymbols()
        .appStores(env, router: model)
        .fullCover(item: $model.deepStudyKey.identifiable) { key in
            deepStudy(key: key.value)
        }
        // Every locked surface lands on one sheet, so two gates cannot fight over the slot
        // and the funnel's paywall and this one are the same view with the same store.
        .sheet(isPresented: gateBinding) { gatePaywall }
        // Deep Study is premium wherever it is opened *through the router* — a deep link, a
        // share link, Home's Verse Search. The Discover card gates itself before it ever
        // sets a key. A `--screenshot deepstudy` route is exempt: the capture harness asks
        // for that screen by name and must get it.
        .onChange(of: model.deepStudyKey) { _, key in
            guard key != nil, route == nil, !env.entitlements.isPremium else { return }
            model.deepStudyKey = nil
            env.gate.request(.deepStudy)
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

    // MARK: - The paywall

    /// `PremiumGate.reason` as the boolean a `sheet` wants. Setting it false is the only
    /// way the sheet can report a swipe-to-dismiss, which `onDismiss` does not cover.
    private var gateBinding: Binding<Bool> {
        Binding(
            get: { env.gate.reason != nil },
            set: { if !$0 { env.gate.dismiss() } }
        )
    }

    /// The paywall a locked control raises.
    ///
    /// The one-time offer store is deliberately *not* `env.offers`: the gift envelope is the
    /// first-run funnel's consolation for dismissing the paywall, and burning it here would
    /// spend the customer's one discount on a tap they made while reading. An in-memory
    /// store that already says "seen" makes `PaywallFlow.dismissTrial()` return control
    /// straight to the app.
    private var gatePaywall: some View {
        PaywallFlow(
            store: env.entitlements,
            offers: InMemoryOneTimeOfferStore(seenOneTimeOffer: true),
            stage: .trial,
            links: env.legalLinks,
            onDismiss: { env.gate.dismiss() },
            onPurchased: { env.gate.dismiss() }
        )
        .accessibilityIdentifier("gate.paywall")
    }

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
            .environment(\.requestPremium, env.gate.discoverRequest)
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
    var id: String {
        value
    }
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
