import DesignSystem
import SwiftUI

/// The wax seal: a slightly irregular gold disc with the crescent-and-star mark pressed
/// into it. Drawn, not photographed, so nothing is copied from the reference art.
struct WaxSeal: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                WaxBlob()
                    .fill(
                        RadialGradient(
                            colors: [GiftPalette.sealLight, GiftPalette.sealMid, GiftPalette.sealDark],
                            center: UnitPoint(x: 0.36, y: 0.3),
                            startRadius: 0,
                            endRadius: side * 0.72
                        )
                    )
                Circle()
                    .inset(by: side * 0.16)
                    .fill(GiftPalette.sealMid.opacity(0.55))
                Circle()
                    .inset(by: side * 0.16)
                    .strokeBorder(GiftPalette.sealDark.opacity(0.45), lineWidth: side * 0.018)
                SealMotif()
                    .stroke(GiftPalette.sealDark.opacity(0.85), lineWidth: side * 0.026)
                    .padding(side * 0.26)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// A circle with a gently wavy rim, the way poured wax sets.
private struct WaxBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 96
        for step in 0 ... steps {
            let t = Double(step) / Double(steps) * 2 * .pi
            let wobble = 1 + 0.035 * sin(t * 9 + 0.6) + 0.018 * sin(t * 5 - 1.2)
            let point = CGPoint(x: center.x + cos(t) * base * wobble, y: center.y + sin(t) * base * wobble)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// The pressed mark: an open crescent ring with an eight-point star in its gap.
private struct SealMotif: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-48),
            endAngle: .degrees(262),
            clockwise: false
        )
        path.addPath(
            CrescentStarMark.eightPointStar(
                center: CGPoint(x: center.x + radius * 0.72, y: center.y - radius * 0.62),
                radius: radius * 0.3
            )
        )
        return path
    }
}

// MARK: - Sealed envelope

/// The unopened envelope on `gift-closed`: a slightly tilted paper rectangle with the
/// classic four folds and a wax seal where they meet.
struct SealedEnvelope: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: size.height * 0.04)
                    .fill(
                        LinearGradient(
                            colors: [GiftPalette.cloudWarm, GiftPalette.envelopeFront],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: GiftPalette.envelopeShade.opacity(0.45), radius: 14, x: 0, y: 10)

                // Lower folds: two triangles rising from the bottom corners.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.52))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                }
                .fill(GiftPalette.envelopeFront.opacity(0.85))

                // Top flap.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.62))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [GiftPalette.cloudWarm, GiftPalette.envelopeFlap],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.62))
                        path.addLine(to: CGPoint(x: size.width, y: 0))
                    }
                    .stroke(GiftPalette.envelopeShade.opacity(0.5), lineWidth: 1)
                }

                WaxSeal()
                    .frame(width: size.height * 0.46, height: size.height * 0.46)
                    .position(x: size.width / 2, y: size.height * 0.52)
            }
            .clipShape(RoundedRectangle(cornerRadius: size.height * 0.04))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Opened envelope

/// The opened envelope on `gift-open`, drawn at the coordinates measured off the
/// reference: back panel x 26...366 / y 338...579, flap apex (196, 118), the front
/// pocket meeting at (196, 505) and the seal centred on (196, 490).
///
/// It fills the whole reference canvas so every point is an absolute reference
/// coordinate rather than a fraction of some intermediate box.
struct OpenedEnvelope<Card: View>: View {
    @ViewBuilder var card: () -> Card

    private nonisolated static var geometry: PaywallMetrics.OpenEnvelope {
        PaywallMetrics.openEnvelopeGeometry
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AbsolutePath { path in
                path.move(to: Self.geometry.flapApex)
                path.addLine(to: CGPoint(x: Self.geometry.left, y: Self.geometry.bodyTop))
                path.addLine(to: CGPoint(x: Self.geometry.right, y: Self.geometry.bodyTop))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [GiftPalette.envelopeFlap, GiftPalette.envelopeLining],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            card()
                .frame(width: Self.geometry.card.width, height: Self.geometry.card.height)
                .offset(x: Self.geometry.card.minX, y: Self.geometry.card.minY)

            AbsolutePath { path in
                path.move(to: CGPoint(x: Self.geometry.left, y: Self.geometry.bodyTop))
                path.addLine(to: Self.geometry.pocketPoint)
                path.addLine(to: CGPoint(x: Self.geometry.right, y: Self.geometry.bodyTop))
                path.addLine(to: CGPoint(x: Self.geometry.right, y: Self.geometry.bottom))
                path.addLine(to: CGPoint(x: Self.geometry.left, y: Self.geometry.bottom))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [GiftPalette.envelopeFront, GiftPalette.envelopeFlap],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: GiftPalette.envelopeShade.opacity(0.35), radius: 10, y: 6)

            WaxSeal()
                .frame(width: PaywallMetrics.openSealDiameter, height: PaywallMetrics.openSealDiameter)
                .offset(
                    x: Self.geometry.sealCenter.x - PaywallMetrics.openSealDiameter / 2,
                    y: Self.geometry.sealCenter.y - PaywallMetrics.openSealDiameter / 2
                )
        }
        .frame(
            width: PaywallMetrics.referenceWidth,
            height: PaywallMetrics.referenceHeight,
            alignment: .topLeading
        )
    }
}

/// A `Shape` whose path is written in reference-canvas coordinates.
struct AbsolutePath: Shape {
    let build: @Sendable (inout Path) -> Void

    init(_ build: @escaping @Sendable (inout Path) -> Void) {
        self.build = build
    }

    func path(in _: CGRect) -> Path {
        var path = Path()
        build(&path)
        return path
    }
}
