import SwiftUI

/// The small capsule label: the Discover theme chip ("Joy in Trials", 79 px = 26 pt
/// tall, `Color.chipBackground`) and the Deep Study cross-reference chip
/// ("Romans 5:3-4", hairline border, `Color.crossRefChipBackground`).
public struct Chip: View {
    public enum Kind: Sendable {
        /// Filled theme chip on the Discover card and the Deep Study header.
        case theme
        /// Bordered cross-reference chip under a Deep Study section.
        case crossReference
    }

    private let text: String
    private let kind: Kind
    private let action: (() -> Void)?

    public init(_ text: String, kind: Kind = .theme, action: (() -> Void)? = nil) {
        self.text = text
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.pressable)
        } else {
            label
        }
    }

    private var label: some View {
        Text(text)
            .font(.body(fontSize, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(background, in: .capsule)
            .overlay {
                if kind == .crossReference {
                    Capsule().strokeBorder(Color.divider, lineWidth: Stroke.hairline)
                }
            }
            .contentShape(.capsule)
    }

    private var height: CGFloat {
        switch kind {
        case .theme: Metrics.chipHeight
        case .crossReference: Metrics.crossRefChipHeight
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .theme: Spacing.md
        case .crossReference: Spacing.lg
        }
    }

    private var fontSize: CGFloat {
        switch kind {
        case .theme: 13
        case .crossReference: 14
        }
    }

    private var background: Color {
        switch kind {
        case .theme: Color.chipBackground
        case .crossReference: Color.crossRefChipBackground
        }
    }

    private var foreground: Color {
        switch kind {
        case .theme: Color.textPrimary
        case .crossReference: Color.textSecondary
        }
    }
}

/// The green "Offline" badge on the translation sheet: 47 px (16 pt) tall.
public struct OfflineBadge: View {
    private let text: String

    public init(_ text: String = "Offline") {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.body(11, weight: .bold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, Spacing.sm)
            .frame(height: Metrics.badgeHeight)
            .background(Color.offlineBadge, in: .capsule)
            .accessibilityLabel("Available offline")
    }
}

#Preview("Chip light") {
    ChipPreviews().preferredColorScheme(.light)
}

#Preview("Chip dark") {
    ChipPreviews().preferredColorScheme(.dark)
}

private struct ChipPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Chip("Trust in Hardship")
            HStack(spacing: Spacing.md) {
                Chip("Al-Baqarah 2:286", kind: .crossReference) {}
                Chip("Ash-Sharh 94:5-6", kind: .crossReference) {}
            }
            OfflineBadge()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
