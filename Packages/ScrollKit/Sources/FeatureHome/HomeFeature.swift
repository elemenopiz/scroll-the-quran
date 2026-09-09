import DesignSystem
import QuranData
import SwiftUI
import UserState

/// The screens this feature can be routed to. The raw values are the same strings `AppShell`'s
/// `ScreenRoute.rawValue` produces (`ScreenID` plus an optional `#anchor`), so the composition
/// root can hand one straight over:
///
///     HomeRoute(rawValue: route.rawValue)
///
/// `FeatureHome` cannot name `AppShell.ScreenRoute` — `AppShell` depends on this package, not the
/// other way round — so the string is the seam.
public enum HomeRoute: String, CaseIterable, Sendable {
    case home
    case homeScrolled = "home#scrolled"
    case plansSheet = "plans-sheet"
    case planDetail = "plan-detail"
    case verseSearch = "verse-search"
    case library
    case settings
    case widgetGallery = "widget-gallery"

    /// Every route this feature answers to, for `AppShell`'s route table.
    public static func handles(_ rawValue: String) -> Bool {
        HomeRoute(rawValue: rawValue) != nil
    }
}

/// Everything the Home screens need, gathered once so `AppShell` builds it in one place.
@MainActor
public struct HomeEnvironment {
    public let store: UserStore
    public let surahs: SurahIndex
    public let translations: TranslationStore?
    public let plans: ReadingPlanCatalog
    public let navigation: (any HomeNavigation)?
    public let today: Date
    public let restorePurchases: (() async -> Void)?

    public init(
        store: UserStore,
        surahs: SurahIndex,
        translations: TranslationStore? = nil,
        plans: ReadingPlanCatalog = ReadingPlanCatalog(),
        navigation: (any HomeNavigation)? = nil,
        today: Date = Date(),
        restorePurchases: (() async -> Void)? = nil
    ) {
        self.store = store
        self.surahs = surahs
        self.translations = translations
        self.plans = plans
        self.navigation = navigation
        self.today = today
        self.restorePurchases = restorePurchases
    }
}

/// The feature's entry points.
public enum HomeFeature {
    /// The Home tab itself.
    @MainActor
    public static func tab(
        _ environment: HomeEnvironment,
        scroll: HomeScrollPosition = .top,
        sheet: HomeInitialSheet? = nil
    ) -> some View {
        HomeView(
            store: environment.store,
            surahs: environment.surahs,
            translations: environment.translations,
            plans: environment.plans,
            navigation: environment.navigation,
            today: environment.today,
            initialScroll: scroll,
            initialSheet: sheet,
            restorePurchases: environment.restorePurchases
        )
    }

    /// The view behind a `--screenshot` route (and behind a deep link, once one exists).
    /// The sheet routes are Home with that sheet already up, which is what the references show
    /// and what a deep link should land on.
    @MainActor
    @ViewBuilder
    public static func screen(for route: HomeRoute, _ environment: HomeEnvironment) -> some View {
        switch route {
        case .home:
            tab(environment, scroll: .top)
        case .homeScrolled:
            tab(environment, scroll: .scrolled)
        case .plansSheet:
            tab(environment, scroll: .top, sheet: .plans)
        case .planDetail:
            tab(environment, scroll: .top, sheet: .planDetail)
        case .verseSearch:
            VerseSearchView(surahs: environment.surahs, navigation: environment.navigation)
        case .library:
            tab(environment, scroll: .top, sheet: .library)
        case .settings:
            tab(environment, scroll: .top, sheet: .settings)
        case .widgetGallery:
            tab(environment, scroll: .top, sheet: .widgetGuide)
        }
    }
}
