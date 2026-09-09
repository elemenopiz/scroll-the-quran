import DesignSystem
import QuranData
import StudyContent
import SwiftUI

/// Discover card geometry, measured from `Reference/discover-dark.png`
/// (1179x2556 px for 393x852 pt, so pt = px / 3).
enum DiscoverMetrics {
    /// Card fill `#1E1E23` runs x = 48..1130 px, i.e. the 16 pt page margin.
    static let cardInset = Metrics.cardInset
    /// Card top 360 px → theme chip top 420 px: 60 px of padding.
    static let cardPadding: CGFloat = 20
    /// Air above and below the card inside its page.
    ///
    /// The reference card runs y = 360..2141 px, i.e. 120..713.7 pt of an 852 pt screen —
    /// 69.7 % of the screen height, sitting a little above centre. Measured on the
    /// 402x874 pt simulator (which `Tools/snapshot/compare.sh` normalises back to
    /// 393x852) that is 84 pt of air on each side of a page.
    ///
    /// The card centres inside what is left and grows past the reference band when it
    /// has to: our card carries a muted Arabic line the reference has no equivalent of
    /// (CLAUDE.md rule 5), which is worth about 24 pt, and a four-line ayah instead of
    /// the reference's three.
    static let pagePadding: CGFloat = 84
    /// "James 1:2-3": cap height 81 px.
    static let referenceSize: CGFloat = 44
    /// "KJV": 13 pt, set very wide.
    static let tagSize: CGFloat = 13
    static let tagTracking: CGFloat = 2
    /// MEANING body: line pitch 70 px = 23.3 pt at 1.371 em.
    static let bodySize: CGFloat = 17
    /// The DID YOU KNOW box is 329 px tall with three lines of body copy in it.
    static let didYouKnowLines = 3
    static let meaningLines = 4
}

/// A cross-reference chip: the passage and the name to print on it.
struct ReferenceChip: Identifiable, Hashable {
    let passage: PassageRef
    let title: String

    var id: String {
        passage.key
    }
}

/// One full-height Discover card.
///
/// Everything above the action row is fixed-height content; a single `Spacer` between
/// "Deep study" and the icons absorbs the difference, which is how the reference keeps
/// the icon row pinned near the bottom of a card whose body copy varies in length.
@MainActor
struct DiscoverCard: View {
    let presentation: PassagePresentation
    let themeTitle: String?
    let study: Study?
    /// Pre-resolved so the card never reaches into a store: `("Al-A'raf 7:156", 7:156)`.
    let crossRefs: [ReferenceChip]
    let isSaved: Bool
    let isRead: Bool
    let onDeepStudy: () -> Void
    let onOpenReference: (PassageRef) -> Void
    let onSave: () -> Void
    let onNote: () -> Void
    let onShare: () -> Void
    let onMarkRead: () -> Void

    var body: some View {
        CardContainer(
            radius: Radius.cardLarge,
            padding: DiscoverMetrics.cardPadding,
            background: .cardBackground
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if let themeTitle, !themeTitle.isEmpty {
                    Chip(themeTitle)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("discover.themeChip")
                }
                Text(presentation.reference)
                    .font(.serifDisplay(DiscoverMetrics.referenceSize))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xs)
                    .accessibilityIdentifier("discover.reference")
                Text(presentation.translationTag)
                    .font(.body(DiscoverMetrics.tagSize, weight: .semibold))
                    .tracking(DiscoverMetrics.tagTracking)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xxs)
                VerseText(
                    arabic: presentation.arabic,
                    english: presentation.quoted,
                    size: .discover,
                    style: .italic
                )
                .padding(.top, Spacing.lg)
                .accessibilityIdentifier("discover.quote")

                meaning
                didYouKnow
                crossReferences
                deepStudyLink

                Spacer(minLength: Spacing.lg)

                ActionIconRow.standard(
                    identifierPrefix: "discover.actions",
                    isSaved: isSaved,
                    isRead: isRead,
                    save: onSave,
                    comment: onNote,
                    share: onShare,
                    markRead: onMarkRead
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shadow(color: .black.opacity(0.45), radius: 22, y: 6)
        // `.accessibilityIdentifier` on a view that is not itself an accessibility element
        // propagates down and *overwrites* the identifiers its descendants set: without
        // this, every button in the card answers to "discover.card" and none of
        // `discover.deepStudy`, `discover.actions.save`, `discover.themeChip` … exists.
        // Making the card a container element stops the propagation and leaves the
        // children their own ids, the same shape `ReaderView` uses.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discover.card")
    }

    // MARK: - Blocks

    @ViewBuilder
    private var meaning: some View {
        if let text = study?.meaning, !text.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CapsLabel(text: StudySection.meaning.displayTitle, size: DeepStudyMetrics.labelSize)
                Text(text)
                    .font(.serifBody(DiscoverMetrics.bodySize))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(DiscoverMetrics.meaningLines)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, Spacing.xl)
            .accessibilityIdentifier("discover.meaning")
        }
    }

    @ViewBuilder
    private var didYouKnow: some View {
        if let text = study?.didYouKnow, !text.isEmpty {
            CardContainer(
                radius: Radius.cardSmall,
                padding: Spacing.lg,
                background: .didYouKnowBackground
            ) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    CapsLabel(
                        icon: "lightbulb.fill",
                        text: StudySection.didYouKnow.displayTitle,
                        size: DeepStudyMetrics.labelSize,
                        tint: .ratingStar
                    )
                    Text(text)
                        .font(.serifBody(DiscoverMetrics.bodySize))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(DiscoverMetrics.didYouKnowLines)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, Spacing.md)
            .accessibilityIdentifier("discover.didYouKnow")
        }
    }

    @ViewBuilder
    private var crossReferences: some View {
        if !crossRefs.isEmpty {
            HStack(spacing: Spacing.md) {
                ForEach(crossRefs) { chip in
                    Chip(chip.title, kind: .crossReference) {
                        onOpenReference(chip.passage)
                    }
                    .accessibilityIdentifier("discover.crossRef.\(chip.passage.key)")
                }
                Spacer(minLength: 0)
            }
            .padding(.top, Spacing.md)
        }
    }

    private var deepStudyLink: some View {
        Button(action: onDeepStudy) {
            HStack(spacing: Spacing.sm) {
                Text("Deep study")
                    .font(.body(16, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .padding(.top, Spacing.xs)
        .accessibilityIdentifier("discover.deepStudy")
    }
}
