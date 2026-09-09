import Foundation
import StudyContent

/// The `#anchor` half of a `deepstudy#<section>` route.
///
/// The canonical id of a section is its `StudySection` case in kebab-case. The aliases
/// exist because `Reference/manifest.json` names the *reference app's* section titles
/// (`original-language`, `cross-references`), and those routes are what
/// `Tools/snapshot/thresholds.json` launches: `deepstudy#original-language` has to land
/// on our KEY ARABIC TERMS, which is the same slot in the same order.
public enum StudyAnchor {
    /// The scroll-target id used by `ScrollViewReader` and by `--screenshot deepstudy#<id>`.
    public static func id(for section: StudySection) -> String {
        switch section {
        case .meaning: "meaning"
        case .historicalContext: "historical-context"
        case .keyTerms: "key-terms"
        case .lifeInProphetsTime: "life-in-prophets-time"
        case .didYouKnow: "did-you-know"
        case .theologicalSignificance: "theological-significance"
        case .crossReferences: "cross-references"
        case .applyIt: "apply-it"
        case .exploreFurther: "explore-further"
        }
    }

    /// Ids that also resolve to a section, so a manifest route keeps working.
    public static func aliases(for section: StudySection) -> [String] {
        switch section {
        case .historicalContext: ["context", "context-of-revelation", "historical"]
        case .keyTerms: ["original-language", "key-arabic-terms", "keyterms"]
        case .lifeInProphetsTime: ["life-in-biblical-times", "life"]
        case .crossReferences: ["related-verses", "crossrefs", "crossreferences"]
        case .exploreFurther: ["explore-in-scripture", "explore"]
        case .theologicalSignificance: ["theological"]
        case .didYouKnow: ["dyk"]
        default: []
        }
    }

    /// Resolves an anchor written in a route. `nil` for "no anchor" and for the
    /// explicit `top`, both of which mean "do not scroll".
    public static func section(for anchor: String?) -> StudySection? {
        guard let anchor else { return nil }
        let needle = anchor.lowercased().trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty, needle != "top" else { return nil }
        return StudySection.displayOrder.first { section in
            id(for: section) == needle
                || section.rawValue.lowercased() == needle
                || aliases(for: section).contains(needle)
        }
    }
}
