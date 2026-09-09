import DesignSystem
import SwiftUI

/// `onboarding-hook`: the opening claim, the subheadline, and the two calls to action.
/// Layout traced off `Reference/onboarding-hook.png`.
struct HookScreen: View {
    let content: OnboardingContent.Hook
    let onContinue: () -> Void
    let onAlreadySignedUp: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: OnboardingMetrics.headlineToSubheadline) {
                    HeadlineText(
                        spans: content.headline,
                        size: OnboardingMetrics.hookHeadlineSize,
                        pitch: OnboardingMetrics.hookHeadlinePitch
                    )
                    .accessibilityIdentifier("onboarding.hook.headline")

                    SubheadlineText(text: content.subheadline)
                        .accessibilityIdentifier("onboarding.hook.subheadline")
                }
                .padding(.horizontal, OnboardingMetrics.textInset)

                Spacer(minLength: 0)

                CallToActionStack {
                    SecondaryPillButton(
                        title: content.secondaryCTA,
                        identifier: "onboarding.hook.alreadySignedUp",
                        action: onAlreadySignedUp
                    )
                    PrimaryPillButton(
                        title: content.primaryCTA,
                        identifier: "onboarding.hook.continue",
                        action: onContinue
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding-hook")
    }
}

#Preview("Hook") {
    HookScreen(content: OnboardingContent.sample.hook, onContinue: {}, onAlreadySignedUp: {})
}
