import Commerce
import DesignSystem
import SwiftUI

/// `gift-closed` and `gift-open`: the one-time offer shown once, after the paywall has
/// been dismissed without a purchase. Tapping anywhere on the sealed envelope opens it.
public struct GiftOfferView: View {
    private let plan: StorePlan?
    private let standardPlan: StorePlan?
    private let introEligible: Bool
    private let onDismiss: () -> Void
    private let onPurchase: () -> Void
    private let onRestore: () -> Void
    private let links: PaywallLegalLinks
    private let notice: PaywallNotice?
    private let isBusy: Bool
    private let onDismissNotice: () -> Void

    @State private var isOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    public init(
        plan: StorePlan?,
        standardPlan: StorePlan?,
        introEligible: Bool = true,
        isOpen: Bool = false,
        onDismiss: @escaping () -> Void,
        onPurchase: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        links: PaywallLegalLinks = .default,
        notice: PaywallNotice? = nil,
        isBusy: Bool = false,
        onDismissNotice: @escaping () -> Void = {}
    ) {
        self.plan = plan
        self.standardPlan = standardPlan
        self.introEligible = introEligible
        _isOpen = State(initialValue: isOpen)
        self.onDismiss = onDismiss
        self.onPurchase = onPurchase
        self.onRestore = onRestore
        self.links = links
        self.notice = notice
        self.isBusy = isBusy
        self.onDismissNotice = onDismissNotice
    }

    public var body: some View {
        ReferenceCanvas {
            ZStack(alignment: .top) {
                CloudBackground()
                if isOpen {
                    openState
                } else {
                    closedState
                }
                noticeBanner
            }
        }
        .animation(revealAnimation, value: isOpen)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isOpen ? "screen.gift-open" : "screen.gift-closed")
    }

    /// Opening the envelope is a large motion; Reduce Motion gets a cross-fade instead.
    private var revealAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.78)
    }

    // MARK: - Closed

    private var closedEnvelopeArt: CGRect {
        PaywallMetrics.closedEnvelopeArt()
    }

    private var closedState: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isOpen = true }
                .accessibilityIdentifier("gift.reveal")
                .accessibilityLabel(PaywallCopy.giftReveal)
                .accessibilityAddTraits(.isButton)

            // The artwork's canvas carries margin around the paper, so the frame is the
            // canvas rect that lands the paper on the reference's envelope.
            SealedEnvelope()
                .frame(width: closedEnvelopeArt.width, height: closedEnvelopeArt.height)
                .rotationEffect(.degrees(PaywallMetrics.closedEnvelopeRotation))
                .offset(
                    x: closedEnvelopeArt.midX - PaywallMetrics.referenceWidth / 2,
                    y: closedEnvelopeArt.minY
                )
                .allowsHitTesting(false)

            lines(
                PaywallCopy.giftHeadline,
                font: .geoBold(PaywallMetrics.giftHeadlineSize),
                color: GiftPalette.ink,
                spacing: PaywallMetrics.giftHeadlineLineSpacing
            )
            .padding(.top, PaywallMetrics.giftHeadlineTopClosed)
            .accessibilityIdentifier("gift.headline")
            .allowsHitTesting(false)

            lines(
                PaywallCopy.giftSubtitle,
                font: .geoRegular(PaywallMetrics.giftSubtitleSize),
                color: GiftPalette.inkMuted,
                spacing: PaywallMetrics.giftSubtitleLineSpacing
            )
            .padding(.top, PaywallMetrics.giftSubtitleTop)
            .allowsHitTesting(false)

            HStack(spacing: Spacing.sm) {
                Text(PaywallCopy.giftReveal)
                Image(systemName: "chevron.right")
                    .font(.system(size: PaywallMetrics.giftRevealSize * 0.78, weight: .medium))
            }
            .font(.geoBold(PaywallMetrics.giftRevealSize))
            .foregroundStyle(GiftPalette.ink)
            .padding(.top, PaywallMetrics.giftRevealTop)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Open

    private var openState: some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(GiftPalette.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("gift.close")
                .accessibilityLabel("Close")
                Spacer(minLength: 0)
            }
            .padding(.leading, 5)
            .padding(.top, PaywallMetrics.giftCloseTop)
            .zIndex(1)

            OpenedEnvelope { offerCard }

            Text(PaywallCopy.luckyYou)
                .font(.geoBold(PaywallMetrics.luckySize))
                .foregroundStyle(GiftPalette.ink)
                .padding(.top, PaywallMetrics.luckyTop)
                .accessibilityIdentifier("gift.lucky")

            HStack(spacing: Spacing.lg) {
                Text(standardPriceText)
                    .font(.geoBold(PaywallMetrics.strikePriceSize))
                    .foregroundStyle(GiftPalette.inkMuted)
                    .strikethrough(true, color: GiftPalette.inkMuted)
                Text(offerPriceText)
                    .font(.geoBold(PaywallMetrics.strikePriceSize))
                    .foregroundStyle(GiftPalette.pillLabel)
                    .frame(
                        width: PaywallMetrics.offerPillSize.width,
                        height: PaywallMetrics.offerPillSize.height
                    )
                    .background(GiftPalette.pillFill, in: Capsule())
            }
            .padding(.top, PaywallMetrics.priceRowTop)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("gift.price")

            PillButton(
                title: introEligible ? PaywallCopy.startFreeTrial : PaywallCopy.continueTitle,
                height: PaywallMetrics.giftCTAHeight,
                fontSize: 19,
                fill: GiftPalette.pillFill,
                label: GiftPalette.pillLabel,
                isBusy: isBusy,
                action: onPurchase
            )
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, PaywallMetrics.giftCTATop)
            .accessibilityIdentifier("gift.startTrial")

            Text(footnote)
                .font(.geoRegular(PaywallMetrics.footnoteSize))
                .foregroundStyle(GiftPalette.inkLegible)
                .padding(.top, PaywallMetrics.footnoteTop)
                .accessibilityIdentifier("gift.footnote")

            legalRow
                .padding(.top, PaywallMetrics.giftLegalTop)
        }
    }

    /// Terms of Use, Privacy Policy and Restore Purchases (audit IAP-2).
    ///
    /// The gift offer is an independent purchase surface for a real auto-renewing
    /// subscription: a customer who dismisses the paywall lands here and never sees the
    /// trial screen's footer again, so guideline 3.1.2(a)'s live links have to be on this
    /// screen too. The reference has nothing in this band — its gift screen has no legal
    /// affordances at all — which is the accepted deviation recorded in `Reference/scores.md`.
    private var legalRow: some View {
        HStack(spacing: 5) {
            ForEach(Array(PaywallCopy.giftLegal.enumerated()), id: \.element) { index, link in
                if index > 0 {
                    Text("|").foregroundStyle(GiftPalette.inkLegible)
                }
                Button(link.title) { open(link) }
                    .foregroundStyle(GiftPalette.inkLegible)
                    .accessibilityIdentifier("gift.legal.\(link.slug)")
            }
        }
        .font(.geoRegular(PaywallMetrics.giftLegalSize))
        .lineLimit(1)
        .fixedSize()
    }

    /// Terms and Privacy open in the browser; Restore Purchases goes back to the App Store.
    private func open(_ link: PaywallCopy.LegalLink) {
        switch link {
        case .terms: openURL(links.terms)
        case .privacy: openURL(links.privacy)
        case .alreadySubscribed, .restore: onRestore()
        }
    }

    /// Under the close control and over the envelope's raised flap: the only band on this
    /// composition that is not price, call to action or disclosure. Drawn only when there
    /// is something to say, so neither gift capture sees it.
    @ViewBuilder
    private var noticeBanner: some View {
        if let notice {
            PaywallNoticeView(
                notice: notice,
                ink: GiftPalette.ink,
                mutedInk: GiftPalette.inkLegible,
                paper: GiftPalette.offerCard,
                edge: GiftPalette.envelopeShade,
                onDismiss: onDismissNotice
            )
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, PaywallMetrics.giftNoticeTop)
        }
    }

    /// The copy on the card that stands out of the envelope: "One Time Offer / 33% OFF /
    /// +3 day trial". The paper under it is `GiftArt.card`, drawn by `OpenedEnvelope`,
    /// which also clips both at the pocket's mouth.
    private var offerCard: some View {
        let cardTop = PaywallMetrics.openEnvelopeGeometry.card.minY
        return ZStack(alignment: .top) {
            Color.clear

            Text(PaywallCopy.oneTimeOffer)
                .font(.geoRegular(PaywallMetrics.oneTimeOfferSize))
                .foregroundStyle(GiftPalette.inkMuted)
                .padding(.top, PaywallMetrics.oneTimeOfferTop - cardTop)

            Text("\(discountPercent)%")
                .font(.geoBold(PaywallMetrics.percentSize))
                .foregroundStyle(GiftPalette.ink)
                .padding(.top, PaywallMetrics.percentTop - cardTop)

            // The pill tucks under the digits' baseline with a white outline, exactly as the
            // reference does — the outline is what separates it from the "33%" above it.
            Text(PaywallCopy.off)
                .font(.geoBold(PaywallMetrics.oneTimeOfferSize))
                .foregroundStyle(GiftPalette.offPillLabel)
                .frame(
                    width: PaywallMetrics.offPillSize.width,
                    height: PaywallMetrics.offPillSize.height
                )
                .background(GiftPalette.offPillFill, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(GiftPalette.offPillOutline, lineWidth: PaywallMetrics.offPillOutline)
                        .padding(-PaywallMetrics.offPillOutline / 2)
                }
                .padding(.top, PaywallMetrics.offPillTop - cardTop)

            if let trialPillTitle {
                Text(trialPillTitle)
                    .font(.geoBold(PaywallMetrics.oneTimeOfferSize - 3))
                    .foregroundStyle(GiftPalette.ink)
                    .frame(
                        width: PaywallMetrics.trialPillSize.width,
                        height: PaywallMetrics.trialPillSize.height
                    )
                    .background(GiftPalette.softPillFill, in: Capsule())
                    .padding(.top, PaywallMetrics.trialPillTop - cardTop)
            }

            Text(PaywallCopy.neverAgain)
                .font(.geoRegular(PaywallMetrics.neverAgainSize))
                .foregroundStyle(GiftPalette.inkMuted)
                .padding(.top, PaywallMetrics.neverAgainTop - cardTop)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gift.offerCard")
    }

    // MARK: - Copy

    private func lines(_ strings: [String], font: Font, color: Color, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(strings, id: \.self) { line in
                Text(line)
                    .font(font)
                    .foregroundStyle(color)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var offerPlan: StorePlan {
        plan ?? StoreCatalogue.gift
    }

    private var standard: StorePlan {
        standardPlan ?? StoreCatalogue.yearly
    }

    private var discountPercent: Int {
        PlanPricing.discountPercent(standard: standard, offer: offerPlan)
    }

    private var standardPriceText: String {
        standard.displayPrice
    }

    private var offerPriceText: String {
        offerPlan.displayPrice
    }

    /// `nil` once the customer has used this subscription group's introductory offer:
    /// StoreKit would charge them immediately, so the screen must not promise a trial.
    private var trialPillTitle: String? {
        guard introEligible, let days = offerPlan.introOffer?.freeDays else { return nil }
        return "+\(days) day trial"
    }

    private var footnote: String {
        let terms = introEligible
            ? PlanPricing.trialFootnote(offerPlan)
            : PlanPricing.periodLine(offerPlan)
        return "\(terms)  •  \(PaywallCopy.autoRenewNote)"
    }
}

#Preview("Gift closed") {
    GiftOfferView(plan: StoreCatalogue.gift, standardPlan: StoreCatalogue.yearly, onDismiss: {}, onPurchase: {})
}

#Preview("Gift open") {
    GiftOfferView(
        plan: StoreCatalogue.gift,
        standardPlan: StoreCatalogue.yearly,
        isOpen: true,
        onDismiss: {},
        onPurchase: {}
    )
}
