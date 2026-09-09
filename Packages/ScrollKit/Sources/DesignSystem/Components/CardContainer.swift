import SwiftUI

/// The rounded surface every list of content sits on: `Color.cardBackground`,
/// 16 pt in from the screen edge (48 px in the references → 361 pt wide) and a
/// continuous corner. Radius defaults to `Radius.card`; Home's rows use
/// `Radius.cardSmall` and the Discover feed card uses `Radius.cardLarge`.
///
/// A `Color.cardBorder` hairline rides the same shape. It is a light-appearance-only
/// token (`.clear` on dark), there because a `#FFFFFF` card on the `#FAFAFC` page has
/// almost no edge of its own; pass `bordered: false` for a card that already sits on a
/// contrasting fill, such as the tinted Deep Study boxes or a card on white.
public struct CardContainer<Content: View>: View {
    private let radius: CGFloat
    private let padding: CGFloat
    private let background: Color
    private let bordered: Bool
    private let content: Content

    public init(
        radius: CGFloat = Radius.card,
        padding: CGFloat = Metrics.cardPadding,
        background: Color = .cardBackground,
        bordered: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.background = background
        self.bordered = bordered
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: .rect(cornerRadius: radius, style: .continuous))
            .cardEdge(radius: radius, enabled: bordered)
    }
}

#Preview("CardContainer light") {
    CardContainerPreviews().preferredColorScheme(.light)
}

#Preview("CardContainer dark") {
    CardContainerPreviews().preferredColorScheme(.dark)
}

private struct CardContainerPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            CardContainer(radius: Radius.cardSmall) {
                Text("Radius.cardSmall — 24 pt").font(.body(15))
            }
            CardContainer {
                Text("Radius.card — 28 pt").font(.body(15))
            }
            CardContainer(radius: Radius.cardLarge) {
                Text("Radius.cardLarge — 32 pt").font(.body(15))
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(Metrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}


public extension View {
    /// The light-mode card hairline, on a shape that matches the card's own corner.
    /// A no-op in dark appearance, where `Color.cardBorder` resolves fully transparent.
    func cardEdge(radius: CGFloat, enabled: Bool = true) -> some View {
        overlay {
            if enabled {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: Stroke.hairline)
            }
        }
    }
}
