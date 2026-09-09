import Foundation
import QuranData
@testable import StudyContent
import Testing

/// One unit exactly as `Tools/content-gen/schema/study.schema.json` describes it, including the
/// fields a hand-written fixture may leave to be derived. Kept verbatim so a schema change on the
/// Node side breaks this test rather than the app.
private let schemaSample = """
{
  "key": "2:255",
  "surah": 2,
  "start": 255,
  "end": 255,
  "theme": "Oneness of God",
  "themeId": "tawhid",
  "title": "The Throne Verse",
  "tier": "discover",
  "meaning": "The longest single description of God in the Quran.",
  "historicalContext": "Medinan, and widely recited from early on.",
  "keyTerms": [
    {
      "arabic": "\\u0627\\u0644\\u0642\\u064a\\u0651\\u0648\\u0645",
      "gloss": "the Sustainer",
      "note": "The one who holds everything up."
    },
    {
      "arabic": "\\u0627\\u0644\\u0643\\u064f\\u0631\\u0633\\u0650\\u064a\\u0651",
      "gloss": "the Throne, the Footstool",
      "note": "Commentators read it as dominion rather than furniture."
    }
  ],
  "lifeInProphetsTime": "Reported as the ayah the Prophet Muhammad, peace be upon him, singled out.",
  "didYouKnow": "It is the 261st verse of the Quran counted end to end.",
  "theologicalSignificance": "Sovereignty and mercy stated in one breath.",
  "crossReferences": [
    { "ref": "112:1-4", "why": "The same claim, compressed to four lines." }
  ],
  "applyIt": "Read it once tonight before you sleep.",
  "exploreFurther": ["112:1-4", "59:22-24"],
  "meta": {
    "model": "claude-opus-5",
    "promptVersion": "p1",
    "generatedAt": "2026-09-09T00:00:00Z",
    "reviewed": false
  }
}
"""

@Test("A unit in the generator's schema shape decodes into Study with every field intact")
func schemaSampleDecodes() throws {
    let study = try JSONDecoder().decode(Study.self, from: Data(schemaSample.utf8))
    #expect(study.key == "2:255")
    #expect(study.passage == PassageRef(surah: 2, start: 255, end: 255))
    #expect(study.themeId == "tawhid")
    #expect(study.tier == .discover)
    #expect(study.keyTerms.count == 2)
    #expect(study.keyTerms[0].gloss == "the Sustainer")
    #expect(study.crossReferences.first?.ref == "112:1-4")
    #expect(study.crossReferences.first?.passage == PassageRef(surah: 112, start: 1, end: 4))
    #expect(study.exploreFurther == ["112:1-4", "59:22-24"])
    #expect(study.meta.model == "claude-opus-5")
    #expect(study.meta.reviewed == false)
    #expect(study.relatedPassages.count == 1)
    #expect(study.explorePassages.count == 2)
}

@Test("Study survives an encode/decode round trip unchanged")
func studyRoundTrips() throws {
    let study = try JSONDecoder().decode(Study.self, from: Data(schemaSample.utf8))
    let again = try JSONDecoder().decode(Study.self, from: JSONEncoder().encode(study))
    #expect(again == study)
}

@Test("If the generator's schema file is present, Study covers every property it declares")
func studyCoversTheGeneratorSchema() throws {
    let schemaURL = repoRoot.appendingPathComponent("Tools/content-gen/schema/study.schema.json")
    guard FileManager.default.fileExists(atPath: schemaURL.path) else { return }
    let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
    let properties: [String] = ((schema?["properties"] as? [String: Any]) ?? [:]).keys.sorted()
    #expect(!properties.isEmpty, "the schema declares no properties")
    let known = Set(Study.CodingKeys.allCases.map(\.stringValue))
    let unknown = Set(properties).subtracting(known)
    #expect(unknown.isEmpty, "Study cannot decode \(unknown.sorted())")
}

@Test("surah, start and end fall back to the key when the generator leaves them out")
func passageIsDerivedFromTheKey() throws {
    let json = #"{ "key": "94:5-6", "title": "Ease with hardship" }"#
    let study = try JSONDecoder().decode(Study.self, from: Data(json.utf8))
    #expect(study.surah == 94)
    #expect(study.start == 5)
    #expect(study.end == 6)
    #expect(study.verses.map(\.key) == ["94:5", "94:6"])
    #expect(study.tier == .standard)
    #expect(study.meta == .unknown)
}

@Test("The nine sections render in one fixed order with the reference screen's titles")
func sectionsHaveAFixedOrder() {
    #expect(StudySection.displayOrder == StudySection.allCases)
    #expect(StudySection.displayOrder.map(\.displayTitle) == [
        "MEANING",
        "CONTEXT OF REVELATION",
        "KEY ARABIC TERMS",
        "LIFE IN THE PROPHET'S TIME",
        "DID YOU KNOW?",
        "THEOLOGICAL SIGNIFICANCE",
        "RELATED VERSES",
        "APPLY IT",
        "EXPLORE FURTHER",
    ])
    #expect(StudySection.displayOrder.count == 9)
    #expect(Set(StudySection.allCases.map(\.displayTitle)).count == 9)
    #expect(StudySection.allCases.filter(\.isProse).count == 6)
}

@Test("Empty sections are skipped and the rest keep the display order")
func populatedSectionsSkipEmptyOnes() throws {
    let full = try JSONDecoder().decode(Study.self, from: Data(schemaSample.utf8))
    #expect(full.populatedSections == StudySection.displayOrder)
    #expect(full.prose(for: .meaning) == "The longest single description of God in the Quran.")
    #expect(full.prose(for: .keyTerms) == nil)

    let sparse = Study(key: "1:1", title: "In the name of God", meaning: "  ", applyIt: "Say it.")
    #expect(sparse.populatedSections == [.applyIt])
    #expect(!sparse.hasContent(.meaning))
    #expect(!sparse.hasContent(.crossReferences))
}
