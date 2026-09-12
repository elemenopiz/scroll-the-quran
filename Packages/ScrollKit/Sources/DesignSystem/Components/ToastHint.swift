import SwiftUI

/// The reader's dismissible coaching toast ("Tap or slide / to jump to any verse"):
/// 642x182 px (214x61 pt), `Color.cardBackground`, `Radius.chip`.
///
/// The width is pinned rather than derived. Left to size itself from its paddings the
/// box came out 262 pt — 48 pt wider than the reference — because the 16 pt page-margin
/// paddings, an 18 pt glyph and a 32 pt close button are each a little generous. The
/// measured insets in `Metrics.toast*` reproduce the reference box, and the two labels
/// take a small shrink rather than wrapping if a translation runs long.
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
                .font(.system(size: Metrics.toastIconGlyph, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if let onDismiss {
                Spacer(minLength: Spacing.xs)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: Metrics.toastCloseGlyph, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: Metrics.toastCloseButton, height: Metrics.toastCloseButton)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("toast.dismiss")
            }
        }
        .padding(.leading, Metrics.toastLeadingPadding)
        .padding(.trailing, onDismiss == nil ? Metrics.toastLeadingPadding : Metrics.toastTrailingPadding)
        .frame(width: Metrics.toastWidth, alignment: .leading)
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
