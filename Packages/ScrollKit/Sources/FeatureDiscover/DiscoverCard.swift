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
/// **The body is a budget, not three fixed slots (Phase 4m).** The owner asked for "the
/// entirety of the verse" on the card and said "the meaning/did you know can be cut off",
/// so the quote, MEANING and DID YOU KNOW share one `bodyBudget`-tall container:
/// `DiscoverCardLayout.body(for:meaning:didYouKnow:width:)` gives the quote every line it
/// needs (stepping 16 → 15 → 14 pt when it must), MEANING what is left down to two lines,
/// and DID YOU KNOW its box only if there is still room. The chip, the title, the
/// cross-reference row, "Deep study ›" and the action row do not move, and the card is
/// still exactly `DiscoverCardLayout.cardHeight` tall.
///
/// **What is deliberately absent.** No translation badge and no Arabic line: the badge is
/// the reader toolbar's pill, and the muted Arabic layer stays on the reader page, the
/// Deep Study quote box, the share card and the widget (owner, Phase 4i amendment 2 —
/// recorded as the rule-5 exception in `Reference/scores.md`).
@MainActor
struct DiscoverCard: View {
    let presentation: PassagePresentation
    /// The width the card's text is laid out in, from the page's own geometry — the
    /// body plan is a function of it, so it is measured rather than assumed.
    let contentWidth: CGFloat
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
                bodySlot
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

    /// How this card divides the body between the quote, MEANING and DID YOU KNOW.
    private var plan: DiscoverCardLayout.BodyPlan {
        DiscoverCardLayout.body(
            for: presentation.layoutQuote,
            meaning: study?.meaning ?? "",
            didYouKnow: study?.didYouKnow ?? "",
            width: contentWidth
        )
    }

    /// The one container the three body blocks share.
    ///
    /// They stack from the top and the slack falls out of the bottom (the brief's point 4:
    /// centring the whole body would move the MEANING label to a different y on every
    /// card, which is exactly the jitter Phase 4i removed). `minHeight` with a top
    /// alignment does that on its own — and it must be `minHeight` alone, with no
    /// `Spacer` under the blocks: a spacer makes the stack infinitely flexible, the card's
    /// own VStack then hands it every spare point of the page, and the card grows from
    /// 607 pt to the full page height, which is precisely the stretch Phase 4i removed.
    /// `minHeight` rather than a fixed `height` so Dynamic Type still grows it (4d).
    private var bodySlot: some View {
        VStack(alignment: .leading, spacing: 0) {
            quote
            if plan.meaningLines > 0 {
                meaning
            }
            if plan.showsDidYouKnow {
                didYouKnow
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: DiscoverCardLayout.bodyBudget,
            alignment: .topLeading
        )
        .padding(.top, DiscoverMetrics.titleToQuote)
    }

    /// The whole passage, at the size and line count the plan worked out. `lineLimit` is
    /// the plan's own count, so it elides only on the handful of units that cannot fit
    /// even at 14 pt with MEANING and DID YOU KNOW gone.
    private var quote: some View {
        let plan = plan
        return VerseText(
            arabic: nil,
            segments: presentation.segments,
            size: .discover,
            style: .italic,
            quoted: true,
            lineLimit: plan.quoteLines,
            englishSize: plan.quoteSize
        )
        .frame(
            maxWidth: .infinity,
            minHeight: DiscoverCardLayout.slot(lines: plan.quoteLines, size: plan.quoteSize)
        )
        .accessibilityIdentifier("discover.quote")
    }

    /// MEANING, in however many lines the plan left it — four when the quote is short,
    /// down to two, and omitted entirely on the handful of units whose passage needs the
    /// whole body. The section is always complete in Deep Study.
    private var meaning: some View {
        VStack(alignment: .leading, spacing: DiscoverMetrics.labelToBody) {
            CapsLabel(text: StudySection.meaning.displayTitle, size: DeepStudyMetrics.labelSize)
                .lineLimit(1)
                .frame(minHeight: DiscoverCardLayout.capsLabelHeight, alignment: .leading)
            Text(study?.meaning ?? "")
                .font(.serifBody(DiscoverMetrics.bodySize))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(plan.meaningLines)
                .multilineTextAlignment(.leading)
                .frame(
                    maxWidth: .infinity,
                    minHeight: DiscoverCardLayout.slot(
                        lines: plan.meaningLines,
                        size: DiscoverMetrics.bodySize
                    ),
                    alignment: .topLeading
                )
        }
        .padding(.top, DiscoverMetrics.quoteToMeaning)
        .accessibilityIdentifier("discover.meaning")
    }

    /// The DID YOU KNOW box, on the card only while the quote and MEANING leave room for
    /// its three lines. Dropping it is the first thing a long passage costs.
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
