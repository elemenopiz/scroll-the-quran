import SwiftUI

/// The wide uppercase section label: "BIBLICAL MEANING", "DID YOU KNOW?",
/// "DAYS OPENED". 11 pt semibold, `Tracking.caps`, optionally preceded by an SF Symbol
/// (Deep Study tints its icon, Home does not).
public struct CapsLabel: View {
    private let icon: String?
    private let text: String
    private let size: CGFloat
    private let tint: Color?

    public init(icon: String? = nil, text: String, size: CGFloat = 11, tint: Color? = nil) {
        self.icon = icon
        self.text = text
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size + 2, weight: .semibold))
                    .foregroundStyle(tint ?? Color.textSecondary)
            }
            Text(text)
                .capsLabelStyle(size: size)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#Preview("CapsLabel light") {
    CapsLabelPreviews().preferredColorScheme(.light)
}

#Preview("CapsLabel dark") {
    CapsLabelPreviews().preferredColorScheme(.dark)
}

private struct CapsLabelPreviews: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            CapsLabel(text: "Meaning")
            CapsLabel(icon: "clock", text: "Historical context", tint: .blue)
            CapsLabel(icon: "lightbulb.fill", text: "Did you know?", tint: .ratingStar)
            CapsLabel(text: "Days opened", size: 13)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appBackground)
    }
}
