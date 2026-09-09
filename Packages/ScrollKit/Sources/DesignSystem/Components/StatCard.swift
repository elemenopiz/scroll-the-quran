import SwiftUI

/// The Home streak / progress card: a 56 pt (168 px) filled circle, a large serif
/// value, a caps label, and an optional footer (a `ProgressBar` plus a caption, or the
/// seven-day dot strip). Card is `Radius.card` with 18 pt padding.
public struct StatCard<Footer: View>: View {
    /// How the leading circle is filled. `flame` is the measured streak gradient.
    public enum Emblem: Sendable {
        case flame
        case tinted(Color)
    }

    private let emblem: Emblem
    private let systemImage: String
    private let value: String
    private let caption: String
    private let trailing: String?
    private let footer: Footer

    public init(
        emblem: Emblem = .flame,
        systemImage: String,
        value: String,
        caption: String,
        trailing: String? = nil,
        @ViewBuilder footer: () -> Footer
    ) {
        self.emblem = emblem
        self.systemImage = systemImage
        self.value = value
        self.caption = caption
        self.trailing = trailing
        self.footer = footer()
    }

    public var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.lg) {
                    emblemView
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(value)
                            .font(.serifDisplay(38))
                            .foregroundStyle(Color.textPrimary)
                        CapsLabel(text: caption, size: 13)
                    }
                    Spacer(minLength: 0)
                    if let trailing {
                        Image(systemName: trailing)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                footer
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(value) \(caption)")
    }

    private var emblemView: some View {
        Image(systemName: systemImage)
            .font(.system(size: Metrics.statIcon * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Metrics.statIcon, height: Metrics.statIcon)
            .background {
                switch emblem {
                case .flame: Circle().fill(LinearGradient.flame)
                case let .tinted(color): Circle().fill(color)
                }
            }
    }
}

public extension StatCard where Footer == EmptyView {
    init(
        emblem: Emblem = .flame,
        systemImage: String,
        value: String,
        caption: String,
        trailing: String? = nil
    ) {
        self.init(
            emblem: emblem,
            systemImage: systemImage,
            value: value,
            caption: caption,
            trailing: trailing,
            footer: { EmptyView() }
        )
    }
}

#Preview("StatCard light") {
    StatCardPreviews().preferredColorScheme(.light)
}

#Preview("StatCard dark") {
    StatCardPreviews().preferredColorScheme(.dark)
}

private struct StatCardPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            StatCard(
                systemImage: "flame.fill",
                value: "1",
                caption: "Days opened",
                trailing: "square.and.arrow.up"
            ) {
                Text("Great start. Come back tomorrow to keep it going.")
                    .font(.body(16))
                    .foregroundStyle(Color.textPrimary)
            }
            StatCard(
                emblem: .tinted(Color(rgb: 0x8A7561)),
                systemImage: "book.fill",
                value: "<1%",
                caption: "Quran read"
            ) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ProgressBar(value: 0.008)
                    Text("1 of 114 surahs")
                        .font(.body(16))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(Metrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
