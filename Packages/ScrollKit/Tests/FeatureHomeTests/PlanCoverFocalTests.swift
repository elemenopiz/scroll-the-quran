import CoreGraphics
@testable import FeatureHome
import Foundation
import Testing

/// The focal table and the crop maths that puts a 3:2 cover's subject inside a square tile
/// or a 1.95:1 hero without slicing it. Phase 4l.
@Suite("Plan cover focal points")
struct PlanCoverFocalTests {
    // MARK: The table

    @Test("every shipped slug has a focal entry")
    func everySlugHasAFocal() {
        for slug in PlanCoverArtwork.slugs {
            #expect(PlanCoverArtwork.focal[slug] != nil, "no focal point for \(slug)")
        }
    }

    @Test("the table names no slug the catalog does not ship")
    func noStraySlugs() {
        for slug in PlanCoverArtwork.focal.keys {
            #expect(PlanCoverArtwork.slugs.contains(slug), "focal table names unknown slug \(slug)")
        }
    }

    @Test("every anchor is a unit point")
    func anchorsAreInRange() {
        for (slug, focal) in PlanCoverArtwork.focal {
            #expect(focal.x >= 0 && focal.x <= 1, "\(slug) x out of 0...1: \(focal.x)")
            #expect(focal.y >= 0 && focal.y <= 1, "\(slug) y out of 0...1: \(focal.y)")
        }
    }

    @Test("an unknown slug falls back to the centre")
    func unknownSlugIsCentred() {
        #expect(PlanCoverArtwork.focal(slug: "no-such-cover") == .center)
        #expect(PlanCoverArtwork.focal(for: nil) == .center)
    }

    @Test("a slug resolves with or without the catalog prefix")
    func prefixIsTolerated() {
        #expect(PlanCoverArtwork.focal(slug: "lantern") == PlanCoverArtwork.focal(slug: "PlanCover-lantern"))
        #expect(PlanCoverArtwork.focal(slug: "lantern") == PlanCoverArtwork.Focal(0.05, 0.5))
    }

    @Test("a plan takes the anchor of the cover it actually draws")
    func planResolvesThroughItsAsset() {
        // `image` wins when it names a shipped slug …
        #expect(PlanCoverArtwork.focal(for: plan(id: "anything", image: "night-window")) == PlanCoverArtwork.Focal(0.02, 1.0))
        // … and the id table is the fallback for a plan written before `image` existed.
        #expect(PlanCoverArtwork.focal(for: plan(id: "juz-amma", image: nil)) == PlanCoverArtwork.Focal(0.05, 0.5))
        // A plan that maps to no cover at all draws the wash, so its anchor is moot: centre.
        #expect(PlanCoverArtwork.focal(for: plan(id: "unmapped", image: nil)) == .center)
    }

    // MARK: Fill maths

    @Test("a 3:2 frame filled into a square overflows sideways only")
    func filledIntoSquare() {
        let filled = PlanCoverArtwork.filledSize(container: CGSize(width: 100, height: 100))
        #expect(filled == CGSize(width: 150, height: 100))
    }

    @Test("a 3:2 frame filled into a 1.95:1 hero overflows vertically only")
    func filledIntoHero() {
        let filled = PlanCoverArtwork.filledSize(container: CGSize(width: 195, height: 100))
        #expect(filled == CGSize(width: 195, height: 130))
    }

    @Test("an empty container has no fill")
    func filledIntoNothing() {
        #expect(PlanCoverArtwork.filledSize(container: .zero) == .zero)
    }

    // MARK: Offsets — square (3:2 into 1:1)

    @Test(
        "the square crop slides across the frame's middle third",
        arguments: [
            // anchor, origin.x, shift from the centred position, visible slice start
            (CGFloat(0.0), CGFloat(0), CGFloat(25), CGFloat(0)),
            (CGFloat(0.5), CGFloat(-25), CGFloat(0), CGFloat(1.0 / 6)),
            (CGFloat(1.0), CGFloat(-50), CGFloat(-25), CGFloat(1.0 / 3)),
        ]
    )
    func squareOffsets(anchor: CGFloat, expectedOrigin: CGFloat, expectedShift: CGFloat, expectedSliceX: CGFloat) {
        let container = CGSize(width: 100, height: 100)
        let scaled = PlanCoverArtwork.filledSize(container: container)
        let focal = PlanCoverArtwork.Focal(anchor, 0.5)

        let origin = PlanCoverArtwork.origin(container: container, scaled: scaled, focal: focal)
        #expect(abs(origin.x - expectedOrigin) < 0.0001)
        #expect(origin.y == 0, "a square crop of a 3:2 frame never moves vertically")

        let shift = PlanCoverArtwork.centerOffset(container: container, scaled: scaled, focal: focal)
        #expect(abs(shift.width - expectedShift) < 0.0001)
        #expect(shift.height == 0)

        let slice = PlanCoverArtwork.visibleRect(container: container, scaled: scaled, focal: focal)
        #expect(abs(slice.minX - expectedSliceX) < 0.0001)
        #expect(abs(slice.width - 2.0 / 3) < 0.0001, "two thirds of the width is visible")
        #expect(slice.height == 1, "the whole height is visible")
    }

    // MARK: Offsets — hero (3:2 into 1.95:1)

    @Test(
        "the hero crop slides down the frame's middle 23 %",
        arguments: [
            (CGFloat(0.0), CGFloat(0), CGFloat(15), CGFloat(0)),
            (CGFloat(0.5), CGFloat(-15), CGFloat(0), CGFloat(1.5 / 13)),
            (CGFloat(1.0), CGFloat(-30), CGFloat(-15), CGFloat(3.0 / 13)),
        ]
    )
    func heroOffsets(anchor: CGFloat, expectedOrigin: CGFloat, expectedShift: CGFloat, expectedSliceY: CGFloat) {
        let container = CGSize(width: 195, height: 100)
        let scaled = PlanCoverArtwork.filledSize(container: container)
        let focal = PlanCoverArtwork.Focal(0.5, anchor)

        let origin = PlanCoverArtwork.origin(container: container, scaled: scaled, focal: focal)
        #expect(abs(origin.y - expectedOrigin) < 0.0001)
        #expect(origin.x == 0, "a 1.95:1 crop of a 3:2 frame never moves horizontally")

        let shift = PlanCoverArtwork.centerOffset(container: container, scaled: scaled, focal: focal)
        #expect(abs(shift.height - expectedShift) < 0.0001)
        #expect(shift.width == 0)

        let slice = PlanCoverArtwork.visibleRect(container: container, scaled: scaled, focal: focal)
        #expect(abs(slice.minY - expectedSliceY) < 0.0001)
        #expect(abs(slice.height - 10.0 / 13) < 0.0001, "1.5/1.95 of the height is visible")
        #expect(slice.width == 1, "the whole width is visible")
    }

    // MARK: The promise the table is making

    @Test("no crop ever loses more than the frame's spare third")
    func cropsStayInsideTheFrame() {
        let square = CGSize(width: 173.5, height: 173.5)
        let hero = CGSize(width: 361, height: 361 / 1.95)
        for slug in PlanCoverArtwork.slugs {
            let focal = PlanCoverArtwork.focal(slug: slug)
            for container in [square, hero] {
                let scaled = PlanCoverArtwork.filledSize(container: container)
                let slice = PlanCoverArtwork.visibleRect(container: container, scaled: scaled, focal: focal)
                #expect(slice.minX >= -0.0001 && slice.maxX <= 1.0001, "\(slug) crop leaves the frame horizontally")
                #expect(slice.minY >= -0.0001 && slice.maxY <= 1.0001, "\(slug) crop leaves the frame vertically")
            }
        }
    }

    /// The 18 covers were authored off-centre on purpose, so a table of all-centre anchors
    /// would mean the table had silently been reset.
    @Test("most covers are anchored off centre")
    func theTableActuallyMoves() {
        let offCentre = PlanCoverArtwork.focal.values.filter { $0 != .center }
        #expect(offCentre.count >= 15)
    }

    // MARK: Helpers

    private func plan(id: String, image: String?) -> ReadingPlan {
        ReadingPlan(
            id: id,
            title: "Plan",
            subtitle: "Sub",
            image: image,
            section: "s",
            bestFor: "b",
            lengthDays: 1,
            dailyMinutes: 1,
            about: "a",
            schedule: []
        )
    }
}
