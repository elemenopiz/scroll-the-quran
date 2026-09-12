import DesignSystem
import QuranData
import SwiftUI

/// The "Today's Reading" card: cover, plan title, today's refs, "Day n of N" and a progress bar.
/// With no plan running it becomes the "Pick a plan to begin" invitation and opens the sheet.
struct TodaysReadingCard: View {
    let today: TodaysReading?
    let surahs: SurahIndex?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CardContainer(radius: Radius.card, padding: HomeMetrics.todayCardPadding) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        cover
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Today's Reading")
                                .font(.body(HomeMetrics.todayTitle, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            if let today {
                                Text(today.plan.title)
                                    .font(.body(17, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(today.refsLine(using: surahs))
                                    .font(.body(16))
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(today.dayLabel)
                                    .font(.body(15))
                                    .foregroundStyle(Color.textTertiaryReadable)
                            } else {
                                Text("Pick a plan to begin")
                                    .font(.body(17, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("Choose a reading plan and follow it one day at a time.")
                                    .font(.body(16))
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if let today {
                        ProgressBar(value: today.completion, height: HomeMetrics.todayProgressHeight)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.todaysReading")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cover: some View {
        PlanCoverImage(plan: today?.plan)
            .frame(width: HomeMetrics.todayCover, height: HomeMetrics.todayCover)
            .clipShape(.rect(cornerRadius: HomeMetrics.todayCoverRadius, style: .continuous))
    }

    private var accessibilityLabel: String {
        guard let today else { return "Today's reading. Pick a plan to begin." }
        return "Today's reading. \(today.plan.title). \(today.refsLine(using: surahs)). \(today.dayLabel)."
    }
}
