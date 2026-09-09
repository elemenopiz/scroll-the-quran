import SwiftUI

/// One row of the paywall trial timeline: a 40 pt (120 px) filled circle carrying an
/// SF Symbol, a 2 pt (6 px) `#D3D1C7` connector down to the next node, and the
/// title/subtitle pair beside it.
public struct TimelineStep: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let isLast: Bool

    public init(systemImage: String, title: String, message: String, isLast: Bool = false) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.isLast = isLast
    }

    /// Measured on paywall-trial: node centres are 252 px apart, so the connector
    /// occupies whatever is left below a node once the text has laid out.
    public static let connectorColor = Color(rgb: 0xD3D1C7)

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            VStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textOnPill)
                    .frame(width: Metrics.timelineNode, height: Metrics.timelineNode)
                    .background(Color.pillFill, in: .circle)
                if !isLast {
                    Rectangle()
                        .fill(TimelineStep.connectorColor)
                        .frame(width: Metrics.timelineConnector)
                        .frame(maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.geoBold(19))
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.body(18))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Spacing.xxxl)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("TimelineStep light") {
    TimelineStepPreviews().preferredColorScheme(.light)
}

#Preview("TimelineStep dark") {
    TimelineStepPreviews().preferredColorScheme(.dark)
}

private struct TimelineStepPreviews: View {
    var body: some View {
        VStack(spacing: 0) {
            TimelineStep(
                systemImage: "lock",
                title: "Today",
                message: "Open the Quran like never before. Full access, everything unlocked"
            )
            TimelineStep(
                systemImage: "bell",
                title: "Day 5",
                message: "A reminder with your week in the Quran"
            )
            TimelineStep(
                systemImage: "checkmark",
                title: "Day 7",
                message: "Pick a reading plan and continue ayah by ayah",
                isLast: true
            )
        }
        .padding(Spacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackgroundFlat)
    }
}
