@testable import Commerce
import Foundation
import Testing

/// Performs `action`, then waits for the store to have applied enough of
/// `customerInfoUpdates` for `condition` to hold.
///
/// The store's entitlement can change on the update stream, which is a `Task` started in
/// `init` — so "the card failed" and "the family organiser approved it" are observed one
/// hop after the line that causes them. The obvious way to wait for that is to poll a
/// clock, and it is wrong: under the full parallel suite the main actor is a single queue
/// shared by hundreds of tests, the hop can take seconds, and a wall-clock budget then
/// fails for reasons that have nothing to do with the code under test. (It did: three of
/// the tests below failed inside `Tools/verify.sh` and passed in isolation.)
///
/// So this waits on the store's own `onCustomerInfoApplied` seam instead — one wake per
/// applied update, no polling, no sleeping. The timeout is only a backstop so a genuine
/// failure reports rather than hangs the suite; on the passing path it is never reached.
///
/// Any update still buffered from an earlier call (a purchase pushes one) is applied
/// first, in order, and simply costs one extra condition check.
@MainActor
private func applying(
    to store: RevenueCatEntitlementStore,
    timeout: Duration = .seconds(30),
    until condition: @MainActor () -> Bool,
    _ action: @MainActor () -> Void
) async -> Bool {
    let (wakes, continuation) = AsyncStream<Void>.makeStream()
    store.onCustomerInfoApplied = { _ in continuation.yield() }
    defer {
        store.onCustomerInfoApplied = nil
        continuation.finish()
    }

    action()
    if condition() { return true }

    let backstop = Task { @MainActor in
        try? await Task.sleep(for: timeout)
        continuation.finish()
    }
    defer { backstop.cancel() }

    for await _ in wakes where condition() {
        return true
    }
    return condition()
}

// MARK: - Mapping

@Suite("RevenueCat → BillingState")
struct RevenueCatBillingStateTests {
    @Test("No entitlement at all is 'never subscribed'")
    func noEntitlement() {
        #expect(BillingState(entitlement: nil) == .notSubscribed)
    }

    @Test("Active with no billing issue is subscribed")
    func active() {
        #expect(BillingState(entitlement: RCEntitlementInfo(isActive: true)) == .subscribed)
    }

    @Test("Active *with* a billing issue is the grace period — still entitled, still in trouble")
    func gracePeriod() {
        let state = BillingState(entitlement: RCEntitlementInfo(
            isActive: true,
            billingIssueDetectedAt: Date()
        ))
        #expect(state == .inGracePeriod)
        // The distinction that matters: access continues, and Settings still nags.
        #expect(state.needsPaymentUpdate)
        #expect(state.bannerMessage?.contains("continues") == true)
    }

    @Test("Inactive with a billing issue is billing retry — access has stopped")
    func billingRetry() {
        let state = BillingState(entitlement: RCEntitlementInfo(
            isActive: false,
            expirationDate: Date(),
            billingIssueDetectedAt: Date()
        ))
        #expect(state == .inBillingRetry)
        #expect(state.needsPaymentUpdate)
        #expect(state.bannerMessage?.contains("paused") == true)
    }

    @Test("Inactive with an expiry and no billing issue is a plain expiry, and asks for nothing")
    func expired() {
        let state = BillingState(entitlement: RCEntitlementInfo(isActive: false, expirationDate: Date()))
        #expect(state == .expired)
        #expect(state.needsPaymentUpdate == false)
        #expect(state.bannerTitle == nil)
    }

    @Test("An entitlement that was never active is 'never subscribed', not 'expired'")
    func neverActive() {
        #expect(BillingState(entitlement: RCEntitlementInfo(isActive: false)) == .notSubscribed)
    }

    @Test("Grace period outranks a lapse when two states meet")
    func precedence() {
        #expect(BillingState.inGracePeriod.combined(with: .expired) == .inGracePeriod)
        #expect(BillingState.subscribed.combined(with: .inGracePeriod) == .subscribed)
    }
}

@Suite("RevenueCat → StorePlan")
struct RevenueCatStorePlanTests {
    @Test("A package becomes the plan the paywall renders, price and trial intact")
    func plan() throws {
        let plan = try #require(StorePlan(package: RCPackage(identifier: "$rc_annual", storeProduct: .yearly)))
        #expect(plan.id == .yearly)
        #expect(plan.displayPrice == "$29.99")
        #expect(plan.period == .year)
        #expect(plan.introOffer?.freeDays == 7)
        // Same numbers the StoreKit path produces, so swapping stores cannot move a price.
        #expect(plan == StoreCatalogue.yearly)
    }

    @Test("The monthly and gift packages match the StoreKit catalogue too")
    func otherPlans() throws {
        let monthly = try #require(StorePlan(package: RCPackage(identifier: "$rc_monthly", storeProduct: .monthly)))
        let gift = try #require(StorePlan(package: RCPackage(identifier: "gift_annual", storeProduct: .yearlyGift)))
        #expect(monthly == StoreCatalogue.monthly)
        #expect(gift == StoreCatalogue.gift)
    }

    @Test("A package for a product the app does not sell is dropped, not forced into a ProductID")
    func unknownProduct() {
        let stray = RCStoreProduct(
            productIdentifier: "com.scrollthequran.lifetime",
            localizedTitle: "Lifetime",
            localizedPriceString: "$99.99",
            price: 99.99,
            periodUnit: .year
        )
        let package = RCPackage(identifier: "$rc_lifetime", storeProduct: stray)
        #expect(package.productID == nil)
        #expect(StorePlan(package: package) == nil)
    }

    @Test("paywallOffering falls back to `default` when no offering is marked current")
    func offeringFallback() {
        let offering = RCOffering(identifier: "default", packages: [])
        let offerings = RCOfferings(current: nil, all: ["default": offering, "promo": RCOffering(identifier: "promo", packages: [])])
        #expect(offerings.paywallOffering?.identifier == "default")
        #expect(RCOfferings(current: offering).paywallOffering?.identifier == "default")
        #expect(RCOfferings(current: nil, all: [:]).paywallOffering == nil)
    }
}

// MARK: - The store

@MainActor
@Suite("RevenueCat entitlement store")
struct RevenueCatEntitlementStoreTests {
    // MARK: Configuration

    @Test("A non-empty API key configures the SDK exactly once; an empty one does not touch it")
    func configuration() {
        let client = StubRevenueCatClient()
        _ = RevenueCatEntitlementStore(client: client, apiKey: "appl_test", appUserID: nil)
        #expect(client.configureCount == 1)
        #expect(client.configuredAPIKey == "appl_test")
        // nil app user id: RevenueCat generates an anonymous one, and the Apple identifier
        // never leaves the device.
        #expect(client.configuredAppUserID == nil)

        let second = StubRevenueCatClient()
        _ = RevenueCatEntitlementStore(client: second)
        #expect(second.configureCount == 0)
    }

    // MARK: Catalogue

    @Test("load() builds the catalogue in ProductID order, whatever order the dashboard returned")
    func loadCatalogue() async {
        let client = StubRevenueCatClient(offerings: RCOfferings(current: RCOffering(
            identifier: "default",
            packages: [
                RCPackage(identifier: "gift_annual", storeProduct: .yearlyGift),
                RCPackage(identifier: "$rc_monthly", storeProduct: .monthly),
                RCPackage(identifier: "$rc_annual", storeProduct: .yearly),
            ]
        )))
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()

        #expect(store.products.map(\.id) == ProductID.allCases)
        #expect(store.products == StoreCatalogue.all)
        #expect(store.hasLoaded)
        #expect(store.lastError == nil)
        #expect(store.isPremium == false)
        #expect(store.billingState == .notSubscribed)
    }

    @Test("An offering carrying a product the app does not sell loads the rest instead of failing")
    func strayPackage() async {
        let stray = RCPackage(
            identifier: "$rc_weekly",
            storeProduct: RCStoreProduct(
                productIdentifier: "com.scrollthequran.weekly",
                localizedTitle: "Weekly",
                localizedPriceString: "$1.99",
                price: 1.99,
                periodUnit: .week
            )
        )
        let client = StubRevenueCatClient(offerings: RCOfferings(current: RCOffering(
            identifier: "default",
            packages: [stray, RCPackage(identifier: "$rc_annual", storeProduct: .yearly)]
        )))
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.products.map(\.id) == [.yearly])
    }

    @Test("A failed load records the error and leaves the catalogue it already had")
    func loadFailure() async {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.products.count == 3)

        client.nextError = .underlying("The network connection was lost.")
        await store.load()
        // The paywall must not blank out because one refresh timed out.
        #expect(store.products.count == 3)
        #expect(store.lastError == .storeKit("The network connection was lost."))
    }

    // MARK: Purchasing

    @Test("Buying the yearly plan unlocks Premium")
    func purchaseUnlocks() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.isPremium == false)

        let outcome = try await store.purchase(.yearly)

        #expect(outcome == .purchased)
        #expect(store.isPremium)
        #expect(store.billingState == .subscribed)
        #expect(store.entitledProductIDs.contains(ProductID.yearly.rawValue))
        #expect(store.lastError == nil)
        // The purchase went through the *package*, not a raw product id.
        #expect(client.purchasedPackages.map(\.identifier) == ["$rc_annual"])
    }

    @Test("Each plan unlocks the same `premium` entitlement", arguments: ProductID.allCases)
    func everyPlanUnlocks(id: ProductID) async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(try await store.purchase(id) == .purchased)
        #expect(store.isPremium)
        #expect(store.entitledProductIDs == [id.rawValue])
    }

    @Test("The entitlement id decides Premium — an active entitlement under another name does not")
    func onlyPremiumEntitlementUnlocks() async {
        let client = StubRevenueCatClient(customerInfo: RCCustomerInfo(
            entitlements: ["pro": RCEntitlementInfo(identifier: "pro", isActive: true)],
            activeSubscriptions: ["com.scrollthequran.yearly"]
        ))
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.isPremium == false)
        #expect(store.billingState == .notSubscribed)
    }

    @Test("Backing out of the App Store sheet unlocks nothing")
    func purchaseCancelled() async throws {
        let client = StubRevenueCatClient()
        client.nextPurchaseResult = .cancelled
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()

        #expect(try await store.purchase(.yearly) == .cancelled)
        #expect(store.isPremium == false)
        #expect(store.lastError == nil)
    }

    @Test("Ask to Buy unlocks nothing until the approval arrives on the stream")
    func askToBuy() async throws {
        let client = StubRevenueCatClient()
        client.nextPurchaseResult = .pending
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()

        #expect(try await store.purchase(.yearly) == .pending)
        #expect(store.isPremium == false)

        // Twenty minutes later, a family organiser says yes. Nothing in the app is called;
        // it arrives on customerInfoUpdates.
        #expect(await applying(to: store, until: { store.isPremium }) {
            client.approvePendingPurchase(of: .yearly)
        })
        #expect(store.billingState == .subscribed)
    }

    @Test("Buying a product the dashboard's offering does not carry is a productUnavailable")
    func packageMissingFromOffering() async {
        let client = StubRevenueCatClient(offerings: RCOfferings(current: RCOffering(
            identifier: "default",
            packages: [RCPackage(identifier: "$rc_annual", storeProduct: .yearly)]
        )))
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()

        await #expect(throws: CommerceError.productUnavailable(.monthly)) {
            try await store.purchase(.monthly)
        }
        #expect(store.lastError == .productUnavailable(.monthly))
        #expect(client.purchaseCount == 0)
    }

    @Test("A declined card surfaces as a message the paywall can show, and is remembered")
    func purchaseFailure() async {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        client.nextError = .underlying("Your card was declined.")

        await #expect(throws: CommerceError.storeKit("Your card was declined.")) {
            try await store.purchase(.yearly)
        }
        #expect(store.lastError == .storeKit("Your card was declined."))
        #expect(store.isPremium == false)
    }

    @Test("An unconfigured SDK does not leak its internals onto the paywall")
    func notConfiguredIsReadable() async {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        client.nextError = .notConfigured

        await #expect(throws: CommerceError.self) {
            try await store.purchase(.yearly)
        }
        guard case let .storeKit(message) = store.lastError else {
            Issue.record("expected a .storeKit error, got \(String(describing: store.lastError))")
            return
        }
        #expect(message.contains("not available") )
        #expect(message.lowercased().contains("configure") == false)
    }

    // MARK: Restoring

    @Test("Restore brings an existing subscription back")
    func restoreGrants() async throws {
        let client = StubRevenueCatClient()
        client.restoresTo = .entitled(to: .monthly)
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.isPremium == false)

        try await store.restore()

        #expect(store.isPremium)
        #expect(store.billingState == .subscribed)
        #expect(store.entitledProductIDs == [ProductID.monthly.rawValue])
        #expect(client.restoreCount == 1)
    }

    @Test("Restore with nothing to restore is not an error, and unlocks nothing")
    func restoreEmpty() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()

        try await store.restore()

        #expect(store.isPremium == false)
        #expect(store.lastError == nil)
    }

    @Test("A failed restore throws and is remembered")
    func restoreFailure() async {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        client.nextError = .underlying("Could not reach the App Store.")

        await #expect(throws: CommerceError.storeKit("Could not reach the App Store.")) {
            try await store.restore()
        }
        #expect(store.lastError == .storeKit("Could not reach the App Store."))
    }

    // MARK: Billing state over the stream

    @Test("A card that fails keeps access and raises the banner")
    func gracePeriodArrivesOnTheStream() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        _ = try await store.purchase(.yearly)
        #expect(store.billingState == .subscribed)
        #expect(store.needsPaymentUpdate == false)

        #expect(await applying(to: store, until: { store.billingState == .inGracePeriod }) {
            client.enterGracePeriod()
        })
        // The point of the whole BillingState detour: still a paying customer.
        #expect(store.isPremium)
        #expect(store.needsPaymentUpdate)
        #expect(store.billingState.bannerTitle == "Update your payment method")
    }

    @Test("Billing retry without a grace period stops access, and still raises the banner")
    func billingRetryArrivesOnTheStream() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        _ = try await store.purchase(.yearly)

        #expect(await applying(to: store, until: { store.billingState == .inBillingRetry }) {
            client.enterBillingRetry()
        })
        #expect(store.isPremium == false)
        #expect(store.needsPaymentUpdate)
    }

    @Test("An expiry drops Premium and asks for nothing")
    func expiryArrivesOnTheStream() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        _ = try await store.purchase(.yearly)

        #expect(await applying(to: store, until: { store.isPremium == false }) {
            client.expire()
        })
        #expect(store.billingState == .expired)
        #expect(store.needsPaymentUpdate == false)
    }

    @Test("A purchase made on another device arrives with no call from this one")
    func purchaseOnAnotherDevice() async {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.isPremium == false)

        #expect(await applying(to: store, until: { store.isPremium }) {
            client.push(.entitled(to: .yearlyGift))
        })
        #expect(store.entitledProductIDs == [ProductID.yearlyGift.rawValue])
        #expect(client.purchaseCount == 0)
        #expect(client.restoreCount == 0)
    }

    // MARK: Intro offer

    @Test("The trial is on the table until the customer is entitled")
    func introEligibility() async throws {
        let client = StubRevenueCatClient()
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.introOfferEligible)

        _ = try await store.purchase(.yearly)
        #expect(store.introOfferEligible == false)
    }

    @Test("A client that reports ineligibility is believed, entitled or not")
    func introEligibilityOverride() async {
        let client = StubRevenueCatClient()
        client.introEligibilityOverride = [.yearly: false]
        let store = RevenueCatEntitlementStore(client: client)
        await store.load()
        #expect(store.isPremium == false)
        #expect(store.introOfferEligible == false)
    }

    // MARK: The protocol seam

    @Test("It is an EntitlementProviding, so the paywall needs no change to use it")
    func conformsToTheSeam() async throws {
        let client = StubRevenueCatClient()
        let store: any EntitlementProviding = RevenueCatEntitlementStore(client: client)
        await store.load()

        #expect(store.plan(.yearly) == StoreCatalogue.yearly)
        #expect(store.plan(.monthly)?.displayPrice == "$4.99")
        #expect(try await store.purchase(.yearly) == .purchased)
        #expect(store.isPremium)
        #expect(store.needsPaymentUpdate == false)
    }
}
