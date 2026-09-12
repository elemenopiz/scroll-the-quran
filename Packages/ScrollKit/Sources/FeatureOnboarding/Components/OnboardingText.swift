import DesignSystem
import SwiftUI

/// The serif funnel headline. Spans marked `.boldItalic` in `Content/onboarding.json`
/// are drawn in the bundled italic face at bold weight, exactly as the reference does
/// with "2+ hours today".
struct HeadlineText: View {
    let spans: [OnboardingContent.Span]
    let size: CGFloat
    let extraLineSpacing: CGFloat
    let columnWidth: CGFloat
    /// SwiftUI wraps a headline noticeably narrower than the column it is given
    /// (its balanced line-break strategy). Pinning the line count is what makes the
    /// wrap land on the reference's words; `minimumScaleFactor` keeps longer copy
    /// shrinking rather than truncating.
    let lineLimit: Int

    init(spans: [OnboardingContent.Span], size: CGFloat, extraLineSpacing: CGFloat, columnWidth: CGFloat, lineLimit: Int) {
        self.spans = spans
        self.size = size
        self.extraLineSpacing = extraLineSpacing
        self.columnWidth = columnWidth
        self.lineLimit = lineLimit
    }

    init(markdown: String, size: CGFloat, extraLineSpacing: CGFloat, columnWidth: CGFloat, lineLimit: Int) {
        self.init(
            spans: OnboardingMarkdown.spans(from: markdown), size: size,
            extraLineSpacing: extraLineSpacing, columnWidth: columnWidth, lineLimit: lineLimit
        )
    }

    init(plain: String, size: CGFloat, extraLineSpacing: CGFloat, columnWidth: CGFloat, lineLimit: Int) {
        self.init(
            spans: [OnboardingContent.Span(text: plain, style: .regular)], size: size,
            extraLineSpacing: extraLineSpacing, columnWidth: columnWidth, lineLimit: lineLimit
        )
    }

    var body: some View {
        spans
            .map { span in
                Text(span.text).font(font(for: span.style))
            }
            .reduce(Text(verbatim: ""), +)
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(extraLineSpacing)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.8)
            .frame(width: columnWidth)
            .accessibilityLabel(spans.plainText)
    }

    /// `.leading(.tight)` pulls Source Serif 4's 1.37 em default line height back towards
    /// the reference's baseline pitch; `extraLineSpacing` trims the rest.
    private func font(for style: OnboardingContent.Span.Style) -> Font {
        let base: Font = style == .boldItalic ? .serifItalic(size).weight(.bold) : .serifDisplay(size)
        return base.leading(.tight)
    }
}

/// The grey sans line under every funnel headline.
struct SubheadlineText: View {
    let text: String
    var size: CGFloat = OnboardingMetrics.subheadlineSize

    var body: some View {
        Text(text)
            .font(.body(size, weight: .medium))
            .foregroundStyle(Color.textTertiaryReadable)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}
