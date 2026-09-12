import CoreGraphics
import DesignSystem
@testable import FeatureReader
import Testing

@Suite("Verse rail geometry")
struct VerseRailGeometryTests {
    /// The reference capture: Romans 5 (21 verses) on a rail 1880 px = 626.7 pt tall.
    static let reference = VerseRailGeometry(ayahCount: 21, height: 626.667)

    @Test("the reference rail reproduces its measured 30 pt pitch and 28 pt dash")
    func matchesTheReference() {
        #expect(abs(Self.reference.pitch - 29.84) < 0.05)
        #expect(abs(Self.reference.dashLength - 27.84) < 0.05)
        // First dash starts at the top, last one ends at the bottom.
        #expect(Self.reference.origin(ofAyah: 1) == 0)
        #expect(abs(Self.reference.origin(ofAyah: 21) + Self.reference.dashLength - 624.8) < 0.5)
    }

    @Test("a drag to 80 % of the rail lands on round(0.8 x N)", arguments: [7, 21, 112, 176, 286])
    func dragToEightyPercent(_ ayahCount: Int) {
        let rail = VerseRailGeometry(ayahCount: ayahCount, height: 600)
        let expected = Int((0.8 * Double(ayahCount)).rounded())
        #expect(rail.ayah(atFraction: 0.8) == expected)
        #expect(rail.ayah(atY: 480) == expected)
    }

    @Test("the centre of every dash maps back to its own ayah")
    func roundTripsThroughEveryDash() {
        let rail = VerseRailGeometry(ayahCount: 21, height: 626.667)
        for ayah in 1 ... 21 {
            #expect(rail.ayah(atY: rail.centre(ofAyah: ayah)) == ayah)
            #expect(rail.ayah(atFraction: rail.fraction(ofAyah: ayah)) == ayah)
        }
    }

    @Test("both ends clamp instead of running off the rail")
    func endsClamp() {
        let rail = VerseRailGeometry(ayahCount: 21, height: 600)
        #expect(rail.ayah(atFraction: -3) == 1)
        #expect(rail.ayah(atFraction: 0) == 1)
        #expect(rail.ayah(atFraction: 1) == 21)
        #expect(rail.ayah(atFraction: 9) == 21)
        #expect(rail.ayah(atY: -100) == 1)
        #expect(rail.ayah(atY: 10000) == 21)
        #expect(rail.origin(ofAyah: -5) == 0)
        #expect(rail.origin(ofAyah: 999) == rail.origin(ofAyah: 21))
    }

    @Test("a long surah still draws a visible dash")
    func longSurahKeepsAHairline() {
        let rail = VerseRailGeometry(ayahCount: 286, height: 626.667)
        #expect(rail.dashLength >= 1)
        #expect(abs(rail.pitch - 2.19) < 0.01)
        #expect(rail.ayah(atFraction: 1) == 286)
    }

    @Test("a one-ayah surah is one full-height dash")
    func singleAyah() {
        let rail = VerseRailGeometry(ayahCount: 1, height: 600)
        #expect(rail.pitch == 600)
        #expect(rail.ayah(atFraction: 0.5) == 1)
        #expect(rail.fraction(ofAyah: 1) == 0.5)
    }

    @Test("the fraction of an ayah is the centre of its dash")
    func fractionIsTheDashCentre() {
        let rail = VerseRailGeometry(ayahCount: 4, height: 400)
        #expect(rail.fraction(ofAyah: 1) == 0.125)
        #expect(rail.fraction(ofAyah: 4) == 0.875)
    }

    @Test("the bottom number is hidden once the indicator reaches it")
    func bottomNumberHidesUnderTheIndicator() {
        let rail = VerseRailGeometry(ayahCount: 21, height: 600)
        #expect(rail.showsBottomNumber(forAyah: 1))
        #expect(!rail.showsBottomNumber(forAyah: 21))
    }
}

/// Phase 4j. The rail is the control that drops the reader anywhere in a 286-ayah surah, so
/// the mapping it does — a y down the rail to an ayah, and back to a label position — has to be
/// monotonic, clamped, and never put a number where the chrome is.
@Suite("Verse rail geometry (Phase 4j)")
struct VerseRailScrubGeometryTests {
    /// The rail as `ReaderView` lays it out on the reference device: the safe area (710 pt)
    /// less the rail's own top and bottom insets.
    static let railHeight = ReaderMetrics.referenceSize.height
        - ReaderMetrics.referenceTopInset
        - ReaderMetrics.referenceBottomInset
        - ReaderMetrics.railTopInset
        - ReaderMetrics.railBottomInset

    @Test("a scrub down the rail never goes backwards", arguments: [1, 7, 21, 112, 286])
    func scrubIsMonotonic(_ ayahCount: Int) {
        let rail = VerseRailGeometry(ayahCount: ayahCount, height: Self.railHeight)
        var previous = rail.ayah(atY: -50)
        #expect(previous == 1)
        // Half-point steps: finer than the 2.19 pt pitch of the longest surah.
        for step in stride(from: -50.0, through: Double(Self.railHeight) + 50, by: 0.5) {
            let ayah = rail.ayah(atY: CGFloat(step))
            #expect(ayah >= previous, "y \(step) went back from \(previous) to \(ayah)")
            #expect((1 ... ayahCount).contains(ayah), "y \(step) left the surah: \(ayah)")
            previous = ayah
        }
        #expect(previous == ayahCount)
    }

    @Test("every ayah is reachable by a scrub", arguments: [1, 7, 21, 112, 286])
    func everyAyahIsReachable(_ ayahCount: Int) {
        let rail = VerseRailGeometry(ayahCount: ayahCount, height: Self.railHeight)
        let reached = Set(stride(from: 0.0, through: Double(Self.railHeight), by: 0.25)
            .map { rail.ayah(atY: CGFloat($0)) })
        #expect(reached == Set(1 ... ayahCount))
    }

    /// The ayah number beside the indicator is not clamped into the rail — clamping it would
    /// move pixels the `reader-dark` capture is scored against — so the clearance it has
    /// without clamping is what has to hold, at both ends and for every surah length.
    @Test("the number beside the indicator clears the toolbar and the tab bar")
    func numberClearsTheChrome() {
        let labelHeight = ReaderMetrics.railNumberSize + Spacing.xs
        // Screen-space y of the rail's top edge, and of the chrome it must not touch.
        let railTop = ReaderMetrics.referenceTopInset + ReaderMetrics.railTopInset
        let toolbarBottom = ReaderMetrics.referenceTopInset
            + ReaderMetrics.toolbarTopInset
            + ReaderMetrics.toolbarHeight
        let safeBottom = ReaderMetrics.referenceSize.height - ReaderMetrics.referenceBottomInset

        for ayahCount in 1 ... 286 {
            let rail = VerseRailGeometry(ayahCount: ayahCount, height: Self.railHeight)
            let top = railTop + rail.centre(ofAyah: 1) - labelHeight / 2
            let bottom = railTop + rail.centre(ofAyah: ayahCount) + labelHeight / 2
            #expect(top > toolbarBottom, "surah of \(ayahCount): the '1' overlaps the toolbar")
            #expect(bottom < safeBottom, "surah of \(ayahCount): the last number is over the tab bar")
        }
    }

    /// 286 ayat is the worst case for both ends; state the numbers so a change to the insets
    /// shows up here rather than in a screenshot.
    @Test("the longest surah keeps 9 pt of clearance at the top")
    func longestSurahClearance() {
        let rail = VerseRailGeometry(ayahCount: 286, height: Self.railHeight)
        let labelHeight = ReaderMetrics.railNumberSize + Spacing.xs
        let railTop = ReaderMetrics.referenceTopInset + ReaderMetrics.railTopInset
        let top = railTop + rail.centre(ofAyah: 1) - labelHeight / 2
        #expect(abs(top - 111.1) < 0.2)
        #expect(abs(Self.railHeight - 627) < 0.5)
    }
}

/// Phase 4j. `.paging` snaps *relative* to where the content is, so a pager that is left 283 pt
/// into a page stays 283 pt into every page after it. `ReaderPagingBehavior` snaps to the
/// absolute grid instead, which is what a jump needs and what heals a mis-parked pager.
@Suite("Reader paging behaviour")
struct ReaderPagingBehaviorTests {
    static let pageHeight: CGFloat = 729

    @Test("a target inside a page is pulled onto the nearest boundary")
    func snapsToTheNearestBoundary() {
        let height = Self.pageHeight
        // The measured failure: a jump to 2:86 stopped 283 pt short of the page's start.
        #expect(ReaderPagingBehavior.snapped(86 * height - 283, pageHeight: height) == 86 * height)
        // Just past the halfway point goes to the next page, not back.
        #expect(ReaderPagingBehavior.snapped(3 * height + height * 0.51, pageHeight: height) == 4 * height)
        #expect(ReaderPagingBehavior.snapped(3 * height + height * 0.49, pageHeight: height) == 3 * height)
    }

    @Test("a target already on a boundary does not move", arguments: [0, 1, 2, 86, 252, 286])
    func boundariesAreFixedPoints(_ page: Int) {
        let y = CGFloat(page) * Self.pageHeight
        #expect(ReaderPagingBehavior.snapped(y, pageHeight: Self.pageHeight) == y)
    }

    @Test("every snapped target is a whole number of pages")
    func alwaysLandsOnTheGrid() {
        for step in stride(from: -2000.0, through: 20000.0, by: 37.0) {
            let snapped = ReaderPagingBehavior.snapped(CGFloat(step), pageHeight: Self.pageHeight)
            let pages = snapped / Self.pageHeight
            #expect(pages == pages.rounded(), "\(step) snapped to \(snapped), which is not a page boundary")
            #expect(abs(snapped - CGFloat(step)) <= Self.pageHeight / 2 + 0.001)
        }
    }

    @Test("a container with no height is left alone rather than divided by")
    func zeroContainerIsSafe() {
        #expect(ReaderPagingBehavior.snapped(123, pageHeight: 0) == 123)
        #expect(ReaderPagingBehavior.snapped(123, pageHeight: -10) == 123)
    }
}
