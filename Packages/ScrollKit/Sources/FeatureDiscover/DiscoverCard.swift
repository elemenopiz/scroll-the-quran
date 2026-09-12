import DesignSystem
import QuranData
import StudyContent
import SwiftUI

/// One full-height Discover card.
///
/// **Fixed slots.** Every block sits in a slot whose height is `DiscoverCardLayout`'s
/// arithmetic over the font metrics, so a one-ayah unit and the longest of the 326 build
/// a card of exactly the same height and the pager lands on every card the same way. The
/// slots are `minHeight`, so Dynamic Type still grows them.
///
/// **What is deliberately absent.** No translation badge and no Arabic line: the badge is
/// the reader toolbar's pill, and the muted Arabic layer stays on the reader page, the
/// Deep Study quote box, the share card and the widget (owner, Phase 4i amendment 2 —
/// recorded as the rule-5 exception in `Reference/scores.md`).
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
                chip
                title
                quote
                meaning
                didYouKnow
                crossReferences
                deepStudyLink
                actions
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

    // MARK: - Slots

    /// The chip's slot is reserved whether or not the unit is filed under a theme, so a
    /// themeless unit does not shorten the card.
    private var chip: some View {
        Group {
            if let themeTitle, !themeTitle.isEmpty {
                Chip(themeTitle)
                    .accessibilityIdentifier("discover.themeChip")
            }
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.chipHeight)
    }

    private var title: some View {
        Text(presentation.reference)
            .font(.serifDisplay(DiscoverMetrics.referenceSize))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(DiscoverMetrics.referenceMinimumScale)
            .frame(maxWidth: .infinity, minHeight: DiscoverCardLayout.titleSlot)
            .padding(.top, DiscoverMetrics.chipToTitle)
            .accessibilityIdentifier("discover.reference")
    }

    /// Four lines, tail-elided, centred in the slot when the passage is shorter — the same
    /// "…" treatment the meaning and the did-you-know box use.
    private var quote: some View {
        VerseText(
            arabic: nil,
            segments: presentation.segments,
            size: .discover,
            style: .italic,
            quoted: true,
            lineLimit: DiscoverMetrics.quoteLines
        )
        .frame(maxWidth: .infinity, minHeight: DiscoverCardLayout.quoteSlot)
        .padding(.top, DiscoverMetrics.titleToQuote)
        .accessibilityIdentifier("discover.quote")
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: DiscoverMetrics.labelToBody) {
            CapsLabel(text: StudySection.meaning.displayTitle, size: DeepStudyMetrics.labelSize)
                .lineLimit(1)
                .frame(minHeight: DiscoverCardLayout.capsLabelHeight, alignment: .leading)
            Text(study?.meaning ?? "")
                .font(.serifBody(DiscoverMetrics.bodySize))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(DiscoverMetrics.meaningLines)
                .multilineTextAlignment(.leading)
                .frame(
                    maxWidth: .infinity,
                    minHeight: DiscoverCardLayout.meaningSlot,
                    alignment: .topLeading
                )
        }
        .padding(.top, DiscoverMetrics.quoteToMeaning)
        .accessibilityIdentifier("discover.meaning")
    }

    private var didYouKnow: some View {
        CardContainer(
            radius: Radius.cardSmall,
            padding: DiscoverMetrics.didYouKnowPadding,
            background: .didYouKnowBackground
        ) {
            VStack(alignment: .leading, spacing: DiscoverMetrics.didYouKnowLabelGap) {
                CapsLabel(
                    icon: "lightbulb.fill",
                    text: StudySection.didYouKnow.displayTitle,
                    size: DeepStudyMetrics.labelSize,
                    tint: .ratingStar
                )
                .lineLimit(1)
                .frame(minHeight: DiscoverCardLayout.capsLabelWithIconHeight, alignment: .leading)
                Text(study?.didYouKnow ?? "")
                    .font(.serifBody(DiscoverMetrics.bodySize))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(DiscoverMetrics.didYouKnowLines)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: DiscoverCardLayout.didYouKnowSlot,
                        alignment: .topLeading
                    )
            }
        }
        .padding(.top, DiscoverMetrics.bodyToDidYouKnow)
        .accessibilityIdentifier("discover.didYouKnow")
    }

    /// One row, at most two chips — and the row's height is reserved even when the unit
    /// names no related passage.
    private var crossReferences: some View {
        HStack(spacing: Spacing.md) {
            ForEach(Array(crossRefs.prefix(2))) { chip in
                Chip(chip.title, kind: .crossReference) {
                    onOpenReference(chip.passage)
                }
                .accessibilityIdentifier("discover.crossRef.\(chip.passage.key)")
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Metrics.crossRefChipHeight)
        .padding(.top, DiscoverMetrics.didYouKnowToChips)
    }

    private var deepStudyLink: some View {
        Button(action: onDeepStudy) {
            HStack(spacing: Spacing.xs) {
                Text("Deep study")
                    .font(.body(17, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .padding(.top, DiscoverMetrics.chipsToDeepStudy)
        .accessibilityIdentifier("discover.deepStudy")
    }

    private var actions: some View {
        ActionIconRow.standard(
            identifierPrefix: "discover.actions",
            isSaved: isSaved,
            isRead: isRead,
            iconSize: DiscoverMetrics.actionIcon,
            columnWidth: DiscoverMetrics.actionColumnWidth,
            save: onSave,
            comment: onNote,
            share: onShare,
            markRead: onMarkRead
        )
        .padding(.top, DiscoverMetrics.deepStudyToActions)
    }
}
