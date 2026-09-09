import DesignSystem
import SwiftUI

/// The black capsule at the bottom of every funnel screen.
///
/// Local to `FeatureOnboarding` on purpose: Phase 2c is building the shared
/// `DesignSystem` components in parallel. Fold this into that once it lands —
/// see the report's "duplicates for consolidation" note.
struct PrimaryPillButton: View {
    let title: String
    let identifier: String
    let scale: ReferenceScale
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body(scale.type(17), weight: .semibold))
                .foregroundStyle(Color.textOnPill)
                .frame(maxWidth: .infinity)
                .frame(height: scale.height(OnboardingMetrics.ctaHeight))
                .background(Color.pillFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// The hairline-outlined capsule above it ("I already signed up on the web").
struct SecondaryPillButton: View {
    let title: String
    let identifier: String
    let scale: ReferenceScale
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body(scale.type(17), weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: scale.height(OnboardingMetrics.ctaHeight))
                .overlay(
                    Capsule().strokeBorder(Color.divider, lineWidth: OnboardingMetrics.secondaryStroke)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// The bottom call-to-action stack shared by the hook, the slides and the reviews screen.
struct CallToActionStack<Content: View>: View {
    let scale: ReferenceScale
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: scale.height(OnboardingMetrics.ctaSpacing)) {
            content
        }
        .padding(.horizontal, scale.width(OnboardingMetrics.ctaHorizontalInset))
        .padding(.bottom, scale.height(OnboardingMetrics.ctaBottomPadding))
    }
}
