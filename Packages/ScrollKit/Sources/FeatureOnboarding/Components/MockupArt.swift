import DesignSystem
import Foundation
import SwiftUI

/// The screen inside a funnel slide's `PhoneFrame`: a real capture of one of our own
/// screens — Reader, Plans, Discover, Verse Search — shipped as a bundled PNG.
///
/// **Why a PNG and not the live view.** `FeatureOnboarding` sits *below*
/// `FeatureReader` / `FeatureHome` / `FeatureDiscover` in the package graph and cannot
/// import them. The captures are made from the running app by
/// `Tools/snapshot/render-mockups.sh` (`--screenshot reader | plans-sheet | discover |
/// verse-search`) and land in `Sources/FeatureOnboarding/Resources/Mockup-<name>.png`,
/// which `Package.swift`'s `resources: [.process("Resources")]` rule bundles. Re-run that
/// script after any change to those four screens.
///
/// **Fit, never fill.** Each capture is a whole 402 x 874 pt screen, shipped at 690 x 1500
/// px (~3x the width it is drawn at) with the display's corner radius already cut into its
/// alpha. `PhoneFrame`'s window has the same 402:874 aspect, so `.fit` lands the capture on
/// it edge to edge with nothing to crop: the status bar's clock, the Dynamic Island and all
/// four tab labels stay whole. The old frame scaled the capture to *fill* a window of a
/// different aspect and centre-cropped ~1.5 %, which was enough to cut the clock in half and
/// clip "Community" and "The Quran" down to "mmunity" and "The Qu".
struct MockupArt: View {
    let mockup: OnboardingContent.Mockup
    let scale: ReferenceScale

    private var size: CGSize { PhoneFrameLayout(scale: scale).screenSize }

    var body: some View {
        Group {
            if let image = mockup.image {
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else {
                base
            }
        }
        .background(base)
        .accessibilityHidden(true)
        .accessibilityIdentifier("onboarding.slide.mockup.\(mockup.rawValue)")
    }

    /// Behind the capture, so a missing or still-decoding resource reads as the screen's
    /// own ground rather than as a hole in the phone frame.
    private var base: some View {
        (mockup == .discover || mockup == .deepstudy ? Color.rowBackground : Color.appBackgroundFlat)
            .frame(width: size.width, height: size.height)
    }
}

extension OnboardingContent.Mockup {
    /// The bundled capture for this slide. `deepstudy` is the Verse Search screen: the
    /// reference's fourth slide (`onboarding-slide4-search.png`) shows search, and the
    /// enum case is named for the feature the slide's copy sells.
    var resourceName: String {
        "Mockup-\(rawValue)"
    }

    /// Where the capture actually is inside `Bundle.module`. `MockupArtTests` asserts
    /// every case resolves, because a missing one is invisible: the phone frame just
    /// renders its own ground and reads as an empty screen.
    var resourceURL: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: "png")
    }

    /// Decoded from the file rather than looked up by name. `Image(_:bundle:)` goes
    /// through the asset-catalog lookup, which this target has no catalog for, so it
    /// silently draws nothing for a loose `.process`-ed PNG.
    var image: Image? {
        guard let url = resourceURL else { return nil }
        #if canImport(UIKit)
            return UIImage(contentsOfFile: url.path).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
            return NSImage(contentsOfFile: url.path).map { Image(nsImage: $0) }
        #else
            return nil
        #endif
    }
}
