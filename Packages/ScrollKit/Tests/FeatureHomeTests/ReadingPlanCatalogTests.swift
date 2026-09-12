import CoreText
import DesignSystem
@testable import FeatureHome
import Foundation
import QuranData
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

    // MARK: The catalogue's shape

    @Test("Six shelves, eighteen plans, and the four that wear the START HERE ribbon")
    func shelvesAndStartHere() throws {
        let catalog = try HomeTestContent.catalog()
        #expect(catalog.sections.count == 6)
        #expect(catalog.plans.count == 18)
        #expect(catalog.sections.map(\.title) == [
            "Recommended for beginners",
            "Read it through",
            "The Sunnah of reading",
            "Stories of the prophets",
            "By theme",
            "Memorise",
        ])
        let startHere = catalog.plans.filter(\.startHere).map(\.id)
        #expect(startHere.count == 4)
        // The ribbon and the beginner shelf are the same four plans, in the same order.
        #expect(Set(startHere) == Set(catalog.sections[0].planIDs))
    }

    @Test("Plan ids are unique, and every id Phase 1 shipped still exists")
    func idsAreStable() throws {
        let catalog = try HomeTestContent.catalog()
        let ids = catalog.plans.map(\.id)
        #expect(Set(ids).count == ids.count, "two plans share an id")
        // `PlanProgress` is keyed by plan id: dropping one strands a reader mid-plan.
        let phase1 = [
            "juz-a-day", "juz-amma", "al-kahf-fridays", "protection-verses",
            "patience", "gratitude", "mercy",
        ]
        #expect(Set(ids).isSuperset(of: phase1))
    }

    @Test("Every ref is a whole-ayah passage that exists in the Quran")
    func everyRefIsInsideTheQuran() throws {
        let index = try HomeTestContent.surahIndex()
        for plan in try HomeTestContent.catalog().plans {
            for day in plan.schedule {
                for ref in day.refs {
                    let passage = try #require(PassageRef(key: ref), "\(plan.id) day \(day.day): '\(ref)'")
                    #expect(passage.start <= passage.end, "\(plan.id): '\(ref)' runs backwards")
                    #expect(index.contains(passage), "\(plan.id): '\(ref)' is outside the Quran")
                    // Whole ayat only: the key the generator wrote is the key the passage
                    // round-trips to, so nothing was split mid-ayah or padded.
                    let expected = passage.start == passage.end
                        ? "\(passage.surah):\(passage.start)"
                        : "\(passage.surah):\(passage.start)-\(passage.end)"
                    #expect(ref == expected, "\(plan.id): '\(ref)' is not a plain whole-ayah ref")
                }
            }
        }
    }

    @Test("dailyMinutes is a computed figure inside the range a card can print")
    func dailyMinutesArePlausible() throws {
        for plan in try HomeTestContent.catalog().plans {
            #expect(plan.dailyMinutes >= 3, "\(plan.id) claims \(plan.dailyMinutes) min/day")
            #expect(plan.dailyMinutes <= 90, "\(plan.id) claims \(plan.dailyMinutes) min/day")
            #expect(plan.metaLine.contains("min/day"), "\(plan.id) prints no daily figure")
        }
    }

    // MARK: The copy

    @Test("Plan prose is English, descriptive, and carries no transliterated Arabic")
    func planProseFollowsTheHouseRules() throws {
        // The generator enforces these when it writes the file; this is the regression
        // guard on the shipped copy, in the same spirit as `ThemeIndexTests`.
        let arabic = try #require(try? NSRegularExpression(pattern: "[\\u0600-\\u06FF\\u0750-\\u077F\\uFB50-\\uFEFF]"))
        for plan in try HomeTestContent.catalog().plans {
            let prose = [plan.title, plan.subtitle, plan.bestFor, plan.about]
            for text in prose {
                let range = NSRange(text.startIndex ..< text.endIndex, in: text)
                #expect(
                    arabic.firstMatch(in: text, range: range) == nil,
                    "\(plan.id): Arabic script belongs to the muted line the app draws"
                )
                #expect(!text.contains("Allah"), "\(plan.id): English prose says God")
            }
            let aboutWords = plan.about.split(whereSeparator: \.isWhitespace).count
            #expect(aboutWords >= 60 && aboutWords <= 120, "\(plan.id): about is \(aboutWords) words")
            let subtitleWords = plan.subtitle.split(whereSeparator: \.isWhitespace).count
            #expect(subtitleWords <= 6, "\(plan.id): subtitle is \(subtitleWords) words")
            #expect(!plan.bestFor.isEmpty, "\(plan.id): no bestFor line")
        }
    }

    @Test("Every Sunnah-of-reading plan says which collection its practice is reported in")
    func sunnahPlansNameTheirSource() throws {
        let catalog = try HomeTestContent.catalog()
        let shelf = try #require(catalog.sections.first { $0.title == "The Sunnah of reading" })
        let plans = catalog.plans(in: shelf)
        #expect(!plans.isEmpty)
        for plan in plans {
            #expect(
                plan.about.contains("collection"),
                "'\(plan.id)' describes a reported practice without naming where it is reported"
            )
        }
    }

    // MARK: The card

    /// The plans grid is two flexible columns inside the sheet's page margin, and a card's
    /// labels sit inside `Spacing.md` of padding. 393 pt is the reference screen, which is
    /// narrower than the simulator's 402, so it is the width that has to hold.
    private static let cardLabelWidth: CGFloat =
        (393 - 2 * Spacing.pageMargin - HomeMetrics.planGridSpacing) / 2 - 2 * Spacing.md

    /// `ReadingPlansSheet` gives every card `.lineLimit(1).minimumScaleFactor(0.78)`, so a
    /// label may set up to 1/0.78 of the card's width before it starts being truncated.
    private static let labelBudget = cardLabelWidth / 0.78

    /// Typographic width of one line, measured through CoreText. `Font.body(_:weight:)`
    /// resolves to the system face, which is the same SF Pro on the host as on the device;
    /// this is a fit check, not a pixel measurement.
    private func lineWidth(_ text: String, size: CGFloat, weight: CTFontSymbolicTraits?) -> CGFloat {
        var font = CTFontCreateUIFontForLanguage(.system, size, nil)!
        if let weight, let heavier = CTFontCreateCopyWithSymbolicTraits(font, size, nil, weight, weight) {
            font = heavier
        }
        let attributed = NSAttributedString(
            string: text,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
    }

    @Test("No plan card's title, meta line or tagline outruns the card at the default size")
    func cardCopyFitsTheCard() throws {
        let budget = Self.labelBudget
        for plan in try HomeTestContent.catalog().plans {
            let title = lineWidth(plan.title, size: 17, weight: .traitBold)
            let meta = lineWidth(plan.metaLine, size: 14, weight: nil)
            let tagline = lineWidth(plan.subtitle, size: 14, weight: .traitBold)
            #expect(title <= budget, "\(plan.id) title sets \(Int(title)) pt against \(Int(budget))")
            #expect(meta <= budget, "\(plan.id) meta sets \(Int(meta)) pt against \(Int(budget))")
            #expect(tagline <= budget, "\(plan.id) tagline sets \(Int(tagline)) pt against \(Int(budget))")
        }
    }
}
