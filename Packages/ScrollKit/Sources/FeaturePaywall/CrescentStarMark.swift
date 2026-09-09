import DesignSystem
import SwiftUI

/// The app mark on the paywall: an open crescent drawn as a stroked ring with a bite
/// taken out of it, and an eight-point star (the rub-el-hizb figure) sitting in the gap.
///
/// Drawn rather than shipped as art so `FeaturePaywall` needs no bundle resources.
/// A later artwork task replaces it with the finished mark.
struct CrescentStarMark: View {
    var lineWidth: CGFloat = 4.5

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let ring = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            ).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

            // The crescent: a full ring with the top-right arc left open for the star.
            var crescent = Path()
            crescent.addArc(
                center: CGPoint(x: ring.midX, y: ring.midY),
                radius: ring.width / 2,
                startAngle: .degrees(-58),
                endAngle: .degrees(272),
                clockwise: false
            )
            context.stroke(
                crescent,
                with: .color(.textPrimary),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            // Inner hairline, so the mark reads as a moon rather than a plain circle.
            var inner = Path()
            inner.addArc(
                center: CGPoint(x: ring.midX + side * 0.13, y: ring.midY - side * 0.04),
                radius: ring.width / 2 - lineWidth * 1.9,
                startAngle: .degrees(96),
                endAngle: .degrees(258),
                clockwise: false
            )
            context.stroke(
                inner,
                with: .color(.textPrimary),
                style: StrokeStyle(lineWidth: lineWidth * 0.62, lineCap: .round)
            )

            let star = Self.eightPointStar(
                center: CGPoint(x: ring.maxX - side * 0.07, y: ring.minY + side * 0.1),
                radius: side * 0.235
            )
            context.fill(star, with: .color(.textPrimary))
        }
        .accessibilityHidden(true)
    }

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

#Preview("Mark") {
    CrescentStarMark()
        .frame(width: 58, height: 54)
        .padding(40)
}
