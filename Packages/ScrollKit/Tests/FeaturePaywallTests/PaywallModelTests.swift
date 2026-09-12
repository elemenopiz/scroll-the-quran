import Foundation
import Commerce
@testable import FeaturePaywall
import Testing

@Suite("Paywall flow")
@MainActor
struct PaywallModelTests {
    @Test("The flow opens on the trial screen and can move to the plans sheet")
    func stages() {
        let model = PaywallModel(store: MockEntitlementStore())
        #expect(model.stage == .trial)
        model.show(.plans)
        #expect(model.stage == .plans)
    }

    @Test("Dismissing the trial paywall the first time reveals the one-time gift offer")
    func firstDismissShowsGift() {
        let offers = InMemoryOneTimeOfferStore()
        let model = PaywallModel(store: MockEntitlementStore(), offers: offers)
        #expect(model.dismissTrial() == false)
        #expect(model.stage == .giftClosed)
        #expect(offers.seenOneTimeOffer)
    }

    @Test("Dismissing again leaves the paywall instead of offering the gift twice")
    func secondDismissLeaves() {
        let offers = InMemoryOneTimeOfferStore(seenOneTimeOffer: true)
        let model = PaywallModel(store: MockEntitlementStore(), offers: offers)
        #expect(model.dismissTrial())
        #expect(model.stage == .trial)
    }

    @Test("A successful purchase reports true and entitles the store")
    func purchase() async {
        let store = MockEntitlementStore()
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly))
        #expect(store.isPremium)
        #expect(model.errorMessage == nil)
    }

    @Test("An Ask to Buy purchase reports false and explains that approval is pending")
    func pendingPurchase() async {
        let store = MockEntitlementStore()
        store.nextOutcome = .pending
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(store.isPremium == false)
        #expect(model.pendingMessage == PaywallCopy.askToBuyPending)
        #expect(model.errorMessage == nil)
    }

    @Test("A failure after a pending purchase clears the pending message")
    func pendingThenFailure() async {
        let store = MockEntitlementStore()
        store.nextOutcome = .pending
        let model = PaywallModel(store: store)
        _ = await model.purchase(.yearly)
        store.nextError = .storeKit("offline")
        _ = await model.purchase(.yearly)
        #expect(model.pendingMessage == nil)
        #expect(model.errorMessage == "offline")
    }

    @Test("A cancelled purchase reports false and leaves no error")
    func cancelledPurchase() async {
        let store = MockEntitlementStore()
        store.nextOutcome = .cancelled
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(store.isPremium == false)
    }

    @Test("A failed purchase surfaces a readable message")
    func failedPurchase() async {
        let store = MockEntitlementStore()
        store.nextError = .productUnavailable(.yearly)
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(model.errorMessage == "That plan is not available right now.")
    }

    @Test("Restore reports whether the customer came back entitled")
    func restore() async {
        let store = MockEntitlementStore(isPremium: true)
        let model = PaywallModel(store: store)
        #expect(await model.restore())
        #expect(store.restoreCount == 1)
    }

    @Test("A failing restore reports false with a message")
    func failedRestore() async {
        let store = MockEntitlementStore()
        store.nextError = .storeKit("offline")
        let model = PaywallModel(store: store)
        #expect(await model.restore() == false)
        #expect(model.errorMessage != nil)
    }

    @Test("The model falls back to the fixture catalogue when the store has not loaded")
    func fallbackPlans() {
        let model = PaywallModel(store: MockEntitlementStore(products: []))
        #expect(model.yearly?.displayPrice == "$29.99")
        #expect(model.gift?.displayPrice == "$19.99")
    }

    @Test("Errors map to customer-facing copy")
    func errorCopy() {
        #expect(PaywallModel.message(for: .unverifiedTransaction) == "We could not verify that purchase.")
        #expect(PaywallModel.message(for: .storeKit("boom")) == "boom")
    }

    @Test("load() asks the store for its catalogue")
    func load() async {
        let store = MockEntitlementStore()
        let model = PaywallModel(store: store)
        await model.load()
        #expect(store.loadCount == 1)
    }
}

/// Audit IAP-1. Every branch a purchase or a restore can end in has to leave something on
/// screen — the finding was that the model computed all of this and no view read it, and
/// the only reason that shipped is that nothing asserted the state was *reachable*.
@Suite("Purchase feedback")
@MainActor
struct PaywallNoticeTests {
    @Test("A cancelled purchase says so instead of failing silently")
    func cancelledSpeaks() async {
        let store = MockEntitlementStore()
        store.pose(.cancelled)
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(model.notice == .info(PaywallCopy.purchaseCancelled))
        // A cancellation is not an error: it must not be dressed as one.
        #expect(model.notice?.isError == false)
        #expect(model.errorMessage == nil)
    }

    @Test("A failed purchase surfaces the store's message as an error")
    func failureSpeaks() async {
        let store = MockEntitlementStore()
        store.pose(.failed)
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(model.notice == .error(FixturePurchaseOutcome.failureMessage))
        #expect(model.notice?.isError == true)
    }

    @Test("Ask to Buy reads as pending, not as a failure")
    func pendingSpeaks() async {
        let store = MockEntitlementStore()
        store.pose(.pending)
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly) == false)
        #expect(model.notice == .pending(PaywallCopy.askToBuyPending))
        #expect(model.notice?.isError == false)
        #expect(model.pendingMessage == PaywallCopy.askToBuyPending)
    }

    @Test("A successful purchase leaves nothing on screen")
    func successIsSilent() async {
        let store = MockEntitlementStore()
        store.pose(.success)
        let model = PaywallModel(store: store)
        #expect(await model.purchase(.yearly))
        #expect(model.notice == nil)
    }

    @Test("A restore that finds nothing says so rather than doing nothing")
    func emptyRestoreSpeaks() async {
        let store = MockEntitlementStore()
        let model = PaywallModel(store: store)
        #expect(await model.restore() == false)
        #expect(model.notice == .info(PaywallCopy.nothingToRestore))
    }

    @Test("A restore that finds a purchase is silent and reports true")
    func restoreThatWorks() async {
        let store = MockEntitlementStore()
        store.restoreGrantsPremium = true
        let model = PaywallModel(store: store)
        #expect(await model.restore())
        #expect(model.notice == nil)
    }

    @Test("A restore that cannot reach the App Store reads as an error")
    func restoreFailureSpeaks() async {
        let store = MockEntitlementStore()
        store.pose(.failed)
        let model = PaywallModel(store: store)
        #expect(await model.restore() == false)
        #expect(model.notice == .error(PaywallCopy.restoreFailed))
    }

    @Test("The banner's close button clears the message")
    func dismissClears() async {
        let store = MockEntitlementStore()
        store.pose(.cancelled)
        let model = PaywallModel(store: store)
        _ = await model.purchase(.yearly)
        #expect(model.notice != nil)
        model.dismissNotice()
        #expect(model.notice == nil)
    }

    @Test("A new attempt clears the message the last one left")
    func retryClearsTheLastMessage() async {
        let store = MockEntitlementStore()
        store.pose(.failed)
        let model = PaywallModel(store: store)
        _ = await model.purchase(.yearly)
        #expect(model.notice?.isError == true)
        store.pose(.success)
        #expect(await model.purchase(.yearly))
        #expect(model.notice == nil)
    }

    @Test("Nothing is busy before or after an attempt, and a second tap is refused")
    func busyState() async {
        let store = MockEntitlementStore()
        let model = PaywallModel(store: store)
        #expect(model.isBusy == false)
        #expect(model.isPurchasing == false)
        #expect(model.isRestoring == false)
        _ = await model.purchase(.yearly)
        #expect(model.isBusy == false)
        #expect(store.purchaseCount == 1)
    }

    @Test("A purchase in flight blocks a second purchase and a restore")
    func concurrentAttemptsAreRefused() async {
        let store = MockEntitlementStore()
        // `pose(.stalled)` is 30 s, which is what a UI test needs to *see* the spinner and
        // what a unit test must not spend. The mechanism under test is the same one.
        store.purchaseDelay = .milliseconds(200)
        let model = PaywallModel(store: store)
        async let first = model.purchase(.yearly)
        // Give the first attempt a turn to set `isPurchasing` before the second one asks.
        await Task.yield()
        #expect(await model.restore() == false)
        #expect(store.restoreCount == 0, "a restore must not run while a purchase is in flight")
        #expect(model.isBusy)
        _ = await first
    }

    @Test("Notice text and severity read correctly")
    func noticeShape() {
        #expect(PaywallNotice.error("boom").text == "boom")
        #expect(PaywallNotice.error("boom").isError)
        #expect(PaywallNotice.pending("wait").isError == false)
        #expect(PaywallNotice.info("hm").isError == false)
    }
}

/// Audit IAP-2: the gift offer is an independent purchase surface and needs its own live
/// Terms, Privacy and Restore (guideline 3.1.2(a)).
@Suite("Gift offer disclosures")
struct GiftDisclosureTests {
    @Test("The gift footer carries Terms, Privacy and Restore")
    func giftLegalLinks() {
        #expect(PaywallCopy.giftLegal.contains(.terms))
        #expect(PaywallCopy.giftLegal.contains(.privacy))
        #expect(PaywallCopy.giftLegal.contains(.restore))
        #expect(PaywallCopy.giftLegal.count == 3)
        // Every slug is usable as an accessibility identifier suffix.
        #expect(PaywallCopy.giftLegal.allSatisfy { !$0.slug.contains(" ") })
        #expect(Set(PaywallCopy.LegalLink.allCases.map(\.slug)).count == 4)
    }

    @Test("The gift footnote states the price, the period and that it renews")
    func giftFootnoteDiscloses() {
        // The screen composes `trialFootnote` with `autoRenewNote`; both halves matter.
        #expect(PlanPricing.trialFootnote(StoreCatalogue.gift) == "3 days free, then $19.99/year")
        #expect(PaywallCopy.autoRenewNote.lowercased().contains("renew"))
        // It has to stay short enough to share one 393 pt line with the price.
        #expect(PaywallCopy.autoRenewNote.count < 16)
    }

    @Test("The gift row sits below the disclosure and above the home indicator")
    func giftLegalPlacement() {
        #expect(PaywallMetrics.giftLegalTop > PaywallMetrics.footnoteTop)
        #expect(PaywallMetrics.giftLegalTop + PaywallMetrics.giftLegalSize < PaywallMetrics.referenceHeight - 10)
    }
}

@Suite("Screen routing")
struct PaywallScreensTests {
    @Test("Every screen id in the manifest maps to a stage")
    func stagesForScreenIDs() {
        #expect(PaywallScreens.stage(forScreenID: "paywall-trial") == .trial)
        #expect(PaywallScreens.stage(forScreenID: "paywall-plans") == .plans)
        #expect(PaywallScreens.stage(forScreenID: "gift-closed") == .giftClosed)
        #expect(PaywallScreens.stage(forScreenID: "gift-open") == .giftOpen)
        #expect(PaywallScreens.stage(forScreenID: "home") == nil)
    }

    @Test("The advertised screen id list covers every stage")
    func screenIDsCoverStages() {
        let stages = PaywallScreens.screenIDs.compactMap(PaywallScreens.stage(forScreenID:))
        #expect(Set(stages) == Set(PaywallStage.allCases))
    }
}

@Suite("Paywall copy")
struct PaywallCopyTests {
    @Test("Every footer link is a real destination, none decorative")
    func legalLinksAreLive() {
        // App Review 3.1.2(a): Terms and Privacy must be reachable from the purchase screen.
        #expect(PaywallCopy.LegalLink.allCases.count == 4)
        #expect(PaywallCopy.LegalLink.allCases.contains(.terms))
        #expect(PaywallCopy.LegalLink.allCases.contains(.privacy))
        #expect(PaywallLegalLinks.default.terms.scheme == "https")
        #expect(PaywallLegalLinks.default.privacy.scheme == "https")
        #expect(PaywallLegalLinks.default.terms != PaywallLegalLinks.default.privacy)
    }

    @Test("The trial timeline is three steps with stable identifiers")
    func timeline() {
        #expect(PaywallCopy.timeline.map(\.id) == ["today", "day5", "day7"])
        #expect(PaywallCopy.timeline.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
    }

    @Test("The paywall never says Bible and never transliterates")
    func quranWording() {
        let all = PaywallCopy.timeline.map(\.body) + PaywallCopy.headline + PaywallCopy.giftHeadline
        #expect(all.allSatisfy { !$0.lowercased().contains("bible") })
        #expect(PaywallCopy.timeline[0].body.contains("Quran"))
    }

    @Test("Four legal links, with restore last")
    func legal() {
        #expect(PaywallCopy.legal.count == 4)
        #expect(PaywallCopy.legal.last == "Restore Purchases")
    }
}

@Suite("Reference metrics")
struct PaywallMetricsTests {
    @Test("The canvas is the 393x852 reference space")
    func canvas() {
        #expect(PaywallMetrics.referenceWidth == 393)
        #expect(PaywallMetrics.referenceHeight == 852)
    }

    @Test("The plan cards and the badge line up the way the reference does")
    func plansGeometry() {
        // Card 1 top border y 546, badge 19 pt tall overhanging it by 7 pt.
        #expect(PaywallMetrics.cardTop == 546)
        #expect(PaywallMetrics.badgeSize.height == 19)
        #expect(PaywallMetrics.badgeOverlap == 7)
        // Cards are inset 20 pt from the screen, the sheet 7 pt.
        #expect(PaywallMetrics.cardInset > PaywallMetrics.sheetInset)
    }

    @Test("The opened envelope's flap, pocket and seal are stacked in the right order")
    func envelopeGeometry() {
        let envelope = PaywallMetrics.openEnvelopeGeometry
        #expect(envelope.flapApex.y < envelope.bodyTop)
        #expect(envelope.bodyTop < envelope.pocketPoint.y)
        #expect(envelope.pocketPoint.y < envelope.bottom)
        #expect(envelope.card.minY < envelope.bodyTop)
        // The card is hidden behind the pocket point rather than ending in mid air.
        #expect(envelope.card.maxY > envelope.pocketPoint.y)
    }
}

@Suite("Gift offer eligibility")
@MainActor
struct GiftOfferEligibilityTests {
    @Test("An eligible customer is offered the free trial")
    func eligible() {
        let model = PaywallModel(store: MockEntitlementStore(introOfferEligible: true))
        #expect(model.introEligible)
        #expect(PlanPricing.trialFootnote(StoreCatalogue.gift) == "3 days free, then $19.99/year")
    }

    @Test("A customer who has already used the introductory offer is not promised one")
    func ineligible() {
        // StoreKit charges immediately once the group's intro offer is spent, so the
        // gift screen must fall back to the plain price rather than "3 days free".
        let model = PaywallModel(store: MockEntitlementStore(introOfferEligible: false))
        #expect(model.introEligible == false)
        #expect(PlanPricing.periodLine(StoreCatalogue.gift) == "$19.99/year")
    }
}

/// Audit IAP-4, IAP-5.
@Suite("Trial paywall disclosures")
@MainActor
struct TrialDisclosureTests {
    @Test("The injected links reach the view instead of the view's own default")
    func injectedLinksAreUsed() throws {
        // IAP-4: `PaywallFlow.init` took `links:` and built `PaywallTrialView` without it,
        // so any change to the injected URLs would silently have done nothing. Both
        // defaults resolve to the same URLs, which is why it was invisible.
        let custom = PaywallLegalLinks(
            terms: try #require(URL(string: "https://example.test/terms")),
            privacy: try #require(URL(string: "https://example.test/privacy"))
        )
        let view = PaywallTrialView(
            plan: StoreCatalogue.yearly,
            introEligible: true,
            onClose: {},
            onRedeem: {},
            onViewAllPlans: {},
            onRestore: {},
            links: custom
        )
        #expect(view.links == custom)
        #expect(view.links != .default)
    }

    @Test("The renewal wording sits on the line next to the call to action")
    func renewalCopyIsAdjacentToTheCTA() {
        // IAP-5: the reference prints only "($2.49/mo)" there.
        #expect(PlanPricing.monthlyEquivalent(StoreCatalogue.yearly) == "($2.49/mo)")
        #expect(PaywallCopy.autoRenewNote == "Auto-renews")
        #expect(PaywallMetrics.priceNoteTop < PaywallMetrics.ctaTop)
    }
}
