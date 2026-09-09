import CoreGraphics
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
