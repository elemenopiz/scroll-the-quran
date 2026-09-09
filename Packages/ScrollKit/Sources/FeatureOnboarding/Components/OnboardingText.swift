import DesignSystem
import SwiftUI

/// The serif funnel headline. Spans marked `.boldItalic` in `Content/onboarding.json`
/// are drawn in the bundled italic face at bold weight, exactly as the reference does
/// with "2+ hours today".
struct HeadlineText: View {
    let spans: [OnboardingContent.Span]
    let size: CGFloat
    let pitch: CGFloat

    init(spans: [OnboardingContent.Span], size: CGFloat, pitch: CGFloat) {
        self.spans = spans
        self.size = size
        self.pitch = pitch
    }

    init(markdown: String, size: CGFloat, pitch: CGFloat) {
        self.init(spans: OnboardingMarkdown.spans(from: markdown), size: size, pitch: pitch)
    }

    init(plain: String, size: CGFloat, pitch: CGFloat) {
        self.init(spans: [OnboardingContent.Span(text: plain, style: .regular)], size: size, pitch: pitch)
    }

    var body: some View {
        spans
            .map { span in
                Text(span.text)
                    .font(span.style == .boldItalic ? .serifItalic(size).weight(.bold) : .serifDisplay(size))
            }
            .reduce(Text(verbatim: ""), +)
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(OnboardingMetrics.lineSpacing(family: FontFamily.serif, size: size, pitch: pitch))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(spans.plainText)
    }
}

/// The grey sans line under every funnel headline.
struct SubheadlineText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body(OnboardingMetrics.subheadlineSize, weight: .medium))
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
