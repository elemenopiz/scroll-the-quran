@testable import Commerce
import Foundation
import StoreKit
import StoreKitTest
import Testing

/// `SKTestSession` needs a real application process: it writes a StoreKit override into
/// the host app's container. Inside `swift test` the host is `swiftpm-testing-helper`,
/// which has no container, so the session logs `SKInternalErrorDomain 15` and every
/// `Product.products(for:)` throws. The lifecycle test below therefore runs only when the
/// bundle it is loaded into is app-hosted; on the host it is reported as skipped.
enum StoreKitTestSupport {
    static var isAppHosted: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// `Config/ScrollTheQuran.storekit`, found relative to this source file so no test
    /// bundle resource (and therefore no `Package.swift` change) is needed.
    static var configurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CommerceTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ScrollKit
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Config/ScrollTheQuran.storekit")
    }
}

@Suite("StoreKit entitlements", .serialized)
struct StoreKitEntitlementStoreTests {
    @Test("The StoreKit configuration file is where the test session expects it")
    func configurationFileExists() {
        #expect(FileManager.default.fileExists(atPath: StoreKitTestSupport.configurationURL.path))
    }

    @Test(
        "Buying the yearly plan entitles the store; expiring it takes the entitlement away",
        .enabled(if: StoreKitTestSupport.isAppHosted)
    )
    @MainActor
    func yearlyPurchaseLifecycle() async throws {
        let session = try SKTestSession(contentsOf: StoreKitTestSupport.configurationURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = StoreKitEntitlementStore()
        await store.load()
        #expect(store.products.map(\.id) == ProductID.allCases)
        #expect(store.isPremium == false)

        let outcome = try await store.purchase(.yearly)
        #expect(outcome == .purchased)
        #expect(store.isPremium)
        #expect(store.entitledProductIDs.contains(ProductID.yearly.rawValue))

        try session.expireSubscription(productIdentifier: ProductID.yearly.rawValue)
        await store.refreshEntitlements()
        #expect(store.isPremium == false)
    }

    @Test("Prices flattened out of StoreKit match the configuration file", .enabled(if: StoreKitTestSupport.isAppHosted))
    @MainActor
    func flattenedPrices() async throws {
        let session = try SKTestSession(contentsOf: StoreKitTestSupport.configurationURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let store = StoreKitEntitlementStore()
        await store.load()
        let yearly = try #require(store.plan(.yearly))
        #expect(yearly.price == Decimal(string: "29.99")!)
        #expect(yearly.period == .year)
        #expect(yearly.introOffer == IntroOffer(freeDays: 7))
        let gift = try #require(store.plan(.yearlyGift))
        #expect(gift.introOffer == IntroOffer(freeDays: 3))
        let monthly = try #require(store.plan(.monthly))
        #expect(monthly.period == .month)
        #expect(monthly.introOffer == nil)
    }
}

@Suite("Mock entitlements")
@MainActor
struct MockEntitlementStoreTests {
    @Test("The fixture catalogue is the three configured products, in order")
    func catalogue() {
        let store = MockEntitlementStore()
        #expect(store.products.map(\.id) == [.yearly, .monthly, .yearlyGift])
        #expect(store.isPremium == false)
        #expect(store.introOfferEligible)
    }

    @Test("A successful purchase entitles the store and burns the introductory offer")
    func purchaseEntitles() async throws {
        let store = MockEntitlementStore()
        let outcome = try await store.purchase(.yearly)
        #expect(outcome == .purchased)
        #expect(store.isPremium)
        #expect(store.introOfferEligible == false)
        #expect(store.purchaseCount == 1)
    }

    @Test("Expiring the subscription drops the entitlement")
    func expiry() async throws {
        let store = MockEntitlementStore()
        _ = try await store.purchase(.yearly)
        store.expire()
        #expect(store.isPremium == false)
    }

    @Test("A pending purchase unlocks nothing")
    func pending() async throws {
        let store = MockEntitlementStore()
        store.nextOutcome = .pending
        #expect(try await store.purchase(.yearly) == .pending)
        #expect(store.isPremium == false)
    }

    @Test("A cancelled purchase unlocks nothing")
    func cancelled() async throws {
        let store = MockEntitlementStore()
        store.nextOutcome = .cancelled
        #expect(try await store.purchase(.yearly) == .cancelled)
        #expect(store.isPremium == false)
    }

    @Test("Buying a product that is not in the catalogue throws")
    func unknownProduct() async {
        let store = MockEntitlementStore(products: [StoreCatalogue.monthly])
        await #expect(throws: CommerceError.productUnavailable(.yearly)) {
            try await store.purchase(.yearly)
        }
    }

    @Test("Errors are surfaced from purchase and restore")
    func errors() async {
        let store = MockEntitlementStore()
        store.nextError = .storeKit("network down")
        await #expect(throws: CommerceError.storeKit("network down")) { try await store.purchase(.yearly) }
        await #expect(throws: CommerceError.storeKit("network down")) { try await store.restore() }
    }

    @Test("plan(_:) looks a plan up by identifier")
    func planLookup() {
        let store = MockEntitlementStore()
        #expect(store.plan(.monthly)?.displayPrice == "$4.99")
        #expect(store.plan(.yearlyGift)?.displayPrice == "$19.99")
    }
}

@Suite("One-time offer persistence")
@MainActor
struct OneTimeOfferStoreTests {
    @Test("The in-memory store round-trips the flag")
    func inMemory() {
        let store = InMemoryOneTimeOfferStore()
        #expect(store.seenOneTimeOffer == false)
        store.seenOneTimeOffer = true
        #expect(store.seenOneTimeOffer)
    }

    @Test("The defaults-backed store round-trips the flag")
    func defaultsBacked() throws {
        let suite = "commerce.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DefaultsOneTimeOfferStore(defaults: defaults)
        #expect(store.seenOneTimeOffer == false)
        store.seenOneTimeOffer = true
        #expect(store.seenOneTimeOffer)
        #expect(defaults.bool(forKey: DefaultsOneTimeOfferStore.key))
    }
}
