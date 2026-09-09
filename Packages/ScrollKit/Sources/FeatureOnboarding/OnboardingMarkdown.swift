import Foundation

/// Turns the headline Markdown in `Content/onboarding.json` into styled spans.
///
/// Only the one inline style the funnel uses is supported: `***span***` (and `**span**`,
/// which the reference renders the same way) becomes `.boldItalic`. Anything else is
/// literal text — this is deliberately not a general Markdown parser.
public enum OnboardingMarkdown {
    public static func spans(from markdown: String) -> [OnboardingContent.Span] {
        var spans: [OnboardingContent.Span] = []
        var plain = ""
        var rest = Substring(markdown)

        func flushPlain() {
            guard !plain.isEmpty else { return }
            spans.append(OnboardingContent.Span(text: plain, style: .regular))
            plain = ""
        }

        while let open = rest.range(of: "***") ?? rest.range(of: "**") {
            let marker = String(rest[open])
            let head = rest[rest.startIndex ..< open.lowerBound]
            let tail = rest[open.upperBound...]
            guard let close = tail.range(of: marker) else { break }

            plain += head
            flushPlain()
            let emphasised = String(tail[tail.startIndex ..< close.lowerBound])
            if !emphasised.isEmpty {
                spans.append(OnboardingContent.Span(text: emphasised, style: .boldItalic))
            }
            rest = tail[close.upperBound...]
        }

        plain += rest
        flushPlain()
        return spans
    }

    /// The headline with every marker removed — the VoiceOver label and the UI-test string.
    public static func plainText(from markdown: String) -> String {
        spans(from: markdown).map(\.text).joined()
    }
}

public extension [OnboardingContent.Span] {
    var plainText: String {
        map(\.text).joined()
    }
}
