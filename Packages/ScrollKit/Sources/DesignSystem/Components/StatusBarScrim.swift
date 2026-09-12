import SwiftUI

/// A fade behind the status bar, for a screen whose content scrolls under it.
///
/// A full-bleed `ScrollView` runs its content up to the top of the display, so the clock,
/// Wi-Fi and battery glyphs land on top of whatever line happens to be there. The
/// reference handles this by fading the content out toward the top rather than by insetting
/// it — the screen still reads as one continuous surface, and the status bar stays legible.
///
/// The scrim is the screen's own ground: opaque across the status bar, then a short fade to
/// clear so there is no visible edge where it ends. It is `allowsHitTesting(false)` so it
/// never eats a tap meant for the content, and hidden from VoiceOver.
///
/// Height comes from the real safe-area inset, so it is right on an island device, a notch
/// device and a notchless one. `Metrics.fade` is how far past the inset the gradient runs.
public struct StatusBarScrim: View {
    private let color: Color

    public init(color: Color = .appBackgroundFlat) {
        self.color = color
    }

    public enum Metrics {
        /// How far past the safe-area top the gradient takes to reach clear.
        public static let fade: CGFloat = 20
        /// Fraction of the scrim that stays fully opaque before the fade starts.
        public static let solid: Double = 0.62
    }

    public var body: some View {
        GeometryReader { proxy in
            let inset = proxy.safeAreaInsets.top
            LinearGradient(
                stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: Metrics.solid),
                    .init(color: color.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: inset + Metrics.fade)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Fades this view's content out behind the status bar. See `StatusBarScrim`.
    ///
    /// Apply it to the scroll container, *below* anything pinned to the top (a close
    /// button, a toolbar): those should stay at full contrast, and they already sit
    /// inside the safe area.
    func statusBarScrim(_ color: Color = .appBackgroundFlat) -> some View {
        overlay(alignment: .top) { StatusBarScrim(color: color) }
    }
}

#Preview("Status bar scrim") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0 ..< 40, id: \.self) { index in
                Text("Line \(index) of body copy that scrolls up under the clock.")
                    .font(.serifBody(17))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding()
    }
    .background(Color.appBackgroundFlat)
    .statusBarScrim()
}
