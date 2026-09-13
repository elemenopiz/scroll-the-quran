import DesignSystem
import SwiftUI

/// The rounded mark at the top of every reader page: 281 px (93.7 pt) square in
/// `reader-dark.png`, centred, with the brand mark inside it.
///
/// Phase 4n made it a **control**. It is the original's way into the verse menu — tap the
/// card and the ayah's six options rise on a sheet — so it is a `Button` carrying the label
/// "Verse options" and is no longer hidden from VoiceOver. What it draws is unchanged, and
/// `.pressable` only scales while a finger is down, so `reader-dark` sees the same pixels.
///
/// The artwork (`LogoCard` / `LogoCardLight`) lives in the **app's** asset catalog, so it
/// resolves through `Bundle.main` and is not visible to package previews. When it is missing
/// the card draws itself from tokens with a `BrandMark` inside, instead of leaving a hole.
struct ReaderLogoCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = ReaderMetrics.logoCardSize
    /// Nil where there is nothing to open — previews, the component gallery — in which case
    /// the card stays the decorative mark it was before Phase 4n.
    var onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                mark.contentShape(.rect(cornerRadius: ReaderMetrics.logoCardRadius, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Verse options")
            .accessibilityIdentifier("reader.logo")
        } else {
            // Decorative: the page's own reference line already names the surah.
            mark.accessibilityHidden(true)
        }
    }

    private var mark: some View {
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
