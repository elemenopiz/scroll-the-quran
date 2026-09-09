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
    public static func tab(_ environment: HomeEnvironment, scroll: HomeScrollPosition = .top) -> some View {
        HomeView(
            store: environment.store,
            surahs: environment.surahs,
            translations: environment.translations,
            plans: environment.plans,
            navigation: environment.navigation,
            today: environment.today,
            initialScroll: scroll,
            restorePurchases: environment.restorePurchases
        )
    }

    /// The view behind a `--screenshot` route (and behind a deep link, once one exists).
    /// Sheets are rendered as full screens here: a snapshot has nobody to present them.
    @MainActor
    @ViewBuilder
    public static func screen(for route: HomeRoute, _ environment: HomeEnvironment) -> some View {
        switch route {
        case .home:
            tab(environment, scroll: .top)
        case .homeScrolled:
            tab(environment, scroll: .scrolled)
        case .plansSheet:
            ReadingPlansSheet(
                catalog: environment.plans,
                store: environment.store,
                surahs: environment.surahs,
                today: environment.today,
                navigation: environment.navigation
            )
        case .planDetail:
            planDetail(environment)
        case .verseSearch:
            VerseSearchView(surahs: environment.surahs, navigation: environment.navigation)
        case .library:
            LibraryView(
                store: environment.store,
                surahs: environment.surahs,
                translations: environment.translations,
                navigation: environment.navigation
            )
        case .settings:
            SettingsView(
                store: environment.store,
                translations: environment.translations,
                restorePurchases: environment.restorePurchases
            )
        case .widgetGallery:
            AddWidgetGuide()
        }
    }

    /// The detail for the active plan, or — with nothing running — the first plan the catalog
    /// points a new reader at, so the route always has something to render.
    @MainActor
    @ViewBuilder
    private static func planDetail(_ environment: HomeEnvironment) -> some View {
        if let plan = featuredPlan(environment) {
            PlanDetailSheet(
                plan: plan,
                store: environment.store,
                surahs: environment.surahs,
                today: environment.today,
                navigation: environment.navigation
            )
        } else {
            Color.appBackgroundFlat.accessibilityIdentifier("plan-detail")
        }
    }

    @MainActor
    static func featuredPlan(_ environment: HomeEnvironment) -> ReadingPlan? {
        if let active = environment.store.plan.activePlanID, let plan = environment.plans.plan(active) {
            return plan
        }
        return environment.plans.plans.first(where: \.startHere) ?? environment.plans.plans.first
    }
}
