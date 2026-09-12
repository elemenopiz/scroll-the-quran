import SwiftUI

/// A reading-plan tile: cover artwork with an optional diagonal "START HERE" ribbon
/// across the top-leading corner, then title, meta line and a bold tagline.
///
/// Artwork is injected as a view so `DesignSystem` stays free of asset dependencies —
/// Phase 2g supplies the real images, previews use a gradient. The cover is laid out
/// as a square that fills the card's width; pass an `Image` already made
/// `.resizable().scaledToFill()`.
public struct PlanCard<Cover: View>: View {
    private let title: String
    private let meta: String
    private let tagline: String?
    private let ribbon: String?
    private let cover: Cover
    private let action: (() -> Void)?

    public init(
        title: String,
        meta: String,
        tagline: String? = nil,
        ribbon: String? = nil,
        @ViewBuilder cover: () -> Cover,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.meta = meta
        self.tagline = tagline
        self.ribbon = ribbon
        self.cover = cover()
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { card }
                .buttonStyle(.pressable)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `Color.clear` takes the proposed width and squares it, so the cover never
            // reports an unbounded ideal size — an `aspectRatio(_:contentMode: .fill)`
            // straight on the artwork makes a row of these overflow its container.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { cover }
                .overlay(alignment: .topLeading) {
                    if let ribbon {
                        CornerRibbon(text: ribbon)
                    }
                }
                .clipped()
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title)
                    .font(.body(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(meta)
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
                if let tagline {
                    Text(tagline)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Radius.chip, style: .continuous))
        // `#FFFFFF` on the plans sheet's `#FAFAFC`. See `Color.cardBorder`; no-op on dark.
        .cardEdge(radius: Radius.chip)
        .accessibilityElement(children: .combine)
    }
}

/// The 45° "START HERE" banner across a plan cover's top-leading corner.
///
/// The band is given an explicit size and then rotated about its own centre, so the
/// offset that lands that centre on the corner diagonal is exact: half the band's
/// width and height back from `topLeading`, plus `cornerDistance` along both axes.
/// Sizing it by its text instead would let a longer word slide off the corner and get
/// clipped by the card.
public struct CornerRibbon: View {
    private let text: String
    private let bandWidth: CGFloat
    private let bandHeight: CGFloat
    private let cornerDistance: CGFloat

    public init(
        text: String,
        bandWidth: CGFloat = 150,
        bandHeight: CGFloat = 22,
        cornerDistance: CGFloat = 34
    ) {
        self.text = text
        self.bandWidth = bandWidth
        self.bandHeight = bandHeight
        self.cornerDistance = cornerDistance
    }

    public var body: some View {
        Text(text)
            .font(.body(10, weight: .heavy))
            .textCase(.uppercase)
            .tracking(Tracking.capsTight)
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .frame(width: bandWidth, height: bandHeight)
            .background(Color.black)
            .rotationEffect(.degrees(-45))
            .offset(x: cornerDistance - bandWidth / 2, y: cornerDistance - bandHeight / 2)
            .accessibilityHidden(true)
    }
}

#Preview("PlanCard light") {
    PlanCardPreviews().preferredColorScheme(.light)
}

#Preview("PlanCard dark") {
    PlanCardPreviews().preferredColorScheme(.dark)
}

private struct PlanCardPreviews: View {
    private let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.md) {
            PlanCard(
                title: "Start With Al-Fatiha",
                meta: "7 days · about 5 min/day",
                tagline: "The #1 place to start",
                ribbon: "Start here"
            ) {
                LinearGradient(colors: [.flameTop, .flameBottom], startPoint: .top, endPoint: .bottom)
            }
            PlanCard(
                title: "A Surah a Day",
                meta: "30 days · about 4 min/day",
                tagline: "Daily wisdom"
            ) {
                LinearGradient(colors: [.sectionBlue, .sectionBrown], startPoint: .topLeading, endPoint: .bottom)
            }
        }
        .padding(Metrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
    }
}
