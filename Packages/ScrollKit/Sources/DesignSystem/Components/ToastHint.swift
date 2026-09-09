import SwiftUI

/// The reader's dismissible coaching toast ("Tap or slide / to jump to any verse"):
/// 642x182 px (214x61 pt), `Color.cardBackground`, `Radius.chip`.
public struct ToastHint: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let onDismiss: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        onDismiss: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
            }
            if let onDismiss {
                Spacer(minLength: Spacing.md)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("toast.dismiss")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(minHeight: Metrics.toastHeight)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview("ToastHint light") {
    ToastHintPreviews().preferredColorScheme(.light)
}

#Preview("ToastHint dark") {
    ToastHintPreviews().preferredColorScheme(.dark)
}

private struct ToastHintPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            ToastHint(
                systemImage: "arrow.up.left",
                title: "Tap or slide",
                message: "to jump to any ayah",
                onDismiss: {}
            )
            ToastHint(
                systemImage: "hand.draw",
                title: "Swipe up",
                message: "for the next ayah"
            )
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
