import Foundation
import StudyContent

/// What the copy buttons put on the pasteboard.
///
/// Pure string formatting, kept out of the views so the shape is pinned by tests: a
/// section copies as its caps title, a blank line, then its body; the whole study copies
/// as the citation, the quoted ayah, then every populated section in display order.
/// Nothing is localised yet — the reference app copies plain text.
public enum StudyCopy {
    /// Separator between a section's title and its body, and between list rows.
    public static let paragraphBreak = "\n\n"
    /// Between an Arabic term or a reference and its gloss.
    public static let dash = " — "

    /// The body of one section, without its title.
    public static func body(_ section: StudySection, of study: Study) -> String {
        switch section {
        case .keyTerms:
            study.keyTerms
                .map { term in
                    let head = "\(term.arabic)\(dash)\(term.gloss)"
                    return term.note.isEmpty ? head : "\(head)\n\(term.note)"
                }
                .joined(separator: paragraphBreak)
        case .crossReferences:
            study.crossReferences
                .map { $0.why.isEmpty ? $0.ref : "\($0.ref)\(dash)\($0.why)" }
                .joined(separator: "\n")
        case .exploreFurther:
            study.exploreFurther.joined(separator: "\n")
        default:
            study.prose(for: section) ?? ""
        }
    }

    /// One section, titled — what the little copy button beside a caps label writes.
    public static func section(_ section: StudySection, of study: Study) -> String {
        let text = body(section, of: study)
        guard !text.isEmpty else { return section.displayTitle }
        return "\(section.displayTitle)\(paragraphBreak)\(text)"
    }

    /// The whole Deep Study, in display order, skipping sections that came back empty.
    ///
    /// - Parameters:
    ///   - reference: the citation line, e.g. `"Al-Fatihah 1:5-7"`.
    ///   - quote: the English text of the passage, already joined.
    ///   - attribution: the translation credit the licence requires, appended last.
    public static func all(
        _ study: Study,
        reference: String,
        quote: String,
        attribution: String? = nil
    ) -> String {
        var blocks: [String] = []
        if !reference.isEmpty {
            blocks.append(reference)
        }
        if !quote.isEmpty {
            blocks.append(quote)
        }
        blocks.append(contentsOf: study.populatedSections.map { section($0, of: study) })
        if let attribution, !attribution.isEmpty {
            blocks.append(attribution)
        }
        return blocks.joined(separator: paragraphBreak)
    }

    /// What the Discover card's share sheet hands over: citation, ayah, credit.
    public static func card(reference: String, quote: String, attribution: String? = nil) -> String {
        [reference, quote, attribution]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: paragraphBreak)
    }
}
