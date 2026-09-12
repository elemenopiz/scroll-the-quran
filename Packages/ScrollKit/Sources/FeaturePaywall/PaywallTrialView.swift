import Commerce
import DesignSystem
import SwiftUI

/// `paywall-trial`: the brand mark, the "How your free trial works" headline, the three-step
/// timeline, the live price and the redeem call to action.
///
/// Laid out inside a `ReferenceCanvas`, so every `PaywallMetrics` value is the y measured
/// off `Reference/paywall-trial.png` with no device-size arithmetic in the view body.
struct PaywallTrialView: View {
    let plan: StorePlan?
    let introEligible: Bool
    var onClose: () -> Void
    var onRedeem: () -> Void
    var onViewAllPlans: () -> Void
    var onRestore: () -> Void
    var links: PaywallLegalLinks = .default

    @Environment(\.openURL) private var openURL

    /// The mark is the one element that cannot live at its reference y: on a Dynamic Island
    /// device y = 47 is behind the island. The outer reader hands `PaywallMetrics` the real
    /// safe-area inset so the mark can be dropped below it, in canvas points.
    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let screen = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            ReferenceCanvas {
                ZStack(alignment: .top) {
                    Color.appBackgroundFlat

                    BrandMark()
                        .frame(
                            width: PaywallMetrics.logoSize.width,
                            height: PaywallMetrics.logoSize.height
                        )
                        .padding(.top, PaywallMetrics.logoTop(safeAreaTop: insets.top, screen: screen))

                    closeButton
                    headline.padding(.top, PaywallMetrics.headlineTop)
                    timelineConnector
                    timeline.padding(.top, PaywallMetrics.timelineTop)
                    footer
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.paywall-trial")
    }

    // MARK: - Header

    private var closeButton: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: PaywallMetrics.closeSize, weight: .light))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("paywall.close")
            .accessibilityLabel("Close")
            Spacer(minLength: 0)
        }
        .padding(.leading, PaywallMetrics.closeLeading - 22)
        .padding(.top, PaywallMetrics.closeCenterY - 22)
    }

    private var headline: some View {
        VStack(spacing: PaywallMetrics.headlineLineSpacing) {
            ForEach(PaywallCopy.headline, id: \.self) { line in
                Text(line)
                    .font(.geoBold(PaywallMetrics.headlineSize))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.headline")
    }

    /// The hairline that threads the three discs together, drawn behind them.
    private var timelineConnector: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.divider)
                .frame(
                    width: PaywallMetrics.timelineConnector,
                    height: PaywallMetrics.timelineConnectorHeight
                )
            Spacer(minLength: 0)
        }
        .padding(.leading, Spacing.pageMargin + PaywallMetrics.timelineDisc / 2 - PaywallMetrics.timelineConnector / 2)
        .padding(.top, PaywallMetrics.timelineTop + PaywallMetrics.timelineDisc / 2)
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: PaywallMetrics.timelineRowSpacing) {
            ForEach(PaywallCopy.timeline) { step in
                TimelineRow(step: step)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Footer

    private var footer: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark")
                    .font(.system(size: PaywallMetrics.noPaymentSize, weight: .bold))
                Text(PaywallCopy.noPaymentDueNow)
                    .font(.geoBold(PaywallMetrics.noPaymentSize))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.top, PaywallMetrics.noPaymentTop)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paywall.noPaymentDueNow")

            Text(priceLine)
                .font(.geoBold(PaywallMetrics.priceSize))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, PaywallMetrics.priceTop)
                .accessibilityIdentifier("paywall.price")

            if let note = monthlyNote {
                Text(note)
                    .font(.geoRegular(PaywallMetrics.priceNoteSize))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, PaywallMetrics.priceNoteTop)
                    .accessibilityIdentifier("paywall.priceNote")
            }

            PillButton(title: redeemTitle, height: PaywallMetrics.ctaHeight, action: onRedeem)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, PaywallMetrics.ctaTop)
                .accessibilityIdentifier("paywall.redeem")

            Button(action: onViewAllPlans) {
                Text(PaywallCopy.viewAllPlans)
                    .font(.geoBold(PaywallMetrics.viewAllPlansSize))
                    .foregroundStyle(Color.textPrimary)
                    .underline()
            }
            .padding(.top, PaywallMetrics.viewAllTop)
            .accessibilityIdentifier("paywall.viewAllPlans")

            legalRow
                .padding(.top, PaywallMetrics.legalTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var legalRow: some View {
        HStack(spacing: 5) {
            ForEach(Array(PaywallCopy.LegalLink.allCases.enumerated()), id: \.element) { index, link in
                if index > 0 {
                    Text("|").foregroundStyle(Color.textTertiary)
                }
                Button(link.title) { open(link) }
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("paywall.legal.\(index)")
            }
        }
        .font(.geoRegular(PaywallMetrics.legalSize))
        .lineLimit(1)
        .fixedSize()
    }

    /// Terms and Privacy open in the browser; the other two both mean "I already paid".
    private func open(_ link: PaywallCopy.LegalLink) {
        switch link {
        case .terms: openURL(links.terms)
        case .privacy: openURL(links.privacy)
        case .alreadySubscribed, .restore: onRestore()
        }
    }

    // MARK: - Copy from the store

    private var priceLine: String {
        plan.map(PlanPricing.periodLine) ?? PlanPricing.periodLine(StoreCatalogue.yearly)
    }

    private var monthlyNote: String? {
        PlanPricing.monthlyEquivalent(plan ?? StoreCatalogue.yearly)
    }

    private var redeemTitle: String {
        let plan = plan ?? StoreCatalogue.yearly
        return introEligible ? PlanPricing.redeemTitle(plan) : "Continue"
    }
}

// MARK: - Timeline row

private struct TimelineRow: View {
    let step: PaywallCopy.TimelineStep

    var body: some View {
        HStack(alignment: .top, spacing: PaywallMetrics.timelineGap) {
            Circle()
                .fill(Color.pillFill)
                .frame(width: PaywallMetrics.timelineDisc, height: PaywallMetrics.timelineDisc)
                .overlay {
                    Image(systemName: step.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textOnPill)
                }

            VStack(alignment: .leading, spacing: PaywallMetrics.timelineTitleGap) {
                Text(step.title)
                    .font(.geoBold(PaywallMetrics.timelineTitleSize))
                    .foregroundStyle(Color.textPrimary)
                Text(step.body)
                    .font(.geoRegular(PaywallMetrics.timelineBodySize))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(PaywallMetrics.timelineBodyLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, PaywallMetrics.timelineTextTop)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.step.\(step.id)")
    }
}

// MARK: - Shared pill button

struct PillButton: View {
    let title: String
    var height: CGFloat = PaywallMetrics.ctaHeight
    var fontSize: CGFloat = PaywallMetrics.ctaLabelSize
    /// The paywall follows the appearance; the gift screens are a fixed warm-paper
    /// composition and pass their own pair, so the call to action does not turn white
    /// on cream when the system is in dark mode.
    var fill: Color = .pillFill
    var label: Color = .textOnPill
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geoBold(fontSize))
                .foregroundStyle(label)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
