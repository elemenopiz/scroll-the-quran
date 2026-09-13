import DesignSystem
import StudyContent
import SwiftUI

/// One REFLECTION card of the Discover feed (Phase 4o).
///
/// **The same frame as a study card.** `Radius.cardLarge`, `Color.cardBackground`,
/// `DiscoverMetrics.cardPadding`, and exactly `DiscoverCardLayout.cardHeight` tall, in the
/// same slot on the page — so the pager lands on a reflection the way it lands on every
/// other card and the previous card's action row peeks above it identically.
///
/// **A different inside.** A quote mark in a disc, the REFLECTION label, the saying and who
/// said it, centred as one group on the card's centre line. The group is centred rather
/// than stacked from the top because the card is a single utterance, not a set of sections:
/// there is no row here whose y has to match the next card's.
///
/// **No action row, no Deep Study, no Arabic.** The original shows none of the four action
/// icons on a reflection, and there is nothing behind one to save, note, share or mark
/// read; the saying is not an ayah, so rule 5's muted Arabic layer — which is *the ayah's*
/// Uthmani text — has nothing to show. `Reflection.arabic` is a single term kept for the
/// sheet surfaces, not a line of scripture, and it is deliberately not drawn here.
///
/// **Never truncated.** `ReflectionCardLayout.quote(for:width:)` steps 26 → 24 → 22 pt to
/// keep the saying inside six lines and, failing that, lets it take a seventh at 22 pt.
/// There is no `lineLimit` anywhere on this card.
@MainActor
struct ReflectionCard: View {
    let reflection: Reflection
    /// The width the saying is laid out in, from the page's own geometry rather than an
    /// assumed 402 pt canvas — the same measurement the study card takes.
    let quoteWidth: CGFloat

    private var plan: ReflectionCardLayout.QuotePlan {
        ReflectionCardLayout.quote(for: reflection.text, width: quoteWidth)
    }

    var body: some View {
        CardContainer(
            radius: Radius.cardLarge,
            padding: DiscoverMetrics.cardPadding,
            background: .cardBackground
        ) {
            VStack(spacing: 0) {
                mark
                label
                quote
                attribution
            }
            // `minHeight` with a centre alignment, and deliberately **no** `Spacer`: a
            // spacer would make the stack infinitely flexible, the page's own
            // `maxHeight: .infinity` would hand it every spare point, and the card would
            // grow from 607 pt to the whole page — the stretch Phase 4i removed.
            // `minHeight` rather than `height` so Dynamic Type can still grow it.
            .frame(
                maxWidth: .infinity,
                minHeight: ReflectionCardLayout.contentHeight,
                alignment: .center
            )
        }
        .shadow(color: .black.opacity(0.45), radius: 22, y: 6)
        // As on the study card: a container element, so the identifier does not propagate
        // down and overwrite the ones its children set.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discover.reflection")
    }

    // MARK: - Slots

    /// The disc and its open quote. Decorative in full: the saying below carries the
    /// meaning, so VoiceOver is given the REFLECTION label and the text, not a glyph.
    private var mark: some View {
        ZStack {
            Circle()
                .fill(Color.chipBackground)
            Text(verbatim: "\u{201C}")
                .font(.serifDisplay(ReflectionMetrics.markGlyphSize))
                .foregroundStyle(Color.textSecondary)
                .offset(y: ReflectionCardLayout.markGlyphOffset())
        }
        .frame(width: ReflectionMetrics.markDiameter, height: ReflectionMetrics.markDiameter)
        .accessibilityHidden(true)
        .accessibilityIdentifier("discover.reflection.mark")
    }

    private var label: some View {
        // Spelled in capitals like every other section label in the app
        // (`StudySection.displayTitle`), not lowercase plus `.textCase`: the caps string is
        // what the accessibility label carries, and what a UI test looks for.
        CapsLabel(text: "REFLECTION", size: DeepStudyMetrics.labelSize)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: DiscoverCardLayout.capsLabelHeight)
            .padding(.top, ReflectionMetrics.markToLabel)
            .accessibilityIdentifier("discover.reflection.label")
    }

    /// The saying, centred, at the size and line count the plan worked out. No
    /// `lineLimit`: a reflection is never elided.
    private var quote: some View {
        let plan = plan
        return Text(reflection.text)
            .font(.serifDisplay(plan.size))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: plan.height)
            // The card already carries `cardPadding`; this is the rest of the 40 pt the
            // saying is inset from the card's edge.
            .padding(.horizontal, ReflectionMetrics.quoteInset - DiscoverMetrics.cardPadding)
            .padding(.top, ReflectionMetrics.labelToQuote)
            .accessibilityIdentifier("discover.reflection.quote")
    }

    /// "— Rumi". An em dash, a space, then exactly what the catalogue records: an
    /// attribution is a claim about who said something and is never reworded here.
    private var attribution: some View {
        Text(verbatim: "\u{2014} \(reflection.attribution)")
            .font(.body(ReflectionMetrics.attributionSize, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(ReflectionMetrics.attributionMinimumScale)
            .frame(maxWidth: .infinity, minHeight: ReflectionCardLayout.attributionHeight)
            .padding(.top, ReflectionMetrics.quoteToAttribution)
            .accessibilityIdentifier("discover.reflection.attribution")
    }
}
