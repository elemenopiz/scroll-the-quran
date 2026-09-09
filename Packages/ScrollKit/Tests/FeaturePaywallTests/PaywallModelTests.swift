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
