import DesignSystem
import Foundation
import StudyContent
import SwiftUI

/// How each Deep Study section is drawn.
///
/// Four of the nine sit in a tinted box (the tints were measured from the reference
/// captures and live in `TintedSectionKind`); the rest are plain prose or lists on the
/// page background. The mapping is spelled out rather than derived so a new section
/// cannot silently inherit a tint.
public extension StudySection {
    /// The tint this section's box uses, or nil when it is drawn flat on the page.
    var tintedKind: TintedSectionKind? {
        switch self {
        case .historicalContext: .historical
        case .lifeInProphetsTime: .life
        case .didYouKnow: .dyk
        case .applyIt: .apply
        case .meaning, .keyTerms, .theologicalSignificance, .crossReferences, .exploreFurther: nil
        }
    }

    /// The SF Symbol drawn before the caps label, or nil.
    var headerSymbol: String? {
        switch self {
        case .historicalContext: "clock"
        case .lifeInProphetsTime: "building.columns"
        case .didYouKnow: "lightbulb.fill"
        case .theologicalSignificance: nil
        case .crossReferences: "link"
        case .applyIt: "heart.fill"
        case .meaning, .keyTerms, .exploreFurther: nil
        }
    }

    /// The icon tint. The label itself always stays `Tokens.textSecondary`.
    var headerSymbolTint: Color {
        tintedKind?.iconTint ?? .textSecondary
    }
}
