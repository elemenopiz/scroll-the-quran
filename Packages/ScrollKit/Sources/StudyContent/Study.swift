import Foundation
import QuranData

/// How a unit was selected for generation. `Tools/content-gen/schema/study.schema.json`
/// declares this as a string enum, and the pipeline writes it on every assembled unit.
public enum StudyTier: String, Codable, Hashable, Sendable, CaseIterable {
    /// A curated Discover-feed unit.
    case discover
    /// A named or landmark passage.
    case core
    /// Everything else.
    case standard

    /// Unknown or absent tiers read as `standard` rather than failing the whole shard.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StudyTier(rawValue: raw) ?? .standard
    }
}

/// One Deep Study unit: the commentary for a passage such as `"1:5-7"` or `"2:255"`.
///
/// The wire format is what `Tools/content-gen/schema/study.schema.json` emits, one shard per
/// surah. `surah`, `start` and `end` are written by the generator but are also derivable from
/// `key`, so decoding falls back to the key when a hand-written fixture omits them.
public struct Study: Codable, Hashable, Sendable, Identifiable {
    /// An Arabic term named by the study. There is no transliteration field by design: the app
    /// shows the Arabic script followed by the English gloss (CLAUDE.md rule 5).
    public struct KeyTerm: Codable, Hashable, Sendable, Identifiable {
        public let arabic: String
        public let gloss: String
        public let note: String

        public var id: String {
            arabic
        }

        public init(arabic: String, gloss: String, note: String) {
            self.arabic = arabic
            self.gloss = gloss
            self.note = note
        }
    }

    /// A related ayah and the one-line reason it is related.
    public struct CrossRef: Codable, Hashable, Sendable, Identifiable {
        public let ref: String
        public let why: String

        public var id: String {
            ref
        }

        public init(ref: String, why: String) {
            self.ref = ref
            self.why = why
        }

        public var passage: PassageRef? {
            PassageRef(key: ref)
        }
    }

    /// Provenance, so a shard can be regenerated or audited later.
    public struct Meta: Codable, Hashable, Sendable {
        public let model: String
        public let promptVersion: String
        public let generatedAt: String
        public let reviewed: Bool

        public init(model: String, promptVersion: String, generatedAt: String, reviewed: Bool) {
            self.model = model
            self.promptVersion = promptVersion
            self.generatedAt = generatedAt
            self.reviewed = reviewed
        }

        public static let unknown = Meta(model: "", promptVersion: "", generatedAt: "", reviewed: false)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
            promptVersion = try container.decodeIfPresent(String.self, forKey: .promptVersion) ?? ""
            generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt) ?? ""
            reviewed = try container.decodeIfPresent(Bool.self, forKey: .reviewed) ?? false
        }
    }

    /// Spelled out (rather than synthesised) so the field list is inspectable: the tests check
    /// it against `Tools/content-gen/schema/study.schema.json`.
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case key, surah, start, end, theme, themeId, title, tier
        case meaning, historicalContext, keyTerms, lifeInProphetsTime, didYouKnow
        case theologicalSignificance, crossReferences, applyIt, exploreFurther
        case explainEasier, meta
    }

    public let key: String
    public let surah: Int
    public let start: Int
    public let end: Int
    public let theme: String
    public let themeId: String
    public let title: String
    public let tier: StudyTier
    public let meaning: String
    public let historicalContext: String
    public let keyTerms: [KeyTerm]
    public let lifeInProphetsTime: String
    public let didYouKnow: String
    public let theologicalSignificance: String
    public let crossReferences: [CrossRef]
    public let applyIt: String
    public let exploreFurther: [String]
    /// The passage told to a twelve-year-old: 25-50 plain words, shown in the verse menu under
    /// "Explain Easier". Optional — only units the simplify pass has been through carry it
    /// (`Tools/content-gen/author.mjs rewrite`), so every call site must handle nil.
    public let explainEasier: String?
    public let meta: Meta

    public var id: String {
        key
    }

    public var passage: PassageRef {
        PassageRef(surah: surah, start: start, end: end)
    }

    public var verses: [VerseRef] {
        passage.verses
    }

    public init(
        key: String,
        surah: Int? = nil,
        start: Int? = nil,
        end: Int? = nil,
        theme: String = "",
        themeId: String = "",
        title: String,
        tier: StudyTier = .standard,
        meaning: String = "",
        historicalContext: String = "",
        keyTerms: [KeyTerm] = [],
        lifeInProphetsTime: String = "",
        didYouKnow: String = "",
        theologicalSignificance: String = "",
        crossReferences: [CrossRef] = [],
        applyIt: String = "",
        exploreFurther: [String] = [],
        explainEasier: String? = nil,
        meta: Meta = .unknown
    ) {
        let parsed = PassageRef(key: key)
        self.key = key
        self.surah = surah ?? parsed?.surah ?? 0
        self.start = start ?? parsed?.start ?? 0
        self.end = end ?? parsed?.end ?? 0
        self.theme = theme
        self.themeId = themeId
        self.title = title
        self.tier = tier
        self.meaning = meaning
        self.historicalContext = historicalContext
        self.keyTerms = keyTerms
        self.lifeInProphetsTime = lifeInProphetsTime
        self.didYouKnow = didYouKnow
        self.theologicalSignificance = theologicalSignificance
        self.crossReferences = crossReferences
        self.applyIt = applyIt
        self.exploreFurther = exploreFurther
        self.explainEasier = explainEasier
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let parsed = PassageRef(key: key)
        self.key = key
        surah = try container.decodeIfPresent(Int.self, forKey: .surah) ?? parsed?.surah ?? 0
        start = try container.decodeIfPresent(Int.self, forKey: .start) ?? parsed?.start ?? 0
        end = try container.decodeIfPresent(Int.self, forKey: .end) ?? parsed?.end ?? 0
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? ""
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        tier = try container.decodeIfPresent(StudyTier.self, forKey: .tier) ?? .standard
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning) ?? ""
        historicalContext = try container.decodeIfPresent(String.self, forKey: .historicalContext) ?? ""
        keyTerms = try container.decodeIfPresent([KeyTerm].self, forKey: .keyTerms) ?? []
        lifeInProphetsTime = try container.decodeIfPresent(String.self, forKey: .lifeInProphetsTime) ?? ""
        didYouKnow = try container.decodeIfPresent(String.self, forKey: .didYouKnow) ?? ""
        theologicalSignificance = try container.decodeIfPresent(String.self, forKey: .theologicalSignificance) ?? ""
        crossReferences = try container.decodeIfPresent([CrossRef].self, forKey: .crossReferences) ?? []
        applyIt = try container.decodeIfPresent(String.self, forKey: .applyIt) ?? ""
        exploreFurther = try container.decodeIfPresent([String].self, forKey: .exploreFurther) ?? []
        // Absent on every unit written before the simplify pass, and an empty string is the same
        // thing as absent: the verse menu hides the row either way.
        let easier = try container.decodeIfPresent(String.self, forKey: .explainEasier)
        explainEasier = (easier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : easier
        }
        meta = try container.decodeIfPresent(Meta.self, forKey: .meta) ?? .unknown
    }
}

public extension Study {
    /// The body of a prose section, or nil for the three list-shaped sections.
    func prose(for section: StudySection) -> String? {
        switch section {
        case .meaning: meaning
        case .historicalContext: historicalContext
        case .lifeInProphetsTime: lifeInProphetsTime
        case .didYouKnow: didYouKnow
        case .theologicalSignificance: theologicalSignificance
        case .applyIt: applyIt
        case .keyTerms, .crossReferences, .exploreFurther: nil
        }
    }

    /// Whether the section has anything to render. Sections that came back empty are skipped.
    func hasContent(_ section: StudySection) -> Bool {
        switch section {
        case .keyTerms: !keyTerms.isEmpty
        case .crossReferences: !crossReferences.isEmpty
        case .exploreFurther: !exploreFurther.isEmpty
        default: !(prose(for: section) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Whether there is an "Explain Easier" line to offer for this unit.
    var hasExplainEasier: Bool {
        explainEasier != nil
    }

    /// The sections to render, in the fixed display order, skipping empty ones.
    var populatedSections: [StudySection] {
        StudySection.displayOrder.filter { hasContent($0) }
    }

    /// The related and explore-further references that actually parse.
    var relatedPassages: [PassageRef] {
        crossReferences.compactMap { PassageRef(key: $0.ref) }
    }

    var explorePassages: [PassageRef] {
        exploreFurther.compactMap { PassageRef(key: $0) }
    }
}
