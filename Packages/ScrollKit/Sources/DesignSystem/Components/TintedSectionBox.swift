import SwiftUI

/// The five section tints. Dark values were sampled from the Deep Study captures;
/// the light halves are derived (see the comment on the palette in `Tokens.swift`).
public enum TintedSectionKind: String, CaseIterable, Sendable {
    /// The quoted ayah at the top of Deep Study.
    case quote
    /// HISTORICAL CONTEXT.
    case historical
    /// LIFE IN THE PROPHET'S TIME.
    case life
    /// DID YOU KNOW?
    case dyk
    /// APPLY IT.
    case apply

    public var tint: Color {
        switch self {
        case .quote: .sectionQuote
        case .historical: .sectionBlue
        case .life: .sectionBrown
        case .dyk: .sectionGray
        case .apply: .sectionWine
        }
    }

    /// The default caps label. Callers may override for a localised string.
    public var title: String? {
        switch self {
        case .quote: nil
        case .historical: "Historical context"
        case .life: "Life in the Prophet's time"
        case .dyk: "Did you know?"
        case .apply: "Apply it"
        }
    }

    /// The SF Symbol the reference draws before the label.
    public var systemImage: String? {
        switch self {
        case .quote: nil
        case .historical: "clock"
        case .life: "person.2"
        case .dyk: "lightbulb.fill"
        case .apply: "heart.text.square"
        }
    }

    /// The icon tint. The label itself always stays `Color.textSecondary`.
    public var iconTint: Color {
        switch self {
        case .quote: .textSecondary
        case .historical: .blue
        case .life: .flameTop
        case .dyk: .ratingStar
        case .apply: .flameBottom
        }
    }
}

/// The tinted Deep Study section: a rounded box in one of five measured tints with a
/// `CapsLabel` header. Boxes are inset 24 pt from the screen edge (72 px in
/// deepstudy-top → 345 pt wide) and padded 20 pt inside.
///
/// The header is a slot, not a fixed label: the reference draws a small copy button on
/// the same line as the caps label, and `FeatureDiscover` used to compose its own box
/// rather than use this one for exactly that reason. Pass the button (or anything else)
/// as `accessory` and it lands to the right of the label, before the spacer.
///
/// `kind` is optional so an untinted section — most of Deep Study — can use the same
/// header without gaining a fill: `nil` draws the header and content flat on the page.
public struct TintedSectionBox<Accessory: View, Content: View>: View {
    private let kind: TintedSectionKind?
    private let title: String?
    private let icon: String?
    private let iconTint: Color?
    private let labelSize: CGFloat
    private let identifier: String?
    private let accessory: Accessory
    private let content: Content

    public init(
        kind: TintedSectionKind?,
        title: String? = nil,
        icon: String? = nil,
        iconTint: Color? = nil,
        labelSize: CGFloat = 11,
        identifier: String? = nil,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.kind = kind
        self.title = title
        self.icon = icon
        self.iconTint = iconTint
        self.labelSize = labelSize
        self.identifier = identifier
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let label = title ?? kind?.title {
                HStack(spacing: Spacing.sm) {
                    CapsLabel(
                        icon: icon ?? kind?.systemImage,
                        text: label,
                        size: labelSize,
                        tint: iconTint ?? kind?.iconTint
                    )
                    accessory
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SectionTint(kind: kind))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? kind.map { "section.\($0.rawValue)" } ?? "section")
    }
}

public extension TintedSectionBox where Accessory == EmptyView {
    /// A box with no header accessory — the original shape.
    init(
        kind: TintedSectionKind?,
        title: String? = nil,
        icon: String? = nil,
        iconTint: Color? = nil,
        labelSize: CGFloat = 11,
        identifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            kind: kind,
            title: title,
            icon: icon,
            iconTint: iconTint,
            labelSize: labelSize,
            identifier: identifier,
            accessory: { EmptyView() },
            content: content
        )
    }
}

/// The measured fill and 20 pt inset a tinted section gets, and nothing at all for an
/// untinted one — an untinted section sits flat on the page at the page's own inset.
private struct SectionTint: ViewModifier {
    let kind: TintedSectionKind?

    func body(content: Content) -> some View {
        if let kind {
            content
                .padding(Metrics.sectionBoxPadding)
                .background(kind.tint, in: .rect(cornerRadius: Radius.cardSmall, style: .continuous))
        } else {
            content
        }
    }
}

#Preview("TintedSectionBox light") {
    TintedSectionBoxPreviews().preferredColorScheme(.light)
}

#Preview("TintedSectionBox dark") {
    TintedSectionBoxPreviews().preferredColorScheme(.dark)
}

private struct TintedSectionBoxPreviews: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                TintedSectionBox(kind: .quote) {
                    VerseText(
                        arabic: VersePreviewFixture.shortArabic,
                        english: VersePreviewFixture.shortEnglish,
                        size: .deepStudy,
                        style: .italic
                    )
                }
                ForEach(TintedSectionKind.allCases.filter { $0 != .quote }, id: \.self) { kind in
                    TintedSectionBox(kind: kind) {
                        Text("Measured tint \(kind.rawValue). The body copy is Source Serif at 17 pt.")
                            .font(.serifBody())
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .padding(.horizontal, Metrics.sectionBoxInset)
            .padding(.vertical, Spacing.xl)
        }
        .background(Color.appBackgroundFlat)
    }
}
