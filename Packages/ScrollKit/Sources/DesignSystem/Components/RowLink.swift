import SwiftUI

/// The Home settings row: a 40 pt circle, title, subtitle and a chevron, on a
/// `Radius.cardSmall` card. Measured 200 px (67 pt) tall with 16 pt padding.
public struct RowLink: View {
    private let systemImage: String
    private let title: String
    private let subtitle: String?
    private let action: () -> Void

    public init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: Metrics.rowLinkIcon, height: Metrics.rowLinkIcon)
                    .background(Color.chipBackground, in: .circle)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.body(17, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.body(15))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer(minLength: Spacing.md)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Metrics.rowPadding)
            .frame(minHeight: Metrics.rowLinkHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.cardSmall, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
    }
}

#Preview("RowLink light") {
    RowLinkPreviews().preferredColorScheme(.light)
}

#Preview("RowLink dark") {
    RowLinkPreviews().preferredColorScheme(.dark)
}

private struct RowLinkPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            RowLink(systemImage: "bookmark.fill", title: "Saved", subtitle: "Your library") {}
                .accessibilityIdentifier("gallery.rowLink.saved")
            RowLink(
                systemImage: "iphone",
                title: "Add a Quran Verse Widget",
                subtitle: "Put an ayah on your Lock or Home Screen"
            ) {}
            RowLink(systemImage: "gear", title: "Settings") {}
        }
        .padding(Metrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
