import SwiftUI

/// The filled capsule CTA: black on light, white on dark (`Color.pillFill`), bold
/// label in `Color.textOnPill`. Measured 168 px (56 pt) tall on onboarding-hook and
/// 195 px (65 pt) on paywall-trial, so the height is a parameter with the onboarding
/// value as the default. Always a true capsule — the corner profile of the reference
/// reaches zero inset at exactly half the height.
public struct PrimaryPillButton: View {
    private let title: String
    private let height: CGFloat
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        height: CGFloat = Metrics.pillHeight,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.height = height
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geoSemibold(17))
                .foregroundStyle(Color.textOnPill)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color.pillFill, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// The secondary CTA: same capsule, no fill, 1 pt hairline border
/// ("I already signed up on the web" on onboarding-hook, "Done" on the sheets).
public struct OutlinePillButton: View {
    private let title: String
    private let height: CGFloat
    private let action: () -> Void

    public init(
        _ title: String,
        height: CGFloat = Metrics.pillHeight,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geoSemibold(17))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay {
                    Capsule().strokeBorder(Color.divider, lineWidth: Stroke.hairline)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
    }
}

/// The press feedback the reference uses everywhere: a small scale, no tint change.
/// Under Reduce Motion the scale is dropped for a dimming instead.
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .opacity(reduceMotion && configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle {
        PressableButtonStyle()
    }
}

#Preview("Pill buttons light") {
    PillButtonPreviews().preferredColorScheme(.light)
}

#Preview("Pill buttons dark") {
    PillButtonPreviews().preferredColorScheme(.dark)
}

private struct PillButtonPreviews: View {
    var body: some View {
        VStack(spacing: Metrics.ctaStackSpacing) {
            OutlinePillButton("I already signed up on the web") {}
                .accessibilityIdentifier("gallery.outlinePill")
            PrimaryPillButton("Continue") {}
                .accessibilityIdentifier("gallery.primaryPill")
            PrimaryPillButton("Redeem 7 days for $0.00", height: Metrics.pillHeightLarge) {}
            PrimaryPillButton("Disabled", isEnabled: false) {}
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
