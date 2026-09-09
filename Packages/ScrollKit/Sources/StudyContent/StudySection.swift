import Foundation

/// The nine Deep Study sections, in the order they are always rendered. `allCases` is the
/// display order — the reference screens never reorder or interleave them.
public enum StudySection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case meaning
    case historicalContext
    case keyTerms
    case lifeInProphetsTime
    case didYouKnow
    case theologicalSignificance
    case crossReferences
    case applyIt
    case exploreFurther

    public var id: String {
        rawValue
    }

    /// The caps label printed above the section on the Deep Study screen.
    public var displayTitle: String {
        switch self {
        case .meaning: "MEANING"
        case .historicalContext: "CONTEXT OF REVELATION"
        case .keyTerms: "KEY ARABIC TERMS"
        case .lifeInProphetsTime: "LIFE IN THE PROPHET'S TIME"
        case .didYouKnow: "DID YOU KNOW?"
        case .theologicalSignificance: "THEOLOGICAL SIGNIFICANCE"
        case .crossReferences: "RELATED VERSES"
        case .applyIt: "APPLY IT"
        case .exploreFurther: "EXPLORE FURTHER"
        }
    }

    /// The fixed render order. Spelled out rather than derived so a reordering of the enum
    /// cases can never silently reshuffle the screen.
    public static let displayOrder: [StudySection] = [
        .meaning, .historicalContext, .keyTerms, .lifeInProphetsTime, .didYouKnow,
        .theologicalSignificance, .crossReferences, .applyIt, .exploreFurther,
    ]

    /// Sections whose body is a single block of prose.
    public var isProse: Bool {
        switch self {
        case .meaning, .historicalContext, .lifeInProphetsTime, .didYouKnow,
             .theologicalSignificance, .applyIt:
            true
        case .keyTerms, .crossReferences, .exploreFurther:
            false
        }
    }
}
