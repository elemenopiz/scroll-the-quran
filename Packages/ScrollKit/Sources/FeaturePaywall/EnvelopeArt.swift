import DesignSystem
import SwiftUI

/// The generated gift artwork, resolved from the **app's** asset catalog.
///
/// `Artwork/tools/gift-assets.sh` cuts these layers out of the renders in
/// `Artwork/src/gift/`; `Artwork/README.md` says what each one contains. They live in
/// `App/Assets.xcassets`, so they resolve through `Bundle.main` and a package preview (or
/// a host-only unit test) sees nothing — every surface below falls back to the vector art
/// Phase 3 drew rather than leaving a hole.
enum GiftArt {
    /// Closed envelope, wax seal with the brand ring already pressed into it, 1200x900.
    static let closedEnvelope = "EnvelopeClosed"
    /// Opened envelope: raised flap, lining and front pocket in one 1000x1500 layer.
    static let openEnvelope = "EnvelopeOpen"
    /// The blank offer card, 900x1200.
    static let card = "EnvelopeCard"
    /// The same wax seal as the closed envelope's, cut off the paper it was pressed on.
    static let waxSeal = "WaxSealLogo"
    /// The warm sky behind both gift screens, 1179x2556.
    static let clouds = "GiftClouds"

    static func layer(_ name: String) -> Image? {
        BrandMark.image(named: name)
    }

    /// Every gift layer is decoration: the screen's own copy carries the meaning.
    @ViewBuilder
    static func image(_ name: String, width: CGFloat, height: CGFloat, at origin: CGPoint) -> some View {
        if let artwork = layer(name) {
            artwork
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .offset(x: origin.x, y: origin.y)
                .accessibilityHidden(true)
                // Decorative: the tall open-envelope layer's rectangle reaches up over the
                // close button, and an Image hit-tests its whole frame, transparent pixels
                // included. Without this the gift's close button cannot be tapped.
                .allowsHitTesting(false)
        }
    }
}

/// The wax seal, **drawn**: a slightly irregular gold disc with the app's own mark struck
/// into it. This is the fallback for a build without the asset catalog — the shipped
/// screens use `GiftArt.waxSeal`, which is the seal from the same render the closed
/// envelope's is baked into, so both gift screens carry one seal treatment.
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

/// The unopened envelope on `gift-closed`: the generated render, which already carries the
/// wax seal with the brand ring pressed into it, so no seal is drawn on top. Its frame is
/// the artwork's whole 1200x900 canvas (`PaywallMetrics.closedEnvelopeArt()`), which is a
/// little larger than the paper inside it.
struct SealedEnvelope: View {
    private static let canvas = PaywallMetrics.closedEnvelopeCanvas
    private static let paper = PaywallMetrics.closedEnvelopeArtBody

    var body: some View {
        GeometryReader { proxy in
            if let artwork = GiftArt.layer(GiftArt.closedEnvelope) {
                artwork
                    .resizable()
                    .interpolation(.high)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                DrawnSealedEnvelope()
                    .frame(
                        width: proxy.size.width * Self.paper.width / Self.canvas.width,
                        height: proxy.size.height * Self.paper.height / Self.canvas.height
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The vector sealed envelope Phase 3 drew, kept as the no-catalog fallback: a paper
/// rectangle with the classic four folds and a wax seal where they meet.
private struct DrawnSealedEnvelope: View {
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
    }
}

// MARK: - Opened envelope

/// The opened envelope on `gift-open`, stacked the way the render is composed: the
/// envelope layer, then the offer card **clipped at the front pocket's mouth** so it
/// stands in the pocket instead of floating over it, then the wax seal over the point
/// where the two front edges meet.
///
/// It fills the whole reference canvas so every point is an absolute reference coordinate
/// rather than a fraction of some intermediate box.
struct OpenedEnvelope<Card: View>: View {
    @ViewBuilder var card: () -> Card

    private nonisolated static var geometry: PaywallMetrics.OpenEnvelope {
        PaywallMetrics.openEnvelopeGeometry
    }

    var body: some View {
        let geometry = Self.geometry
        ZStack(alignment: .topLeading) {
            envelope(geometry)
            cardInPocket(geometry)
            seal(geometry)
        }
        .frame(
            width: PaywallMetrics.referenceWidth,
            height: PaywallMetrics.referenceHeight,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func envelope(_ geometry: PaywallMetrics.OpenEnvelope) -> some View {
        if GiftArt.layer(GiftArt.openEnvelope) != nil {
            GiftArt.image(
                GiftArt.openEnvelope,
                width: geometry.art.width,
                height: geometry.art.height,
                at: CGPoint(x: geometry.art.minX, y: geometry.art.minY)
            )
        } else {
            DrawnOpenEnvelope(geometry: geometry)
        }
    }

    /// The paper and the offer copy travel together: both are cut off at the pocket's
    /// mouth, so the card reads as one sheet slid down inside the envelope.
    private func cardInPocket(_ geometry: PaywallMetrics.OpenEnvelope) -> some View {
        ZStack(alignment: .topLeading) {
            if GiftArt.layer(GiftArt.card) != nil {
                GiftArt.image(
                    GiftArt.card,
                    width: geometry.cardArt.width,
                    height: geometry.cardArt.height,
                    at: CGPoint(x: geometry.cardArt.minX, y: geometry.cardArt.minY)
                )
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(GiftPalette.offerCard)
                    .shadow(color: GiftPalette.envelopeShade.opacity(0.3), radius: 8, y: 4)
                    .frame(width: geometry.card.width, height: geometry.card.height)
                    .offset(x: geometry.card.minX, y: geometry.card.minY)
                    .accessibilityHidden(true)
            }

            card()
                .frame(width: geometry.card.width, height: geometry.card.height)
                .offset(x: geometry.card.minX, y: geometry.card.minY)
        }
        .frame(
            width: PaywallMetrics.referenceWidth,
            height: PaywallMetrics.referenceHeight,
            alignment: .topLeading
        )
        .clipShape(PocketMouth(geometry: geometry))
    }

    @ViewBuilder
    private func seal(_ geometry: PaywallMetrics.OpenEnvelope) -> some View {
        let diameter = PaywallMetrics.openSealDiameter
        let origin = CGPoint(
            x: geometry.sealCenter.x - diameter / 2,
            y: geometry.sealCenter.y - diameter / 2
        )
        if GiftArt.layer(GiftArt.waxSeal) != nil {
            GiftArt.image(GiftArt.waxSeal, width: diameter, height: diameter, at: origin)
        } else {
            WaxSeal()
                .frame(width: diameter, height: diameter)
                .offset(x: origin.x, y: origin.y)
        }
    }
}

/// Everything above the front pocket's top edge, in reference-canvas coordinates: a flat
/// line across the pocket's corners that dips to the point where its two edges meet. Clip
/// the card to it and the card ends exactly where the paper in front of it begins.
struct PocketMouth: Shape {
    let geometry: PaywallMetrics.OpenEnvelope

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: geometry.pocketEdgeY(atX: rect.maxX)))
        path.addLine(to: CGPoint(x: geometry.right, y: geometry.bodyTop))
        path.addLine(to: geometry.pocketPoint)
        path.addLine(to: CGPoint(x: geometry.left, y: geometry.bodyTop))
        path.addLine(to: CGPoint(x: rect.minX, y: geometry.pocketEdgeY(atX: rect.minX)))
        path.closeSubpath()
        return path
    }
}

/// The vector opened envelope Phase 3 drew, kept as the no-catalog fallback.
private struct DrawnOpenEnvelope: View {
    let geometry: PaywallMetrics.OpenEnvelope

    var body: some View {
        ZStack(alignment: .topLeading) {
            AbsolutePath { path in
                path.move(to: geometry.flapApex)
                path.addLine(to: CGPoint(x: geometry.left, y: geometry.bodyTop))
                path.addLine(to: CGPoint(x: geometry.right, y: geometry.bodyTop))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [GiftPalette.envelopeFlap, GiftPalette.envelopeLining],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            AbsolutePath { path in
                path.move(to: CGPoint(x: geometry.left, y: geometry.bodyTop))
                path.addLine(to: geometry.pocketPoint)
                path.addLine(to: CGPoint(x: geometry.right, y: geometry.bodyTop))
                path.addLine(to: CGPoint(x: geometry.right, y: geometry.bottom))
                path.addLine(to: CGPoint(x: geometry.left, y: geometry.bottom))
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
        }
        .accessibilityHidden(true)
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
