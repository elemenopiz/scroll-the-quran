import Commerce
import FeatureDiscover
import FeatureReader
import Foundation
import QuranData
import StudyContent
import SwiftUI
import UserState

private struct AppTodayKey: EnvironmentKey {
    static let defaultValue = Date()
}

public extension EnvironmentValues {
    /// "Today" for streaks, the daily feed and the widget. Pinned by
    /// `SCROLL_FIXED_DATE` during snapshots so captures are reproducible.
    var appToday: Date {
        get { self[AppTodayKey.self] }
        set { self[AppTodayKey.self] = newValue }
    }
}

/// The composition root.
///
/// One place builds every long-lived store, exactly once, at launch: the bundled content
/// (`SurahIndex`, `TranslationStore`, `StudyStore`, `DiscoverFeed`, `ThemeIndex`), the
/// user's own state (`UserStore`, App Group JSON) and commerce (`StoreKitEntitlementStore`,
/// started at launch so `Transaction.updates` is listening before the paywall appears).
///
/// Under `--screenshot` and UI-test runs the StoreKit store is swapped for
/// `MockEntitlementStore`, which quotes `Config/ScrollTheQuran.storekit` prices with no
/// store round-trip — a snapshot must be the same picture every time it is taken.
///
/// Content that fails to load degrades to an empty store rather than crashing: the app
/// still runs, `loadFailures` records what was missing, and the screens show their empty
/// states.
@MainActor
public final class AppEnvironment {
    public let launch: LaunchOptions
    /// `SCROLL_FIXED_DATE` when set, otherwise the wall clock at launch.
    public let today: Date

    public let index: SurahIndex
    public let translations: TranslationStore
    public let studies: StudyStore
    public let feed: DiscoverFeed
    public let themes: ThemeIndex
    public let user: UserStore

    /// The one long-lived commerce store. Live StoreKit in the app, mock under snapshots.
    public let entitlements: any Commerce.EntitlementProviding
    public let offers: any OneTimeOfferStoring
    /// `FeatureDiscover` declares its own one-boolean entitlement protocol (it does not
    /// depend on `Commerce`); this adapts the store above onto it.
    public let discoverEntitlements: any FeatureDiscover.EntitlementProviding

    /// Content files that could not be read, for diagnostics. Empty in a healthy build.
    public private(set) var loadFailures: [String] = []

    /// The Quran tab's reader, built once and kept for the life of the process.
    ///
    /// It has to live here rather than in `TabRoot`: a SwiftUI view's `init` runs on every
    /// parent update, and this model restores `Prefs.lastReaderPosition` — which writes the
    /// position straight back to `UserStore`. Built inside a view initialiser that is a
    /// mutation of observed state *during* body evaluation, which invalidates the body that
    /// is being evaluated: the render never settles and the screen stays blank.
    public private(set) lazy var reader: ReaderModel = .init(
        index: index,
        translations: translations,
        user: user,
        surah: 1,
        restoringSavedPosition: true
    )

    /// The unit a bare `deepstudy` route opens. Resolving it walks the day's feed and loads a
    /// shard, so it is answered once rather than on every render.
    public private(set) lazy var defaultStudyKey: String? = DiscoverScreens.defaultStudyKey(
        feed: feed,
        studies: studies,
        today: today
    )

    public init(
        launch: LaunchOptions,
        index: SurahIndex,
        translations: TranslationStore,
        studies: StudyStore,
        feed: DiscoverFeed,
        themes: ThemeIndex,
        user: UserStore,
        entitlements: any Commerce.EntitlementProviding,
        offers: any OneTimeOfferStoring,
        loadFailures: [String] = []
    ) {
        self.launch = launch
        today = launch.fixedDate ?? Date()
        self.index = index
        self.translations = translations
        self.studies = studies
        self.feed = feed
        self.themes = themes
        self.user = user
        self.entitlements = entitlements
        self.offers = offers
        self.loadFailures = loadFailures
        discoverEntitlements = DiscoverEntitlementBridge(entitlements)
    }

    /// The process's one environment.
    ///
    /// `RootView.init` runs on every update, so it cannot afford to build this: a second
    /// `StoreKitEntitlementStore` would start a second `Transaction.updates` listener, and
    /// the content would be parsed again. Resolved once, on first use.
    public static func shared(launch: LaunchOptions = .live) -> AppEnvironment {
        if let existing = cached {
            return existing
        }
        let environment = live(launch: launch)
        cached = environment
        return environment
    }

    private static var cached: AppEnvironment?

    /// Test hook: forget the shared environment.
    public static func resetShared() {
        cached = nil
    }

    /// Builds everything the running app needs.
    public static func live(launch: LaunchOptions = .live) -> AppEnvironment {
        var failures: [String] = []

        let index = (try? SurahIndex(locator: .shared)) ?? Self.emptyIndex()
        if index.count == 0 {
            failures.append("quran/surahs.json")
        }

        let user = UserStore.shared()

        let translations: TranslationStore
        if let loaded = try? TranslationStore(locator: .shared, selectedID: user.prefs.translationID) {
            translations = loaded
        } else {
            failures.append("quran/translations.json")
            translations = TranslationStore(registry: Self.emptyRegistry(), index: index)
        }

        let loader = BundleContentLoader()
        let studies: StudyStore
        if let loaded = try? StudyStore(loader: loader) {
            studies = loaded
        } else {
            failures.append("study/passages.json")
            studies = StudyStore.empty()
        }

        let feed: DiscoverFeed
        if let loaded = try? DiscoverFeed(loader: loader, store: studies) {
            feed = loaded
        } else {
            failures.append("discover.json")
            feed = DiscoverFeed(items: [])
        }

        let themes = (try? ThemeIndex(loader: loader)) ?? .empty
        if themes.count == 0 {
            failures.append("themes.json")
        }

        // One store for the life of the process. `StoreKitEntitlementStore.init` starts the
        // `Transaction.updates` listener, so it has to be created at launch — not when the
        // paywall is first shown — or a renewal that lands early is missed.
        let entitlements: any Commerce.EntitlementProviding =
            launch.usesFixtureCommerce ? Commerce.MockEntitlementStore() : StoreKitEntitlementStore()

        return AppEnvironment(
            launch: launch,
            index: index,
            translations: translations,
            studies: studies,
            feed: feed,
            themes: themes,
            user: user,
            entitlements: entitlements,
            offers: UserOneTimeOfferStore(user),
            loadFailures: failures
        )
    }

    /// Kicks the store into loading its catalogue. Idempotent.
    public func start() async {
        await entitlements.load()
    }

    // MARK: - Degraded fallbacks

    private static func emptyIndex() -> SurahIndex {
        // `SurahIndex(surahs:)` only throws on an inconsistent list; the empty one is valid.
        (try? SurahIndex(surahs: [])) ?? {
            // Unreachable: the empty list always validates.
            fatalError("SurahIndex(surahs: []) must not throw")
        }()
    }

    private static func emptyRegistry() -> TranslationRegistry {
        let json = #"{"version":0,"defaultID":"itani","translations":[]}"#
        // The literal is a compile-time constant that matches `TranslationRegistry`'s shape.
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(TranslationRegistry.self, from: Data(json.utf8))
    }
}

/// Adapts `Commerce.EntitlementProviding` (`isPremium`, plus the whole purchase surface)
/// onto the single boolean `FeatureDiscover` asks for. Observation flows through the
/// computed property, so the Discover gate still re-renders when the entitlement changes.
@MainActor
final class DiscoverEntitlementBridge: FeatureDiscover.EntitlementProviding {
    private let store: any Commerce.EntitlementProviding

    init(_ store: any Commerce.EntitlementProviding) {
        self.store = store
    }

    var isSubscribed: Bool {
        store.isPremium
    }
}

/// `UserStore` already persists "the envelope has been shown"; this is the `Commerce`
/// seam onto it. An adapter rather than a retroactive conformance, so neither module has
/// to know about the other.
@MainActor
final class UserOneTimeOfferStore: OneTimeOfferStoring {
    private let user: UserStore

    init(_ user: UserStore) {
        self.user = user
    }

    var seenOneTimeOffer: Bool {
        get { user.hasSeenOneTimeOffer }
        set {
            if newValue {
                user.markOneTimeOfferSeen()
            }
        }
    }
}
