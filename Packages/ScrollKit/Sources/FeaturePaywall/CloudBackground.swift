import DesignSystem
import SwiftUI

/// The warm paper sky behind both gift screens: the generated `GiftClouds` render, toned
/// to `Reference/gift-closed.png`'s own sky band by `Artwork/tools/gift-assets.sh`.
///
/// Without the app's asset catalog it falls back to the drawn version below — a flat
/// `GiftPalette.paper` ground with soft light blooms where the reference has clouds,
/// positioned in the 393x852 reference space and scaled to whatever the screen is, so the
/// composition survives a taller device.
struct CloudBackground: View {
    var body: some View {
        Group {
            if let sky = GiftArt.layer(GiftArt.clouds) {
                // The render is cut to 1179x2556 — the reference canvas's own aspect — so
                // filling the canvas neither stretches it nor crops anything.
                sky
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(
                        width: PaywallMetrics.referenceWidth,
                        height: PaywallMetrics.referenceHeight
                    )
                    .clipped()
            } else {
                DrawnCloudBackground()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DrawnCloudBackground: View {
    /// Centre and radius in reference points, plus the tint and how opaque the bloom is.
    private struct Bloom {
        let center: CGPoint
        let radius: CGFloat
        let color: Color
        let opacity: Double
    }

    private static let blooms: [Bloom] = [
        Bloom(center: CGPoint(x: 48, y: 200), radius: 132, color: GiftPalette.cloudWarm, opacity: 0.95),
        Bloom(center: CGPoint(x: 118, y: 236), radius: 74, color: GiftPalette.cloudWarm, opacity: 0.55),
        Bloom(center: CGPoint(x: 348, y: 232), radius: 118, color: GiftPalette.cloudCool, opacity: 0.9),
        Bloom(center: CGPoint(x: 268, y: 292), radius: 84, color: GiftPalette.cloudCool, opacity: 0.55),
        Bloom(center: CGPoint(x: 74, y: 516), radius: 126, color: GiftPalette.cloudWarm, opacity: 0.9),
        Bloom(center: CGPoint(x: 210, y: 546), radius: 78, color: GiftPalette.cloudWarm, opacity: 0.4),
        Bloom(center: CGPoint(x: 334, y: 470), radius: 70, color: GiftPalette.cloudCool, opacity: 0.35),
    ]

    var body: some View {
        GeometryReader { proxy in
            let scale = CGSize(
                width: proxy.size.width / PaywallMetrics.referenceWidth,
                height: proxy.size.height / PaywallMetrics.referenceHeight
            )
            ZStack {
                GiftPalette.paper
                ForEach(Array(Self.blooms.enumerated()), id: \.offset) { _, bloom in
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [bloom.color.opacity(bloom.opacity), bloom.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: bloom.radius * scale.width
                            )
                        )
                        .frame(
                            width: bloom.radius * 2.3 * scale.width,
                            height: bloom.radius * 1.75 * scale.height
                        )
                        .position(
                            x: bloom.center.x * scale.width,
                            y: bloom.center.y * scale.height
                        )
                }
            }
            .blur(radius: 12)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview("Clouds") {
    CloudBackground()
}
