import DesignSystem
import SwiftUI
import UserState

/// The seven Monday-to-Sunday dots under the streak count: a filled flame dot for a day the app
/// was opened, an empty well for a missed or future one, and a ring around today either way.
struct StreakWeekRow: View {
    let days: [StreakDay]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let style = StreakDotStyle.forDay(
                    isOpened: day.isOpened,
                    isToday: day.isToday,
                    isFuture: day.isFuture
                )
                VStack(spacing: HomeMetrics.streakLetterGap) {
                    Text(day.letter)
                        .font(.body(HomeMetrics.streakLetter, weight: .semibold))
                        .foregroundStyle(style.isRinged ? Color.textPrimary : Color.textSecondary)
                    dot(style)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(for: day, index: index, style: style))
            }
        }
        .accessibilityIdentifier("home.streakWeek")
    }

    private func dot(_ style: StreakDotStyle) -> some View {
        ZStack {
            Circle()
                .fill(style.isFilled ? AnyShapeStyle(LinearGradient.flame) : AnyShapeStyle(Color.progressTrack))
                .frame(width: HomeMetrics.streakDot, height: HomeMetrics.streakDot)
                .overlay {
                    if style.isFilled {
                        Image(systemName: "flame.fill")
                            .font(.system(size: HomeMetrics.streakDot * 0.42, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            if style.isRinged {
                Circle()
                    .strokeBorder(Color.textPrimary, lineWidth: HomeMetrics.streakRingWidth)
                    .frame(width: HomeMetrics.streakRing, height: HomeMetrics.streakRing)
            }
        }
        .frame(width: HomeMetrics.streakRing, height: HomeMetrics.streakRing)
    }

    /// The letters repeat (T, T and S, S), so VoiceOver gets the weekday name, not the initial.
    private func label(for day: StreakDay, index: Int, style: StreakDotStyle) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let name = names.indices.contains(index) ? names[index] : day.letter
        let state = switch style {
        case .today: "opened, today"
        case .todayPending: "not opened yet, today"
        case .opened: "opened"
        case .empty: day.isFuture ? "still to come" : "missed"
        }
        return "\(name), \(state)"
    }
}
