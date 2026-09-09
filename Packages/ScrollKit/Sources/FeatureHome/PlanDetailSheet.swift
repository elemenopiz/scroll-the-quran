import DesignSystem
import QuranData
import SwiftUI
import UserState

/// One reading plan, full page: hero cover, title, meta, the start/continue button, the "about"
/// box and the three fact rows. Measured against `onboarding-slide2-plan-detail.png`.
public struct PlanDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let plan: ReadingPlan
    // `@Observable`: reading `store` in `body` is enough to track it; no binding is needed.
    private let store: UserStore
    private let surahs: SurahIndex?
    private let today: Date
    private let navigation: (any HomeNavigation)?
    private let premium: HomePremiumStatus
    private let requestPremium: HomePremiumRequest

    public init(
        plan: ReadingPlan,
        store: UserStore,
        surahs: SurahIndex? = nil,
        today: Date = Date(),
        navigation: (any HomeNavigation)? = nil,
        premium: HomePremiumStatus = .unlocked,
        requestPremium: HomePremiumRequest = HomePremiumRequest()
    ) {
        self.plan = plan
        self.store = store
        self.surahs = surahs
        self.today = today
        self.navigation = navigation
        self.premium = premium
        self.requestPremium = requestPremium
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                OutlinePillButton("Close", height: 40) { dismiss() }
                    .frame(width: 92)
                    .accessibilityIdentifier("planDetail.close")
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, HomeMetrics.planDetailHeaderTop)
            .frame(minHeight: Metrics.headerButton)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    hero
                        .padding(.top, HomeMetrics.planDetailHeroTopPadding - Spacing.md)
                        .padding(.bottom, Spacing.sm)
                    Text(plan.title)
                        .font(.body(22, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(plan.metaLine)
                        .font(.body(15))
                        .foregroundStyle(Color.textSecondary)
                    startButton
                    aboutBox
                    factsBox
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.huge)
            }
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("plan-detail")
    }

    private var hero: some View {
        Color.clear
            .aspectRatio(HomeMetrics.planHeroAspect, contentMode: .fit)
            .overlay { PlanCoverImage(plan: plan) }
            .clipShape(.rect(cornerRadius: HomeMetrics.planHeroRadius, style: .continuous))
    }

    private var isActive: Bool {
        store.plan.activePlanID == plan.id
    }

    /// Reading plans are premium. The button keeps its label — the reference app does not
    /// grey it out — and a free reader gets the paywall instead of the plan, so nothing is
    /// written to `UserStore` for a plan that was never bought.
    private var startButton: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryPillButton(isActive ? "Continue" : "Start Plan", height: Metrics.pillHeightCompact) {
                guard premium.isPremium else {
                    requestPremium(.readingPlan)
                    return
                }
                if !isActive {
                    store.startPlan(plan.id, on: today)
                }
                openTodaysDay()
            }
            .accessibilityIdentifier("planDetail.start")
            if !premium.isPremium {
                Label("Reading plans are part of Premium", systemImage: "lock.fill")
                    .font(.body(13))
                    .foregroundStyle(Color.textTertiary)
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("planDetail.premiumNote")
            }
        }
    }

    /// Hands the reader today's refs. Reading a plan day is what "start" means; the button also
    /// records the plan so Home can show "Day 1" the moment the sheet closes.
    private func openTodaysDay() {
        let resolved = TodaysReading.resolve(
            catalog: ReadingPlanCatalog(plans: [plan]),
            activePlanID: plan.id,
            startedAt: store.plan.startedAt ?? today,
            completedDays: store.plan.completedDays,
            now: today,
            calendar: store.calendar
        )
        let refs = resolved?.refs ?? plan.day(1)?.refs ?? []
        guard !refs.isEmpty else { return }
        navigation?.openReader(refs: refs)
        dismiss()
    }

    private var aboutBox: some View {
        CardContainer(radius: Radius.card, padding: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                CapsLabel(text: "About this plan")
                Text(plan.about)
                    .font(.body(16))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var factsBox: some View {
        CardContainer(radius: Radius.card, padding: 0) {
            VStack(spacing: 0) {
                factRow("person.2", "Best for", plan.bestFor, isLast: false)
                factRow("calendar", "Length", lengthLine, isLast: false)
                factRow("clock", "Daily commitment", plan.dailyCommitment, isLast: true)
            }
        }
    }

    private var lengthLine: String {
        let days = "\(plan.lengthDays) day\(plan.lengthDays == 1 ? "" : "s")"
        guard let last = plan.schedule.last, let first = plan.schedule.first, last.day > first.day else {
            return days
        }
        return "\(days) · \(plan.schedule.count) sittings"
    }

    private func factRow(_ systemImage: String, _ title: String, _ value: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.body(14))
                        .foregroundStyle(Color.textSecondary)
                    Text(value)
                        .font(.body(16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .accessibilityElement(children: .combine)

            if !isLast {
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: Stroke.hairline)
                    .padding(.leading, Spacing.lg + 22 + Spacing.md)
            }
        }
    }
}
