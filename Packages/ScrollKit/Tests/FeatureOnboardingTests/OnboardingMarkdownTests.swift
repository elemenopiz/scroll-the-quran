@testable import FeatureOnboarding
import Testing

@Suite("Headline markdown")
struct OnboardingMarkdownTests {
    @Test("A triple-asterisk run becomes one bold-italic span between two regular ones")
    func parsesBoldItalicRun() {
        let spans = OnboardingMarkdown.spans(
            from: "The average Muslim will spend ***2+ hours today*** scrolling social media."
        )
        #expect(spans.count == 3)
        #expect(spans[0] == OnboardingContent.Span(text: "The average Muslim will spend ", style: .regular))
        #expect(spans[1] == OnboardingContent.Span(text: "2+ hours today", style: .boldItalic))
        #expect(spans[2] == OnboardingContent.Span(text: " scrolling social media.", style: .regular))
    }

    @Test("Double asterisks are treated the same way")
    func parsesDoubleAsterisk() {
        let spans = OnboardingMarkdown.spans(from: "give **2+ hours** back")
        #expect(spans.map(\.style) == [.regular, .boldItalic, .regular])
        #expect(spans[1].text == "2+ hours")
    }

    @Test("Text with no markers is a single regular span")
    func parsesPlainText() {
        let spans = OnboardingMarkdown.spans(from: "Lives are being changed.")
        #expect(spans == [OnboardingContent.Span(text: "Lives are being changed.", style: .regular)])
    }

    @Test("An unclosed marker is left as literal text rather than swallowing the rest")
    func leavesUnclosedMarkerAlone() {
        let spans = OnboardingMarkdown.spans(from: "half **open headline")
        #expect(spans.plainText == "half **open headline")
        #expect(spans.allSatisfy { span in span.style == .regular })
    }

    @Test("Two emphasised runs both survive")
    func parsesTwoRuns() {
        let spans = OnboardingMarkdown.spans(from: "**a** and **b**")
        #expect(spans.map(\.text) == ["a", " and ", "b"])
        #expect(spans.map(\.style) == [.boldItalic, .regular, .boldItalic])
    }

    @Test("Plain text drops every marker")
    func plainTextStripsMarkers() {
        #expect(
            OnboardingMarkdown.plainText(from: "spend ***2+ hours today*** scrolling")
                == "spend 2+ hours today scrolling"
        )
    }

    @Test("The shipped hook markdown and its pre-split spans agree")
    func markdownMatchesSpans() throws {
        let content = try OnboardingContentTests.repoContent()
        #expect(OnboardingMarkdown.spans(from: content.hook.headlineMarkdown) == content.hook.headline)
    }
}
