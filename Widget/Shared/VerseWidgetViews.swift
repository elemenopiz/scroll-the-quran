import DesignSystem
import SwiftUI
import WidgetKit

/// The widget's four faces. One view per family, all fed by the same
/// `VerseWidgetContent`, all tapping through to `scrollthequran://verse/<s>/<a>`.
///
/// The muted Arabic line sits above the English on both system families (CLAUDE.md rule 5,
/// through `DesignSystem`'s `VerseText`). The accessory families are monochrome, tiny and
/// vibrancy-tinted, so they carry the English alone — a 12 pt Uthmani line there would be an
/// unreadable smudge, not context.
public struct VerseWidgetView: View {
    private let content: VerseWidgetContent
    private let family: WidgetFamily

    public init(content: VerseWidgetContent, family: WidgetFamily) {
        self.content = content
        self.family = family
    }

    public var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inline
            case .accessoryRectangular:
                rectangular
            case .systemMedium:
                system(lineLimit: 4)
            default:
                system(lineLimit: 3)
            }
        }
        .widgetURL(content.url)
        .accessibilityIdentifier("widget.\(identifier)")
    }

    // MARK: - Families

    private func system(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(content.reference)
                .capsLabelStyle()
                .foregroundStyle(Color.textSecondary)
                .accessibilityIdentifier("widget.reference")
            VerseText(
                arabic: content.arabic,
                english: content.english,
                size: .widget,
                style: .roman,
                alignment: .leading
            )
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.reference)
                .capsLabelStyle(size: 9)
                .accessibilityIdentifier("widget.reference")
            Text(content.english)
                .font(.serifBody(13))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
    }

    private var inline: some View {
        Text("\(content.reference) — \(content.english)")
            .lineLimit(1)
    }

    private var identifier: String {
        switch family {
        case .accessoryInline: "accessoryInline"
        case .accessoryRectangular: "accessoryRectangular"
        case .systemMedium: "systemMedium"
        default: "systemSmall"
        }
    }
}

/// `--screenshot widget-gallery`: every family, at its real point size, on one page.
///
/// It renders the same `VerseWidgetView` WidgetKit renders — the app just draws it at the
/// family's canvas size instead of the system doing it — so a regression in the widget shows
/// up in a normal app capture without installing anything on a Home Screen.
public struct WidgetGalleryScreen: View {
    private let content: VerseWidgetContent

    public init(content: VerseWidgetContent) {
        self.content = content
    }

    /// The gallery for a day — `SCROLL_FIXED_DATE` during a capture, so the ayah on screen
    /// is the same one every time.
    public init(today: Date = Date()) {
        content = VerseWidgetSource.content(on: today)
    }

    /// Canvas sizes on a 393 pt-wide screen (iPhone 15 Pro class).
    private static let canvases: [(family: WidgetFamily, name: String, size: CGSize)] = [
        (.systemSmall, "systemSmall", CGSize(width: 158, height: 158)),
        (.systemMedium, "systemMedium", CGSize(width: 338, height: 158)),
        (.accessoryRectangular, "accessoryRectangular", CGSize(width: 172, height: 76)),
        (.accessoryInline, "accessoryInline", CGSize(width: 250, height: 46)),
    ]

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(Self.canvases, id: \.name) { canvas in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(canvas.name)
                                .capsLabelStyle()
                                .foregroundStyle(Color.textTertiary)
                            VerseWidgetView(content: content, family: canvas.family)
                                .padding(Spacing.md)
                                .frame(width: canvas.size.width, height: canvas.size.height, alignment: .topLeading)
                                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.cardSmall))
                                // WidgetKit clips to the family's canvas; so does the gallery,
                                // or an overflowing small widget would look fine here and be
                                // cut off on the Home Screen.
                                .clipShape(RoundedRectangle(cornerRadius: Radius.cardSmall))
                        }
                        .accessibilityIdentifier("widgetGallery.\(canvas.name)")
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.widget-gallery")
    }
}
