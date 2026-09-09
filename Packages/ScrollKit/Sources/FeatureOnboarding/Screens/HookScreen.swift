import DesignSystem
import SwiftUI

/// `onboarding-hook`: the opening claim, the subheadline, and the two calls to action.
/// Layout traced off `Reference/onboarding-hook.png`.
struct HookScreen: View {
    let content: OnboardingContent.Hook
    let scale: ReferenceScale
    let onContinue: () -> Void
    let onAlreadySignedUp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: scale.height(OnboardingMetrics.headlineToSubheadline)) {
                HeadlineText(
                    spans: content.headline,
                    size: scale.type(OnboardingMetrics.hookHeadlineSize),
                    extraLineSpacing: scale.height(OnboardingMetrics.hookHeadlineExtraLineSpacing),
                    columnWidth: scale.width(OnboardingMetrics.hookHeadlineWidth),
                    lineLimit: OnboardingMetrics.hookHeadlineLines
                )
                .accessibilityIdentifier("onboarding.hook.headline")

                SubheadlineText(
                    text: content.subheadline,
                    size: scale.type(OnboardingMetrics.subheadlineSize)
                )
                .accessibilityIdentifier("onboarding.hook.subheadline")
            }
            .padding(.horizontal, scale.width(OnboardingMetrics.textInset))

            Spacer(minLength: 0)

            CallToActionStack(scale: scale) {
                SecondaryPillButton(
                    title: content.secondaryCTA,
                    identifier: "onboarding.hook.alreadySignedUp",
                    scale: scale,
                    action: onAlreadySignedUp
                )
                PrimaryPillButton(
                    title: content.primaryCTA,
                    identifier: "onboarding.hook.continue",
                    scale: scale,
                    action: onContinue
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding-hook")
    }
}

#Preview("Hook") {
    OnboardingCanvas { scale in
        HookScreen(content: OnboardingContent.sample.hook, scale: scale, onContinue: {}, onAlreadySignedUp: {})
    }
    .background(Color.appBackground)
}
