import DesignSystem
import SwiftUI

/// The wax seal: a slightly irregular gold disc with **the app's own mark** struck into it.
/// Drawn, not photographed, so nothing is copied from the reference art.
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
                    .inset(by: side * PaywallMetrics.sealDiscInset)
                    .fill(GiftPalette.sealMid.opacity(0.55))
                Circle()
                    .inset(by: side * PaywallMetrics.sealDiscInset)
                    .strokeBorder(GiftPalette.sealDark.opacity(0.45), lineWidth: side * 0.018)
                SealImpression(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// The brand mark pressed into the wax: a light copy offset down-right under a dark copy
/// at the origin, which is what a recess lit from the top left looks like. Both are the
/// one `BrandMark` artwork, so the seal carries the same ring as the icon and the reader.
private struct SealImpression: View {
    let side: CGFloat

    var body: some View {
        let offset = side * PaywallMetrics.sealEmbossOffset
        ZStack {
            BrandMark(ink: .tinted(GiftPalette.sealLight.opacity(0.85)))
                .offset(x: offset, y: offset)
            BrandMark(ink: .tinted(GiftPalette.sealDark.opacity(0.8)))
                .blendMode(.multiply)
        }
        .padding(side * PaywallMetrics.sealMarkInset)
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

// MARK: - Sealed envelope

/// The unopened envelope on `gift-closed`: a slightly tilted paper rectangle with the
/// classic four folds and a wax seal where they meet.
struct SealedEnvelope: View {
    /// Where all four creases meet, as a fraction of the envelope's height — and therefore
    /// where the seal is centred. 0.52 puts it on (196, 371) in reference points, the centre
    /// measured off `gift-closed.png`.
    private static let foldPoint: CGFloat = 0.52

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: size.height * 0.04)
                    .fill(
                        LinearGradient(
                            colors: [GiftPalette.envelopePaper, GiftPalette.envelopeFront],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Lower folds and top flap meet at the same point, so the four creases make
                // one X and the wax seal sits centred on where they join — as in the
                // reference, where the seal covers the junction entirely.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height * Self.foldPoint))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                }
                .fill(GiftPalette.envelopeFront)

                // Top flap.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height * Self.foldPoint))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [GiftPalette.envelopePaper, GiftPalette.envelopeFront],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: size.width / 2, y: size.height * Self.foldPoint))
                        path.addLine(to: CGPoint(x: size.width, y: 0))
                    }
                    .stroke(GiftPalette.envelopeShade.opacity(0.5), lineWidth: 1)
                }

            }
            // Clip the paper, then cast the shadow: the previous order clipped the shadow
            // away with everything else outside the envelope's own rectangle.
            .clipShape(RoundedRectangle(cornerRadius: size.height * 0.04))
            .shadow(color: GiftPalette.envelopeShade.opacity(0.45), radius: 14, x: 0, y: 10)
            .overlay {
                WaxSeal()
                    .frame(width: size.height * 0.46, height: size.height * 0.46)
                    .position(x: size.width / 2, y: size.height * Self.foldPoint)
            }
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
