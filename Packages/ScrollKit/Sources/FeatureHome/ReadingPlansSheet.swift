import DesignSystem
import QuranData
import SwiftUI
import UserState

/// The Reading Plans sheet: the active plan at the top, then the catalog's sections as a
/// two-column grid of `PlanCard`s. Measured against the phone-frame mockup on
/// `onboarding-slide2-plans.png`.
public struct ReadingPlansSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let catalog: ReadingPlanCatalog
    @Bindable private var store: UserStore
    private let surahs: SurahIndex?
    private let today: Date
    private let navigation: (any HomeNavigation)?

    @State private var detail: ReadingPlan?

    public init(
        catalog: ReadingPlanCatalog,
        store: UserStore,
        surahs: SurahIndex? = nil,
        today: Date = Date(),
        navigation: (any HomeNavigation)? = nil,
        initialDetail: ReadingPlan? = nil
    ) {
        self.catalog = catalog
        self.store = store
        self.surahs = surahs
        self.today = today
        self.navigation = navigation
        _detail = State(initialValue: initialDetail)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Reading Plans", showsDivider: false) {
                OutlinePillButton("Done", height: 40) { dismiss() }
                    .frame(width: 92)
                    .accessibilityIdentifier("plans.done")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: HomeMetrics.planSectionSpacing) {
                    activePlanSection
                    ForEach(catalog.populatedSections) { section in
                        planSection(section)
                    }
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.huge)
            }
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("plans-sheet")
        .sheet(item: $detail) { plan in
            PlanDetailSheet(
                plan: plan,
                store: store,
                surahs: surahs,
                today: today,
                navigation: navigation
            )
        }
    }

    // MARK: Active plan

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

    private var activePlanSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            CapsLabel(text: "Your active plan")
            activePlanCard
        }
        .padding(.top, Spacing.md)
    }

    private var activePlanCard: some View {
        Button {
            if let plan = todaysReading?.plan {
                detail = plan
            }
        } label: {
            CardContainer(radius: Radius.card, padding: HomeMetrics.todayCardPadding) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        // With nothing running the card still carries artwork — the cover of the
                        // plan the section below points a new reader at.
                        PlanCoverImage(plan: todaysReading?.plan ?? invitationPlan)
                            .frame(width: HomeMetrics.activePlanCover, height: HomeMetrics.activePlanCover)
                            .clipShape(.rect(cornerRadius: HomeMetrics.todayCoverRadius, style: .continuous))
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(todaysReading?.plan.title ?? "Pick a plan to begin")
                                .font(.body(17, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(activeBlurb)
                                .font(.body(15))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    if let todaysReading {
                        ProgressBar(value: todaysReading.completion, height: Metrics.progressBarHeight)
                    }
                    Label(todaysReading == nil ? "Browse plans" : "Open this plan", systemImage: "arrow.down")
                        .font(.body(16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .labelStyle(.reversedTitleAndIcon)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("plans.activePlan")
    }

    /// The plan the empty state is inviting the reader into.
    private var invitationPlan: ReadingPlan? {
        catalog.plans.first(where: \.startHere) ?? catalog.plans.first
    }

    private var activeBlurb: String {
        guard let todaysReading else {
            return "New to the Quran? The first section below is where to start — short plans, in order, no prior reading needed."
        }
        return "\(todaysReading.dayLabel) · \(todaysReading.refsLine(using: surahs))"
    }

    // MARK: Sections

    private func planSection(_ section: ReadingPlanSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let eyebrow = section.eyebrow {
                CapsLabel(text: eyebrow)
            }
            Text(section.title)
                .font(.serifDisplay(26, relativeTo: .title2))
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let blurb = section.blurb {
                Text(blurb)
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: gridColumns, spacing: HomeMetrics.planGridSpacing) {
                ForEach(catalog.plans(in: section)) { plan in
                    PlanCard(
                        title: plan.title,
                        meta: plan.metaLine,
                        tagline: plan.subtitle,
                        ribbon: plan.startHere ? "Start here" : nil
                    ) {
                        PlanCoverImage(plan: plan)
                    } action: {
                        detail = plan
                    }
                    // Three single lines under the cover, as in the reference. `lineLimit` and
                    // `minimumScaleFactor` reach the labels inside `PlanCard`; letting a long
                    // title wrap instead pushes the next grid row down by most of a line.
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("plans.card.\(plan.id)")
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: HomeMetrics.planGridSpacing),
            GridItem(.flexible(), spacing: HomeMetrics.planGridSpacing),
        ]
    }
}

/// Title first, then the glyph — the "Browse plans ↓" arrangement.
struct ReversedTitleAndIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == ReversedTitleAndIconLabelStyle {
    static var reversedTitleAndIcon: ReversedTitleAndIconLabelStyle {
        ReversedTitleAndIconLabelStyle()
    }
}
