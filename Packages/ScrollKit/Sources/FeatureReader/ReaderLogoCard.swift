import DesignSystem
import SwiftUI

/// The rounded mark that opens every surah: 281 px (93.7 pt) square in `reader-dark.png`,
/// centred, with the line mark inside it.
///
/// The artwork (`LogoCard` / `LogoCardLight`) lives in the **app's** asset catalog, so it
/// resolves through `Bundle.main` and is not visible to package previews. When it is missing
/// the card draws itself from tokens instead of leaving a hole.
struct ReaderLogoCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = ReaderMetrics.logoCardSize

    var body: some View {
        Group {
            if let artwork {
                artwork
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        // Decorative: the page's own reference line already names the surah.
        .accessibilityHidden(true)
    }

    private var assetName: String {
        colorScheme == .dark ? "LogoCard" : "LogoCardLight"
    }

    private var markName: String {
        colorScheme == .dark ? "LogoMarkWhite" : "LogoMarkBlack"
    }

    private var artwork: Image? {
        Self.image(named: assetName)
    }

    /// Card, corner and mark from tokens, for previews and any build without the catalog.
    private var fallback: some View {
        RoundedRectangle(cornerRadius: ReaderMetrics.logoCardRadius, style: .continuous)
            .fill(Color.cardBackground)
            .overlay {
                if let mark = Self.image(named: markName) {
                    mark
                        .resizable()
                        .scaledToFit()
                        .frame(width: ReaderMetrics.logoMarkSize, height: ReaderMetrics.logoMarkSize)
                } else {
                    Image(systemName: "moon.stars")
                        .font(.system(size: ReaderMetrics.logoMarkSize * Self.symbolFallbackRatio, weight: .light))
                        .foregroundStyle(Color.textPrimary)
                }
            }
    }

    /// The SF Symbol stand-in is drawn smaller than the line mark so it sits inside the card.
    static let symbolFallbackRatio: CGFloat = 0.6

    /// `Image(_:)` renders an empty box for a name the catalog does not have, so ask first.
    static func image(named name: String) -> Image? {
        #if canImport(UIKit)
            UIImage(named: name).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
            NSImage(named: name).map { Image(nsImage: $0) }
        #else
            nil
        #endif
    }
}

#Preview("Logo card dark") {
    ReaderLogoCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
