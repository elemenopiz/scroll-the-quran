import CoreGraphics
import DesignSystem
import SwiftUI

/// The device the funnel slides draw around our own screens, in **device points**.
///
/// One set of numbers, taken off the hardware rather than off the picture, so the SwiftUI
/// frame on the slides and the marketing frame `Artwork/tools/frame.py` rasterises into
/// `Artwork/Frames/phone-frame-1179x2556.png` are the same device at two scales. Anything
/// that needs the frame at a given size asks here and multiplies, so the frame cannot
/// drift into a shape no iPhone has.
///
/// **The frame draws no Dynamic Island.** The island belongs to the screen, and every
/// capture we put inside the frame is a *whole* screen — status bar, island and home
/// indicator included. Drawing a second one on top is what made the old frame read as a
/// sticker: two islands, one slightly bigger than the other.
enum DeviceFrameMetrics {
    /// iPhone 17 Pro: 402 x 874 pt, which is exactly what `--screenshot` captures
    /// (1206 x 2622 px at @3x).
    static let screenSize = CGSize(width: 402, height: 874)
    /// Display corner radius. The glass, not the enclosure.
    static let screenCornerRadius: CGFloat = 55
    /// The black border between the glass and the rail.
    static let innerBorder: CGFloat = 6
    /// The titanium rail itself.
    static let rim: CGFloat = 2.5
    /// Glass edge to enclosure edge.
    static let inset: CGFloat = innerBorder + rim
    /// 419 x 891 pt of enclosure.
    static let outerSize = CGSize(
        width: screenSize.width + inset * 2,
        height: screenSize.height + inset * 2
    )
    /// Concentric with the display: the two radii share a centre.
    static let outerCornerRadius: CGFloat = screenCornerRadius + inset

    /// The Dynamic Island, recorded so the numbers are not lost — **not drawn**. The
    /// capture inside the frame carries the real one, 126 x 37 pt, 11 pt below the glass.
    static let islandSize = CGSize(width: 126, height: 37)
    static let islandTop: CGFloat = 11

    /// How far a side button stands out of the rail.
    static let buttonProud: CGFloat = 3.5

    /// A side button. `top` is measured from the enclosure's top edge.
    struct SideButton: Hashable {
        let top: CGFloat
        let height: CGFloat
        let onLeft: Bool
    }

    /// Action, volume up and volume down on the left; power on the right.
    ///
    /// The two volume keys and the power key were measured off
    /// `Reference/onboarding-slide1-feed.png` — left nubs y 357.3...390.7 and 400...433.3
    /// pt, right nub 369.3...422.7 pt, each 2 pt proud of a 497.7 pt tall frame — and
    /// divided back out of that frame's scale, which lands them within a point of the
    /// hardware's own proportions. The action button sits above them, where the device
    /// has it; the reference's own bezel is too soft to show it.
    static let buttons: [SideButton] = [
        SideButton(top: 160, height: 30, onLeft: true),
        SideButton(top: 222, height: 60, onLeft: true),
        SideButton(top: 298, height: 60, onLeft: true),
        SideButton(top: 251, height: 96, onLeft: false),
    ]
}

/// The titanium of the device being drawn. Physical material, not app chrome — the same
/// reason `GiftPalette` keeps the envelope's paper next to the envelope.
enum DeviceFramePalette {
    /// Top of the rail gradient: `#B9B9BE`.
    static let rimLight = Color(rgb: 0xB9B9BE)
    /// Bottom of the rail gradient: `#8E8E93`, the grey `Tokens.textTertiary` also uses.
    static let rimDark = Color(rgb: 0x8E8E93)
    /// The half-point catch-light along the top edge: `#E6E6EB`.
    static let rimHighlight = Color(rgb: 0xE6E6EB)
    /// The black border between the rail and the glass: `#050506`.
    static let bezel = Color(rgb: 0x050506)
}

/// `DeviceFrameMetrics` resolved to the points a slide actually draws at.
///
/// The whole frame hangs off one number — the enclosure's height — so the screen window
/// inside it keeps the device's 402:874 aspect **exactly**. That is what lets `MockupArt`
/// *fit* its capture into the window instead of filling and cropping it: at this scale
/// even a 1.5 % crop takes the clock off the status bar and the outer tab labels off both
/// sides, which is what the old frame did.
struct PhoneFrameLayout: Equatable {
    /// Device points to view points.
    let unit: CGFloat

    init(scale: ReferenceScale) {
        unit = scale.height(OnboardingMetrics.phoneHeight) / DeviceFrameMetrics.outerSize.height
    }

    private func pt(_ value: CGFloat) -> CGFloat {
        value * unit
    }

    var outerSize: CGSize {
        CGSize(
            width: pt(DeviceFrameMetrics.outerSize.width),
            height: pt(DeviceFrameMetrics.outerSize.height)
        )
    }

    var screenSize: CGSize {
        CGSize(
            width: pt(DeviceFrameMetrics.screenSize.width),
            height: pt(DeviceFrameMetrics.screenSize.height)
        )
    }

    var outerCornerRadius: CGFloat {
        pt(DeviceFrameMetrics.outerCornerRadius)
    }

    var screenCornerRadius: CGFloat {
        pt(DeviceFrameMetrics.screenCornerRadius)
    }

    var rim: CGFloat {
        pt(DeviceFrameMetrics.rim)
    }

    var innerBorder: CGFloat {
        pt(DeviceFrameMetrics.innerBorder)
    }

    var inset: CGFloat {
        pt(DeviceFrameMetrics.inset)
    }

    var buttonProud: CGFloat {
        pt(DeviceFrameMetrics.buttonProud)
    }

    /// The bezel's rounded rectangle: the enclosure knocked in by the rail's width,
    /// concentric with both the enclosure and the glass.
    var bezelSize: CGSize {
        CGSize(width: outerSize.width - rim * 2, height: outerSize.height - rim * 2)
    }

    var bezelCornerRadius: CGFloat {
        outerCornerRadius - rim
    }

    /// One side button's frame in the enclosure's own coordinate space.
    func buttonRect(_ button: DeviceFrameMetrics.SideButton) -> CGRect {
        CGRect(
            x: button.onLeft ? -buttonProud : outerSize.width - rim,
            y: pt(button.top),
            width: rim + buttonProud,
            height: pt(button.height)
        )
    }
}

/// The device mockup the funnel slides show our own screens inside.
///
/// A thin titanium rail, a black border, the side buttons and the screen — nothing else.
/// The capture inside carries its own status bar, Dynamic Island and home indicator, so
/// the frame adds none of them.
struct PhoneFrame<Screen: View>: View {
    let scale: ReferenceScale
    @ViewBuilder var screen: Screen

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let layout = PhoneFrameLayout(scale: scale)
        ZStack(alignment: .topLeading) {
            // Under the rail, so the nubs read as part of the edge rather than as tabs
            // stuck onto it.
            ForEach(DeviceFrameMetrics.buttons, id: \.self) { button in
                let rect = layout.buttonRect(button)
                RoundedRectangle(cornerRadius: rect.width / 2, style: .continuous)
                    .fill(buttonGradient)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }

            RoundedRectangle(cornerRadius: layout.outerCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DeviceFramePalette.rimLight, DeviceFramePalette.rimDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    // The catch-light a milled edge has along its top face.
                    RoundedRectangle(cornerRadius: layout.outerCornerRadius, style: .continuous)
                        .trim(from: 0.02, to: 0.48)
                        .stroke(DeviceFramePalette.rimHighlight, lineWidth: layout.rim / 2)
                }
                .frame(width: layout.outerSize.width, height: layout.outerSize.height)

            RoundedRectangle(cornerRadius: layout.bezelCornerRadius, style: .continuous)
                .fill(DeviceFramePalette.bezel)
                .frame(width: layout.bezelSize.width, height: layout.bezelSize.height)
                .offset(x: layout.rim, y: layout.rim)

            screen
                .frame(width: layout.screenSize.width, height: layout.screenSize.height)
                .clipShape(
                    RoundedRectangle(cornerRadius: layout.screenCornerRadius, style: .continuous)
                )
                .offset(x: layout.inset, y: layout.inset)
        }
        .frame(width: layout.outerSize.width, height: layout.outerSize.height)
        .compositingGroup()
        .shadow(
            color: .black.opacity(
                colorScheme == .dark
                    ? OnboardingMetrics.phoneShadowOpacityDark
                    : OnboardingMetrics.phoneShadowOpacityLight
            ),
            radius: scale.width(OnboardingMetrics.phoneShadowRadius),
            y: scale.height(OnboardingMetrics.phoneShadowOffset)
        )
        .accessibilityHidden(true)
    }

    /// A machined nub catches the light across its width, not down its length.
    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [
                DeviceFramePalette.rimDark,
                DeviceFramePalette.rimLight,
                DeviceFramePalette.rimDark,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
