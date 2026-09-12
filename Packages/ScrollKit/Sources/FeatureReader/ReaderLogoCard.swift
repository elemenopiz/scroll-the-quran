import DesignSystem
import SwiftUI

/// The rounded mark that opens every surah: 281 px (93.7 pt) square in `reader-dark.png`,
/// centred, with the brand mark inside it.
///
/// The artwork (`LogoCard` / `LogoCardLight`) lives in the **app's** asset catalog, so it
/// resolves through `Bundle.main` and is not visible to package previews. When it is missing
/// the card draws itself from tokens with a `BrandMark` inside, instead of leaving a hole.
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

    private var artwork: Image? {
        BrandMark.image(named: assetName)
    }

    /// Card, corner and mark from tokens, for previews and any build without the catalog.
    private var fallback: some View {
        RoundedRectangle(cornerRadius: ReaderMetrics.logoCardRadius, style: .continuous)
            .fill(Color.cardBackground)
            .overlay {
                BrandMark()
                    .frame(width: ReaderMetrics.logoMarkSize, height: ReaderMetrics.logoMarkSize)
            }
    }
}

#Preview("Logo card dark") {
    ReaderLogoCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
