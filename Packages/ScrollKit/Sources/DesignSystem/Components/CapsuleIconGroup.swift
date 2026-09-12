import SwiftUI

/// One item inside a `CapsuleIconGroup`. `id` doubles as the accessibility identifier
/// suffix, so `reader.toolbar` + `dice` becomes `reader.toolbar.dice`.
public struct CapsuleIconItem: Identifiable {
    public let id: String
    public let systemImage: String
    public let label: String
    public let isOn: Bool
    public let action: @MainActor () -> Void

    public init(
        id: String,
        systemImage: String,
        label: String,
        isOn: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.systemImage = systemImage
        self.label = label
        self.isOn = isOn
        self.action = action
    }
}

/// The reader toolbar's grouped icon pills — `[dice][heart]` share one capsule
/// (`Color.cardBackground`, 106 px = 36 pt tall) rather than each getting its own.
public struct CapsuleIconGroup: View {
    private let items: [CapsuleIconItem]
    private let identifierPrefix: String

    public init(identifierPrefix: String, items: [CapsuleIconItem]) {
        self.identifierPrefix = identifierPrefix
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: Metrics.capsuleGroupIcon, weight: .medium))
                        .foregroundStyle(item.isOn ? Color.textPrimary : Color.textSecondary)
                        .padding(.horizontal, Metrics.capsuleGroupItemPadding)
                        .frame(height: Metrics.capsuleGroupHeight)
                        // 36 pt visual, 44 pt hit target (audit A11Y-5) without moving a pixel.
                        .contentShape(Rectangle().inset(by: -(Metrics.hitTarget - Metrics.capsuleGroupHeight) / 2))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(item.label)
                .accessibilityIdentifier("\(identifierPrefix).\(item.id)")
            }
        }
        .padding(.horizontal, Spacing.xs)
        .background(Color.cardBackground, in: .capsule)
    }
}

#Preview("CapsuleIconGroup light") {
    CapsuleIconGroupPreviews().preferredColorScheme(.light)
}

#Preview("CapsuleIconGroup dark") {
    CapsuleIconGroupPreviews().preferredColorScheme(.dark)
}

private struct CapsuleIconGroupPreviews: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            CapsuleIconGroup(
                identifierPrefix: "reader.toolbar",
                items: [
                    CapsuleIconItem(id: "shuffle", systemImage: "dice", label: "Random verse") {},
                    CapsuleIconItem(id: "favourite", systemImage: "heart", label: "Favourites") {},
                ]
            )
            CapsuleIconGroup(
                identifierPrefix: "reader.translation",
                items: [
                    CapsuleIconItem(id: "itani", systemImage: "textformat", label: "Translation") {},
                ]
            )
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
