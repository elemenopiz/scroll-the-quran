import Commerce
import DesignSystem
import SwiftUI

/// `paywall-plans`: the half sheet that slides up over a dimmed `PaywallTrialView`.
///
/// It is drawn rather than presented with `.sheet` so the snapshot route renders it
/// synchronously (no presentation animation to wait on) and so the 7 pt side inset and
/// the badge that overhangs the selected card can be positioned exactly.
struct PlansSheet: View {
    let plans: [StorePlan]
    @Binding var selection: ProductID
    let introEligible: Bool
    var onRedeem: () -> Void
    var onDismiss: () -> Void
    /// Where the flow wants VoiceOver's cursor when this sheet comes up (audit A11Y-3).
    /// The sheet has no title of its own, so the first plan card is the landing point —
    /// it is what the customer is here to choose between.
    var focus: AccessibilityFocusState<PaywallStage?>.Binding
    /// What the last purchase attempt left to say (audit IAP-1). `nil` on every capture.
    var notice: PaywallNotice?
    var isBusy = false
    var onDismissNotice: () -> Void = {}

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ReferenceCanvas {
            ZStack(alignment: .top) {
                Color.black.opacity(PaywallMetrics.sheetDim)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityIdentifier("paywall.plans.scrim")
                    .accessibilityLabel("Dismiss plans")
                    .accessibilityAddTraits(.isButton)

                // Over the dim rather than inside the sheet: the sheet's own 340 pt is
                // spoken for down to the last 32 pt, and a message that lands on the home
                // indicator is a message nobody reads.
                if let notice {
                    PaywallNoticeView(notice: notice, onDismiss: onDismissNotice)
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, PaywallMetrics.sheetNoticeTop)
                }

                sheet
                    .padding(.top, PaywallMetrics.sheetTop)
                    .offset(y: max(0, dragOffset))
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation.height }
                            .onEnded { value in
                                if value.translation.height > 80 {
                                    onDismiss()
                                }
                                dragOffset = 0
                            }
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.paywall-plans")
    }

    private var sheet: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: PaywallMetrics.sheetCornerRadius,
                topTrailingRadius: PaywallMetrics.sheetCornerRadius
            )
            .fill(Color.appBackgroundFlat)
            .padding(.horizontal, PaywallMetrics.sheetInset)

            planCards
                .padding(.top, PaywallMetrics.cardTop - PaywallMetrics.sheetTop)

            HStack(spacing: 7) {
                Image(systemName: "checkmark")
                    .font(.system(size: PaywallMetrics.noPaymentSize, weight: .bold))
                Text(PaywallCopy.noPaymentDueNow)
                    .font(.geoBold(PaywallMetrics.noPaymentSize))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.top, PaywallMetrics.sheetNoPaymentTop - PaywallMetrics.sheetTop)
            .accessibilityElement(children: .combine)

            PillButton(
                title: redeemTitle,
                height: PaywallMetrics.ctaHeight,
                isBusy: isBusy,
                action: onRedeem
            )
            .padding(.horizontal, PaywallMetrics.cardInset)
            .padding(.top, PaywallMetrics.sheetCTATop - PaywallMetrics.sheetTop)
            .accessibilityIdentifier("paywall.plans.redeem")

            Text(PaywallCopy.cancelAnytime)
                .font(.geoRegular(PaywallMetrics.cancelAnytimeSize))
                .foregroundStyle(Color.textSecondary)
                .padding(.top, PaywallMetrics.sheetCancelTop - PaywallMetrics.sheetTop)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: PaywallMetrics.referenceHeight - PaywallMetrics.sheetTop, alignment: .top)
    }

    private var planCards: some View {
        VStack(spacing: PaywallMetrics.cardSpacing) {
            ForEach(Array(orderedPlans.enumerated()), id: \.element.id) { index, plan in
                Button {
                    selection = plan.id
                } label: {
                    PlanCard(
                        plan: plan,
                        title: title(for: plan),
                        isSelected: plan.id == selection,
                        showsBadge: plan.id == .yearly
                    )
                }
                .buttonStyle(.plain)
                .accessibilityFocused(focus, equals: index == 0 ? .plans : nil)
            }
        }
        .padding(.horizontal, PaywallMetrics.cardInset)
    }

    /// Yearly first, then monthly. The gift plan never appears on this sheet.
    private var orderedPlans: [StorePlan] {
        let wanted: [ProductID] = [.yearly, .monthly]
        return wanted.compactMap { id in plans.first { $0.id == id } }
    }

    private func title(for plan: StorePlan) -> String {
        switch plan.id {
        case .yearly:
            if let intro = plan.introOffer, introEligible {
                return "\(intro.freeDays)-Days Full Access"
            }
            return "Yearly plan"
        case .monthly:
            return PaywallCopy.monthlyPlanTitle
        case .yearlyGift:
            return plan.displayName
        }
    }

    private var redeemTitle: String {
        guard let plan = plans.first(where: { $0.id == selection }) else { return "Continue" }
        return introEligible ? PlanPricing.redeemTitle(plan) : "Continue"
    }
}

// MARK: - Card

private struct PlanCard: View {
    let plan: StorePlan
    let title: String
    let isSelected: Bool
    let showsBadge: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.geoBold(PaywallMetrics.planTitleSize))
                    .foregroundStyle(Color.textPrimary)
                priceLine
            }
            Spacer(minLength: 0)
            Text(PlanPricing.weeklyLine(plan))
                .font(.geoRegular(PaywallMetrics.planWeeklySize))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(height: PaywallMetrics.cardHeight)
        .background(isSelected ? Color.rowBackground : Color.appBackgroundFlat, in: shape)
        .overlay {
            shape.strokeBorder(
                isSelected ? Color.pillFill : Color.divider,
                lineWidth: isSelected ? Stroke.outline : Stroke.hairline
            )
        }
        .overlay(alignment: .top) {
            if showsBadge {
                Text(PlanPricing.saveBadge(plan))
                    .font(.geoBold(PaywallMetrics.badgeTextSize))
                    .foregroundStyle(Color.textOnPill)
                    .frame(width: PaywallMetrics.badgeSize.width, height: PaywallMetrics.badgeSize.height)
                    .background(Color.pillFill, in: RoundedRectangle(cornerRadius: 5))
                    .offset(y: PaywallMetrics.badgeOverlap - PaywallMetrics.badgeSize.height)
                    .accessibilityIdentifier("paywall.plans.saveBadge")
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plans.card.\(plan.id.rawValue)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius)
    }

    @ViewBuilder
    private var priceLine: some View {
        if plan.introOffer != nil {
            HStack(spacing: 5) {
                Text(PlanPricing.compareLine(plan))
                    .strikethrough()
                    .foregroundStyle(Color.textTertiary)
                Text(PlanPricing.periodLine(plan))
                    .foregroundStyle(Color.textPrimary)
            }
            .font(.geoRegular(PaywallMetrics.planPriceSize))
        } else {
            Text(PlanPricing.periodLine(plan))
                .font(.geoRegular(PaywallMetrics.planPriceSize))
                .foregroundStyle(Color.textPrimary)
        }
    }
}
