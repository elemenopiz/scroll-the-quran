import DesignSystem
import QuranData
import SwiftUI
import UserState

/// Where the Home scroll view starts. `scrolled` reproduces the `home#scrolled` reference:
/// the Today's Reading card is all but off the top, leaving the stat cards, the two rows and
/// the settings pill on screen.
public enum HomeScrollPosition: String, Sendable {
    case top
    case scrolled
}

/// The Home tab: verse search, today's reading, the two stat cards, the library and widget rows,
/// and the settings pill. Everything it needs is handed in, so a snapshot run and a preview build
/// exactly the same view as the app does.
public struct HomeView: View {
    // `@Observable`: reading `store` in `body` is enough to track it; no binding is needed.
    private let store: UserStore
    private let surahs: SurahIndex
    private let translations: TranslationStore?
    private let catalog: ReadingPlanCatalog
    private let navigation: (any HomeNavigation)?
    private let today: Date
    private let initialScroll: HomeScrollPosition
    private let restorePurchases: (() async -> Void)?
    private let premium: HomePremiumStatus
    private let requestPremium: HomePremiumRequest

    @State private var search: VerseSearchModel
    @State private var route: HomeSheet?

    /// Identifier of the invisible anchor that parks the scroll view for `home#scrolled`.
    static let scrolledAnchorID = "home.scrolledAnchor"

    /// Main-actor: the initialiser reads `UserStore.plan` to resolve `initialSheet`.
    @MainActor
    public init(
        store: UserStore,
        surahs: SurahIndex,
        translations: TranslationStore? = nil,
        plans: ReadingPlanCatalog = ReadingPlanCatalog(),
        navigation: (any HomeNavigation)? = nil,
        today: Date = Date(),
        initialScroll: HomeScrollPosition = .top,
        initialSheet: HomeInitialSheet? = nil,
        restorePurchases: (() async -> Void)? = nil,
        premium: HomePremiumStatus = .unlocked,
        requestPremium: HomePremiumRequest = HomePremiumRequest()
    ) {
        self.store = store
        self.surahs = surahs
        self.translations = translations
        catalog = plans
        self.navigation = navigation
        self.today = today
        self.initialScroll = initialScroll
        self.restorePurchases = restorePurchases
        self.premium = premium
        self.requestPremium = requestPremium
        _search = State(initialValue: VerseSearchModel(index: surahs))
        _route = State(initialValue: initialSheet.map { sheet in
            switch sheet {
            case .plans: .plans
            case .planDetail: .planDetail(HomeView.featuredPlan(in: plans, activeID: store.plan.activePlanID))
            case .library: .library
            case .widgetGuide: .widgetGuide
            case .settings: .settings
            }
        })
    }

    /// The plan the `plan-detail` route opens: whatever is running, else the catalog's first
    /// "start here" plan, else its first plan at all.
    static func featuredPlan(in catalog: ReadingPlanCatalog, activeID: String?) -> ReadingPlan? {
        if let activeID, let plan = catalog.plan(activeID) {
            return plan
        }
        return catalog.plans.first(where: \.startHere) ?? catalog.plans.first
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VerseSearchCard(model: search) { key in
                        studyVerse(key)
                    }
                    .padding(.bottom, HomeMetrics.cardGap)

                    todaysReadingCard
                        .padding(.bottom, HomeMetrics.cardGap)

                    streakCard
                        .padding(.bottom, HomeMetrics.cardGap)

                    progressCard
                        .padding(.bottom, HomeMetrics.rowGap)

                    RowLink(systemImage: "bookmark.fill", title: "Saved", subtitle: "Your library") {
                        route = .library
                    }
                    .lineLimit(1)
                    .accessibilityIdentifier("home.savedRow")
                    .padding(.bottom, HomeMetrics.rowGap)

                    RowLink(
                        systemImage: "iphone",
                        title: "Add a Quran Verse Widget",
                        subtitle: "Put an ayah on your Lock or Home Screen"
                    ) {
                        route = .widgetGuide
                    }
                    // `RowLink` sizes itself from its text; both rows are one line tall in the
                    // reference, and `lineLimit` reaches the labels inside the component.
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("home.widgetRow")
                    .padding(.bottom, HomeMetrics.rowGap)

                    settingsPill
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, HomeMetrics.contentTopPadding)
                .padding(.bottom, HomeMetrics.contentBottomPadding)
            }
            .background(Color.appBackground)
            .onAppear {
                guard initialScroll == .scrolled else { return }
                proxy.scrollTo(HomeView.scrolledAnchorID, anchor: .top)
            }
            // Scrolled, the card stack runs up under the clock and the Dynamic Island —
            // worst on `home#scrolled`, where "Pick a plan to begin" sits behind them.
            // The page's own ground, faded out, rather than an inset that would leave a
            // band of empty page at the top of an unscrolled Home.
            .statusBarScrim(Color.appBackground)
        }
        .accessibilityIdentifier("home")
        .sheet(item: $route) { sheet in
            sheetContent(sheet)
        }
    }

    // MARK: Cards

    private var todaysReadingCard: some View {
        TodaysReadingCard(today: todaysReading, surahs: surahs) {
            route = .plans
        }
        // An overlay, so the anchor costs no layout: its top edge is `scrolledFragment` above the
        // card's bottom, which is exactly where the reference capture parks the scroll view.
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(width: 1, height: HomeMetrics.scrolledFragment)
                .allowsHitTesting(false)
                .id(HomeView.scrolledAnchorID)
        }
    }

    private var streakCard: some View {
        StatCard(
            emblem: .flame,
            systemImage: "flame.fill",
            value: "\(streak)",
            caption: StreakMotivation.daysOpenedCaption
        ) {
            VStack(alignment: .leading, spacing: HomeMetrics.statFooterSpacing) {
                Text(StreakMotivation.line(forStreak: streak))
                    .font(.body(HomeMetrics.streakMessage))
                    .foregroundStyle(Color.textPrimary)
                    // One line in the reference, edge to edge of the card. Shrinking beats
                    // wrapping here: a second line pushes every card below it down by 21 pt.
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                StreakWeekRow(days: store.weekRow(now: today))
            }
        }
        // `StatCard`'s trailing slot is an image, not a control; Home's share glyph is tappable,
        // so it goes on top rather than through the slot.
        .overlay(alignment: .topTrailing) {
            Button {
                navigation?.open(verse: shareVerse)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: Metrics.headerButton, height: Metrics.headerButton)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("home.shareStreak")
            .accessibilityLabel("Share your streak")
            .padding(.trailing, Spacing.sm)
            .padding(.top, Spacing.sm)
        }
        // The overlay puts a second child beside `StatCard`, so the identifier below lands on a
        // plain container and SwiftUI pushes it down onto both — `home.streakCard` then resolved
        // to whichever came first, and the card's frame read as the share glyph's. Marking the
        // pair a container keeps the identifier on the card.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.streakCard")
    }

    private var progressCard: some View {
        StatCard(
            emblem: .tinted(HomeTokens.readEmblem),
            systemImage: "book.fill",
            value: store.percentReadLabel,
            caption: ReadProgressSummary.caption
        ) {
            VStack(alignment: .leading, spacing: HomeMetrics.statFooterSpacing + Spacing.xs) {
                ProgressBar(value: ReadProgressSummary(readCount: store.readCount).fraction)
                Text(store.versesReadLabel)
                    .font(.body(HomeMetrics.streakMessage))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityIdentifier("home.progressCard")
    }

    private var settingsPill: some View {
        Button {
            route = .settings
        } label: {
            Text("Settings / Manage Account")
                .font(.serifBody(HomeMetrics.settingsPillText))
                .foregroundStyle(Color.textOnPill)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.pillHeightCompact)
                .background(Color.pillFill, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.settingsPill")
    }

    // MARK: Gating

    /// "Study This Verse" opens Deep Study, which is premium. A free reader gets the
    /// paywall instead — the same one the Discover card's "Deep study >" raises.
    private func studyVerse(_ key: String) {
        guard premium.isPremium else {
            requestPremium(.verseSearch)
            return
        }
        navigation?.openDeepStudy(key: key)
    }

    // MARK: Derived state

    private var streak: Int {
        store.currentStreak(asOf: today)
    }

    private var todaysReading: TodaysReading? {
        TodaysReading.resolve(
            catalog: catalog,
            activePlanID: store.plan.activePlanID,
            startedAt: store.plan.startedAt,
            completedDays: store.plan.completedDays,
            now: today,
            calendar: store.calendar
        )
    }

    /// What the share glyph opens: today's first passage if a plan is running, else Al-Fatiha 1.
    private var shareVerse: VerseRef {
        guard let passage = todaysReading?.passages.first else { return VerseRef(surah: 1, ayah: 1) }
        return VerseRef(surah: passage.surah, ayah: passage.start)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .plans:
            ReadingPlansSheet(
                catalog: catalog,
                store: store,
                surahs: surahs,
                today: today,
                navigation: navigation,
                premium: premium,
                requestPremium: requestPremium
            )
        case let .planDetail(plan):
            if let plan {
                PlanDetailSheet(
                    plan: plan,
                    store: store,
                    surahs: surahs,
                    today: today,
                    navigation: navigation,
                    premium: premium,
                    requestPremium: requestPremium
                )
            }
        case .library:
            LibraryView(store: store, surahs: surahs, translations: translations, navigation: navigation)
        case .widgetGuide:
            AddWidgetGuide()
        case .settings:
            SettingsView(
                store: store,
                translations: translations,
                restorePurchases: restorePurchases,
                paymentIssue: premium.paymentIssue
            )
        }
    }
}

/// The sheets Home presents.
enum HomeSheet: Identifiable {
    case plans
    case planDetail(ReadingPlan?)
    case library
    case widgetGuide
    case settings

    var id: String {
        switch self {
        case .plans: "plans"
        case let .planDetail(plan): "planDetail.\(plan?.id ?? "none")"
        case .library: "library"
        case .widgetGuide: "widgetGuide"
        case .settings: "settings"
        }
    }
}

/// A sheet Home can be routed straight into (`--screenshot plans-sheet`, a deep link).
public enum HomeInitialSheet: String, CaseIterable, Sendable {
    case plans
    case planDetail
    case library
    case widgetGuide
    case settings
}
