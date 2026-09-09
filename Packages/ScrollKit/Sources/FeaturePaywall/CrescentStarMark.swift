import SwiftUI

/// The rub-el-hizb figure, pressed into the gift envelope's wax seal.
///
/// The app's own mark is `BrandMark` (real artwork out of the asset catalog); this is only
/// the geometry `SealMotif` in `EnvelopeArt` strikes into the wax, kept as a path so it can
/// be filled and embossed rather than drawn as a bitmap.
enum CrescentStarMark {
    /// Two squares at 45 degrees to one another — the rub-el-hizb figure.
    static func eightPointStar(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for rotation in [0.0, 45.0] {
            var square = Path()
            for corner in 0 ..< 4 {
                let angle = Angle.degrees(rotation + Double(corner) * 90 + 45).radians
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if corner == 0 {
                    square.move(to: point)
                } else {
                    square.addLine(to: point)
                }
            }
            square.closeSubpath()
            path.addPath(square)
        }
        return path
    }
}
