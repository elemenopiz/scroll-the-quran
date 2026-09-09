@testable import FeatureDiscover
import Foundation
import StudyContent
import Testing

@Suite("Deep Study section order and anchors")
struct StudyAnchorTests {
    @Test("Sections render in the fixed order the content pipeline writes")
    func displayOrder() {
        #expect(StudySection.displayOrder == [
            .meaning, .historicalContext, .keyTerms, .lifeInProphetsTime, .didYouKnow,
            .theologicalSignificance, .crossReferences, .applyIt, .exploreFurther,
        ])
        #expect(StudySection.displayOrder.count == StudySection.allCases.count)
    }

    @Test("Every section has a unique anchor id")
    func anchorsAreUnique() {
        let ids = StudySection.displayOrder.map { StudyAnchor.id(for: $0) }
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { !$0.isEmpty && $0 == $0.lowercased() })
    }

    @Test("An anchor round-trips back to its section")
    func roundTrip() {
        for section in StudySection.displayOrder {
            #expect(StudyAnchor.section(for: StudyAnchor.id(for: section)) == section)
            #expect(StudyAnchor.section(for: section.rawValue) == section)
        }
    }

    @Test("The routes in Reference/manifest.json resolve")
    func manifestRoutes() {
        // deepstudy-mid, deepstudy-crossrefs and deepstudy-bottom launch these.
        #expect(StudyAnchor.section(for: "original-language") == .keyTerms)
        #expect(StudyAnchor.section(for: "cross-references") == .crossReferences)
        #expect(StudyAnchor.section(for: "apply-it") == .applyIt)
        #expect(StudyAnchor.section(for: "explore-in-scripture") == .exploreFurther)
        #expect(StudyAnchor.section(for: "life-in-biblical-times") == .lifeInProphetsTime)
    }

    @Test("No anchor, an empty anchor and `top` all mean the top of the page")
    func noAnchor() {
        #expect(StudyAnchor.section(for: nil) == nil)
        #expect(StudyAnchor.section(for: "") == nil)
        #expect(StudyAnchor.section(for: "top") == nil)
        #expect(StudyAnchor.section(for: "not-a-section") == nil)
    }

    @Test("Anchors are matched case-insensitively")
    func caseInsensitive() {
        #expect(StudyAnchor.section(for: "APPLY-IT") == .applyIt)
        #expect(StudyAnchor.section(for: "Original-Language") == .keyTerms)
    }

    @Test("Exactly four sections are drawn in a tinted box")
    func tintedSections() {
        let tinted = StudySection.displayOrder.filter { $0.tintedKind != nil }
        #expect(tinted == [.historicalContext, .lifeInProphetsTime, .didYouKnow, .applyIt])
    }
}
