import SwiftUI

/// The header every sheet and the Deep Study page share: an optional leading control,
/// a centred title, an optional trailing control, and a hairline divider. Deep Study's
/// circular buttons are 132 px (44 pt); the translation sheet's "Done" is an
/// `OutlinePillButton`.
public struct SheetHeader<Leading: View, Trailing: View>: View {
    private let title: String
    private let showsDivider: Bool
    private let leading: Leading
    private let trailing: Trailing

    public init(
        title: String,
        showsDivider: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Text(title)
                    .font(.body(20, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    leading
                    Spacer(minLength: Spacing.md)
                    trailing
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .frame(minHeight: Metrics.headerButton)

            if showsDivider {
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: Stroke.hairline)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Trailing-control-only headers (the translation sheet's "Done"). There is
/// deliberately no leading-only twin: two single-closure overloads would make
/// `SheetHeader(title:) { ... }` ambiguous.
public extension SheetHeader where Leading == EmptyView {
    init(title: String, showsDivider: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, showsDivider: showsDivider, leading: { EmptyView() }, trailing: trailing)
    }
}

/// The 44 pt circular glyph button in the Deep Study header.
public struct CircleIconButton: View {
    private let systemImage: String
    private let label: String
    private let action: () -> Void

    public init(systemImage: String, label: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(width: Metrics.headerButton, height: Metrics.headerButton)
                .background(Color.cardBackground, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

#Preview("SheetHeader light") {
    SheetHeaderPreviews().preferredColorScheme(.light)
}

#Preview("SheetHeader dark") {
    SheetHeaderPreviews().preferredColorScheme(.dark)
}

private struct SheetHeaderPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            SheetHeader(title: "Translation") {
                OutlinePillButton("Done", height: 42) {}
                    .frame(width: 110)
            }
            SheetHeader(title: "Al-Baqarah") {
                CircleIconButton(systemImage: "checkmark.circle", label: "Mark complete") {}
            } trailing: {
                CircleIconButton(systemImage: "xmark", label: "Close") {}
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.sheetBackground)
    }
}
