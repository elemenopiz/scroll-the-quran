import CoreGraphics
import Foundation

/// The maths behind the reader's left rail: one dash per ayah, a solid indicator on the
/// current one, and a tap or drag anywhere along it jumping to the ayah under the finger.
///
/// Measured from `Reference/reader-dark.png`: Romans 5 has 21 verses and the rail has 21
/// segments, 84 px dashes on a 90 px pitch (28 pt on 30 pt), spanning y 351..2231 px. So the
/// pitch is simply `height / ayahCount` and the dash is the pitch less a 2 pt gap.
public struct VerseRailGeometry: Equatable, Sendable {
    public let ayahCount: Int
    public let height: CGFloat
    public let gap: CGFloat

    public init(ayahCount: Int, height: CGFloat, gap: CGFloat = ReaderMetrics.railGap) {
        self.ayahCount = max(1, ayahCount)
        self.height = max(0, height)
        self.gap = gap
    }

    /// Centre-to-centre distance between segments.
    public var pitch: CGFloat {
        height / CGFloat(ayahCount)
    }

    /// The drawn length of one dash. Never smaller than a hairline, so a 286-ayah surah still
    /// shows a rail rather than an empty column.
    public var dashLength: CGFloat {
        max(1, pitch - gap)
    }

    /// Offset of the top of an ayah's segment, from the top of the rail.
    public func origin(ofAyah ayah: Int) -> CGFloat {
        CGFloat(clamp(ayah) - 1) * pitch
    }

    /// Offset of the centre of an ayah's *slot*. The drawn dash is `gap` shorter than the
    /// slot, so this is deliberately not the middle of the ink: it is the point that
    /// ``ayah(atY:)`` maps back to this ayah.
    public func centre(ofAyah ayah: Int) -> CGFloat {
        origin(ofAyah: ayah) + pitch / 2
    }

    /// Where an ayah sits along the rail, 0...1 — the value the indicator animates to.
    public func fraction(ofAyah ayah: Int) -> Double {
        guard ayahCount > 0 else { return 0 }
        return (Double(clamp(ayah)) - 0.5) / Double(ayahCount)
    }

    /// The ayah at a fraction of the rail. Rounding is to nearest, away from zero, so the
    /// centre of dash *k* maps back to *k* and a drag to 80 % of a surah lands on
    /// `round(0.8 × ayahCount)`.
    public func ayah(atFraction fraction: Double) -> Int {
        // The nudge is half a hair wide: it only decides cases that land on .5 to within a
        // billionth, which in practice means the exact dash centres that `centre(ofAyah:)`
        // produces and that binary arithmetic lands just underneath.
        let scaled = (fraction * Double(ayahCount) + 1e-9).rounded(.toNearestOrAwayFromZero)
        return clamp(Int(scaled))
    }

    /// The ayah under a point on the rail, measured from the rail's top edge.
    public func ayah(atY y: CGFloat) -> Int {
        guard height > 0 else { return 1 }
        return ayah(atFraction: Double(y / height))
    }

    /// The label shown next to the indicator, and the one pinned at the bottom of the rail.
    public func showsBottomNumber(forAyah ayah: Int) -> Bool {
        clamp(ayah) != ayahCount
    }

    private func clamp(_ ayah: Int) -> Int {
        min(max(ayah, 1), ayahCount)
    }
}
