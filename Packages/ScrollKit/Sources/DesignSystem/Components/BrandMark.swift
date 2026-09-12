import SwiftUI

/// Which ink the mark is drawn in.
public enum BrandMarkInk: Sendable {
    /// White on dark, black on light — the usual case.
    case automatic
    /// Always the light-ground ink, for a mark sitting on a known-light surface.
    case black
    /// Always the dark-ground ink, for a mark sitting on a known-dark surface.
    case white
    /// The silhouette flooded with an arbitrary colour. The artwork is a solid shape, so
    /// template rendering tints it exactly; the gift envelope's wax impression needs two
    /// such copies (a dark strike and a light highlight) of the one mark.
    case tinted(Color)
}

/// The app's mark: the arabesque ring supplied as `Artwork/Logo/Variants/logo-transparent.png`
/// and rendered by `Artwork/tools/logo.sh` into every size the app needs.
///
/// The artwork ships in the **app's** asset catalog (`LogoMarkWhite` / `LogoMarkBlack`), so
/// it resolves through `Bundle.main` and package previews cannot see it. When it is missing
/// the view draws a plain token-coloured ring rather than leaving a hole.
///
/// Square by construction — give it a square frame, or a `scaledToFit` one, and it centres.
public struct BrandMark: View {
    @Environment(\.colorScheme) private var colorScheme

    private let ink: BrandMarkInk

    public init(ink: BrandMarkInk = .automatic) {
        self.ink = ink
    }

    public var body: some View {
        Group {
            if let artwork = Self.image(named: assetName) {
                artwork
                    .resizable()
                    .renderingMode(tint == nil ? .original : .template)
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(tint ?? fallbackColor)
            } else {
                fallback
            }
        }
        // Decorative everywhere it appears: the surrounding screen already names itself.
        .accessibilityHidden(true)
    }

    private var isLightInk: Bool {
        switch ink {
        case .white: true
        case .black, .tinted: false
        case .automatic: colorScheme == .dark
        }
    }

    /// A tinted mark always starts from the black rendition: template rendering throws the
    /// source colour away, and the black PNG is the one with no white halo to alias against.
    private var assetName: String {
        isLightInk ? "LogoMarkWhite" : "LogoMarkBlack"
    }

    private var tint: Color? {
        if case let .tinted(colour) = ink { colour } else { nil }
    }

    private var fallbackColor: Color {
        switch ink {
        case .white: .white
        case .black: .black
        case let .tinted(colour): colour
        case .automatic: .textPrimary
        }
    }

    /// Stand-in for previews and any build without the app catalog: the mark's silhouette
    /// reduced to the ring it reads as at small sizes.
    private var fallback: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Circle()
                .strokeBorder(fallbackColor, lineWidth: side * Self.fallbackStrokeRatio)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Optically matched to the supplied artwork's band weight.
    public static let fallbackStrokeRatio: CGFloat = 0.075

    /// `Image(_:)` renders an empty box for a name the catalog does not have, so ask first.
    public static func image(named name: String) -> Image? {
        #if canImport(UIKit)
            UIImage(named: name).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
            NSImage(named: name).map { Image(nsImage: $0) }
        #else
            nil
        #endif
    }
}

#Preview("Brand mark") {
    HStack(spacing: 32) {
        BrandMark(ink: .black)
            .frame(width: 96, height: 96)
            .padding(24)
            .background(Color.cardBackground.colorInvert())
        BrandMark(ink: .white)
            .frame(width: 96, height: 96)
            .padding(24)
            .background(Color.black)
    }
    .padding(24)
}
