@testable import FeatureHome
import Foundation
import Testing

@Suite("Reading plan catalog")
struct ReadingPlanCatalogTests {
    @Test("Content/plans.json decodes with every section populated")
    func bundledCatalogDecodes() throws {
        let catalog = try HomeTestContent.catalog()
        #expect(!catalog.plans.isEmpty)
        #expect(catalog.sections.count == catalog.populatedSections.count)
        for section in catalog.sections {
            #expect(!catalog.plans(in: section).isEmpty, "section '\(section.title)' resolves no plans")
        }
    }

    @Test("the sheet opens on a beginners rail that fills two rows of the grid")
    func firstSectionIsTheBeginnersRail() throws {
        let catalog = try HomeTestContent.catalog()
        let first = try #require(catalog.populatedSections.first)
        #expect(first.title == "Recommended for beginners")
        #expect(first.eyebrow == "For new readers")
        // The reference's first rail is two rows of two; a third row would push the next
        // section's heading off the `plans-sheet` capture entirely.
        #expect(catalog.plans(in: first).count == 4)
    }

    @Test("no plan is listed in two sections, so no card is drawn twice")
    func sectionsDoNotOverlap() throws {
        let catalog = try HomeTestContent.catalog()
        var seen: Set<String> = []
        for section in catalog.populatedSections {
            for plan in catalog.plans(in: section) {
                #expect(seen.insert(plan.id).inserted, "'\(plan.id)' appears in more than one section")
                // The section a plan names is the section it is listed under.
                #expect(plan.section == section.title, "'\(plan.id)' names '\(plan.section)'")
            }
        }
        #expect(seen.count == catalog.plans.count, "every plan is reachable from a section")
    }

    @Test("every plan carries a cover slug that maps to a catalog image name")
    func everyPlanHasACover() throws {
        for plan in try HomeTestContent.catalog().plans {
            let name = try #require(
                PlanCoverArtwork.assetName(for: plan),
                "plan '\(plan.id)' has no cover"
            )
            #expect(name.hasPrefix(PlanCoverArtwork.prefix))
            #expect(PlanCoverArtwork.slugs.contains(String(name.dropFirst(PlanCoverArtwork.prefix.count))))
        }
    }

    @Test("a plan's schedule covers day 1 through lengthDays with parseable refs")
    func schedulesAreComplete() throws {
        for plan in try HomeTestContent.catalog().plans {
            #expect(plan.schedule.count == plan.lengthDays, "\(plan.id) schedule length")
            for number in 1 ... plan.lengthDays {
                let day = try #require(plan.day(number), "\(plan.id) is missing day \(number)")
                #expect(!day.refs.isEmpty)
                #expect(day.passages.count == day.refs.count, "\(plan.id) day \(number) has an unparseable ref")
            }
        }
    }

    @Test("the meta line reads '30 days · about 45 min/day'")
    func metaLine() throws {
        let plan = try #require(HomeTestContent.fixtureCatalog().plan("three-day"))
        #expect(plan.metaLine == "3 days · about 4 min/day")
        #expect(plan.dailyCommitment == "about 4 min a day")
    }

    @Test("unknown plan ids in a section are dropped, and an empty section is not drawn")
    func unknownIDsAreDropped() {
        let catalog = HomeTestContent.fixtureCatalog()
        #expect(catalog.plans(in: catalog.sections[0]).map(\.id) == ["three-day"])
        #expect(catalog.populatedSections.map(\.title) == ["Only"])
    }

    @Test("refs render with surah names when the index is available")
    func refsLineUsesSurahNames() throws {
        let index = try HomeTestContent.surahIndex()
        let day = ReadingPlanDay(day: 1, title: "One", refs: ["1:1-7", "2:255"])
        #expect(day.refsLine == "1:1-7 · 2:255")
        #expect(day.refsLine(using: index) == "\(index.surah(1)!.name) 1-7 · \(index.surah(2)!.name) 255")
    }

    @Test("a plan whose cover slug is unknown falls back to its id, then to nothing")
    func coverFallback() {
        #expect(PlanCoverArtwork.assetName(image: "not-a-slug", planID: "mercy") == "PlanCover-dawn-light")
        #expect(PlanCoverArtwork.assetName(image: nil, planID: "unheard-of") == nil)
        #expect(PlanCoverArtwork.assetName(image: "PlanCover-lantern", planID: "x") == "PlanCover-lantern")
    }
}
