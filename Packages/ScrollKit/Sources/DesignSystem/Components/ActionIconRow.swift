import SwiftUI

/// One action under a verse. `id` becomes the accessibility identifier suffix.
public struct VerseAction: Identifiable {
    public let id: String
    public let systemImage: String
    /// Drawn instead of `systemImage` while `isOn` is true (e.g. `bookmark.fill`).
    public let filledSystemImage: String?
    public let label: String
    public let isOn: Bool
    public let action: @MainActor () -> Void

    public init(
        id: String,
        systemImage: String,
        filledSystemImage: String? = nil,
        label: String,
        isOn: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.systemImage = systemImage
        self.filledSystemImage = filledSystemImage
        self.label = label
        self.isOn = isOn
        self.action = action
    }

    var resolvedSystemImage: String {
        isOn ? (filledSystemImage ?? systemImage) : systemImage
    }
}

/// The row of verse actions at the foot of a Discover card: bookmark, comment, share,
/// mark-read. Evenly distributed across the card width, 24 pt glyphs in
/// `Color.textSecondary`.
public struct ActionIconRow: View {
    private let identifierPrefix: String
    private let actions: [VerseAction]
    private let iconSize: CGFloat
    private let columnWidth: CGFloat?

    /// - Parameters:
    ///   - iconSize: glyph point size. Defaults to `Metrics.actionIcon`.
    ///   - columnWidth: fixed distance between icon centres, the row then centred in its
    ///     container. `nil` spreads the icons evenly across the full width, which is what
    ///     every caller but the Discover card wants.
    public init(
        identifierPrefix: String,
        actions: [VerseAction],
        iconSize: CGFloat = Metrics.actionIcon,
        columnWidth: CGFloat? = nil
    ) {
        self.identifierPrefix = identifierPrefix
        self.actions = actions
        self.iconSize = iconSize
        self.columnWidth = columnWidth
    }

    /// The stock four-action row, wired by the caller.
    public static func standard(
        identifierPrefix: String,
        isSaved: Bool = false,
        isRead: Bool = false,
        iconSize: CGFloat = Metrics.actionIcon,
        columnWidth: CGFloat? = nil,
        save: @escaping @MainActor () -> Void,
        comment: @escaping @MainActor () -> Void,
        share: @escaping @MainActor () -> Void,
        markRead: @escaping @MainActor () -> Void
    ) -> ActionIconRow {
        ActionIconRow(
            identifierPrefix: identifierPrefix,
            actions: [
                VerseAction(
                    id: "save",
                    systemImage: "bookmark",
                    filledSystemImage: "bookmark.fill",
                    label: "Save",
                    isOn: isSaved,
                    action: save
                ),
                VerseAction(id: "comment", systemImage: "bubble.left", label: "Notes", action: comment),
                VerseAction(id: "share", systemImage: "square.and.arrow.up", label: "Share", action: share),
                VerseAction(
                    id: "read",
                    systemImage: "checkmark.circle",
                    filledSystemImage: "checkmark.circle.fill",
                    label: "Mark as read",
                    isOn: isRead,
                    action: markRead
                ),
            ],
            iconSize: iconSize,
            columnWidth: columnWidth
        )
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button(action: action.action) {
                    Image(systemName: action.resolvedSystemImage)
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundStyle(action.isOn ? Color.textPrimary : Color.textSecondary)
                        .frame(
                            width: columnWidth,
                            height: columnWidth == nil ? nil : Metrics.hitTarget
                        )
                        .frame(maxWidth: columnWidth == nil ? .infinity : nil, minHeight: Metrics.hitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(action.label)
                .accessibilityIdentifier("\(identifierPrefix).\(action.id)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("ActionIconRow light") {
    ActionIconRowPreviews().preferredColorScheme(.light)
}

#Preview("ActionIconRow dark") {
    ActionIconRowPreviews().preferredColorScheme(.dark)
}

private struct ActionIconRowPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            ActionIconRow.standard(
                identifierPrefix: "discover.actions",
                save: {}, comment: {}, share: {}, markRead: {}
            )
            ActionIconRow.standard(
                identifierPrefix: "discover.actionsOn",
                isSaved: true, isRead: true,
                save: {}, comment: {}, share: {}, markRead: {}
            )
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
