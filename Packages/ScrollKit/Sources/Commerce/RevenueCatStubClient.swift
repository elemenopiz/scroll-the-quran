import Foundation

/// A `RevenueCatClient` with no SDK, no network and no App Store behind it.
///
/// It exists so `RevenueCatEntitlementStore` can be tested for real — including the parts
/// that are hardest to reach against a live store: a card that fails while access
/// continues, an Ask to Buy that is approved twenty minutes later, a purchase made on the
/// customer's other phone. Each of those is a method call here.
///
/// Lives in `Sources` rather than `Tests` for the same reason `MockEntitlementStore` does:
/// previews and the `--screenshot` routes need it too, and a test-only type cannot be
/// imported by either.
@MainActor
public final class StubRevenueCatClient: RevenueCatClient {
    /// What `offerings()` returns.
    public var offerings: RCOfferings
    /// The customer as RevenueCat currently sees them. Every call that changes the
    /// entitlement goes through `push(_:)` so the stream stays in step.
    public private(set) var customerInfo: RCCustomerInfo

    /// What the next `purchase(_:)` reports. Set to `.pending` to pose Ask to Buy.
    public var nextPurchaseResult: PurchasePose = .purchased
    /// Set to make the next `purchase(_:)` or `restore()` throw.
    public var nextError: RevenueCatError?
    /// Set when the customer is meant to *have* something to restore.
    public var restoresTo: RCCustomerInfo?
    /// What `introEligibility(for:)` answers. `nil` falls back to the protocol's default.
    public var introEligibilityOverride: [ProductID: Bool]?
    /// How long `purchase(_:)` takes, for the test that has to see the in-flight state.
    public var purchaseDelay: Duration = .zero

    public private(set) var configureCount = 0
    public private(set) var configuredAPIKey: String?
    public private(set) var configuredAppUserID: String?
    public private(set) var offeringsCount = 0
    public private(set) var purchaseCount = 0
    public private(set) var restoreCount = 0
    public private(set) var customerInfoCount = 0
    /// Every package `purchase(_:)` was called with, in order.
    public private(set) var purchasedPackages: [RCPackage] = []

    private var continuation: AsyncStream<RCCustomerInfo>.Continuation?
    private let stream: AsyncStream<RCCustomerInfo>

    /// What a stubbed purchase ends in.
    public enum PurchasePose: Sendable, Equatable {
        /// Grants `premium` on the purchased product.
        case purchased
        case cancelled
        /// Ask to Buy. Nothing is granted and nothing is pushed to the stream — approval
        /// arrives later, which is what `approvePendingPurchase(of:)` poses.
        case pending
    }

    public init(
        offerings: RCOfferings = .stubDefault,
        customerInfo: RCCustomerInfo = .empty
    ) {
        self.offerings = offerings
        self.customerInfo = customerInfo
        var escaped: AsyncStream<RCCustomerInfo>.Continuation?
        stream = AsyncStream { escaped = $0 }
        continuation = escaped
    }

    deinit {
        continuation?.finish()
    }

    // MARK: - RevenueCatClient

    public func configure(apiKey: String, appUserID: String?) {
        configureCount += 1
        configuredAPIKey = apiKey
        configuredAppUserID = appUserID
    }

    public func offerings() async throws -> RCOfferings {
        offeringsCount += 1
        if let nextError {
            throw nextError
        }
        return offerings
    }

    public func purchase(_ package: RCPackage) async throws -> RCPurchaseResult {
        purchaseCount += 1
        purchasedPackages.append(package)
        if purchaseDelay > .zero {
            try? await Task.sleep(for: purchaseDelay)
        }
        if let nextError {
            throw nextError
        }
        switch nextPurchaseResult {
        case .cancelled:
            return .cancelled
        case .pending:
            return .pending
        case .purchased:
            guard let id = package.productID else {
                throw RevenueCatError.underlying("Unknown product \(package.storeProduct.productIdentifier)")
            }
            let info = RCCustomerInfo.entitled(to: id)
            push(info)
            return .purchased(info)
        }
    }

    public func restore() async throws -> RCCustomerInfo {
        restoreCount += 1
        if let nextError {
            throw nextError
        }
        if let restoresTo {
            push(restoresTo)
        }
        return customerInfo
    }

    public func customerInfo() async throws -> RCCustomerInfo {
        customerInfoCount += 1
        if let nextError {
            throw nextError
        }
        return customerInfo
    }

    public var customerInfoUpdates: AsyncStream<RCCustomerInfo> {
        stream
    }

    public func introEligibility(for productIDs: [ProductID]) async -> [ProductID: Bool] {
        guard let introEligibilityOverride else {
            return Dictionary(uniqueKeysWithValues: productIDs.map { ($0, !isEntitled) })
        }
        return introEligibilityOverride
    }

    // MARK: - Test hooks
    //
    // Each of these poses something that happens *outside* the app, which is the whole
    // category `Transaction.updates` / `customerInfoStream` exists for and the one a
    // purchase-only test can never reach.

    /// The card failed and Apple is retrying while access continues.
    public func enterGracePeriod(on id: ProductID = .yearly) {
        push(.entitled(to: id, billingIssueDetectedAt: Date()))
    }

    /// The card failed, there is no grace period, and access has stopped.
    public func enterBillingRetry(on id: ProductID = .yearly) {
        push(RCCustomerInfo(entitlements: [
            RevenueCatConfiguration.premiumEntitlementID: RCEntitlementInfo(
                isActive: false,
                willRenew: true,
                productIdentifier: id.rawValue,
                expirationDate: Date(),
                billingIssueDetectedAt: Date()
            ),
        ]))
    }

    /// The subscription ended.
    public func expire(_ id: ProductID = .yearly) {
        push(RCCustomerInfo(entitlements: [
            RevenueCatConfiguration.premiumEntitlementID: RCEntitlementInfo(
                isActive: false,
                willRenew: false,
                productIdentifier: id.rawValue,
                expirationDate: Date()
            ),
        ]))
    }

    /// A family organiser approved an Ask to Buy, or the customer bought on another device.
    public func approvePendingPurchase(of id: ProductID = .yearly) {
        push(.entitled(to: id))
    }

    /// Push customer info the way RevenueCat's stream would, and keep `customerInfo()` in
    /// step with it — a stub whose stream and whose getter disagree teaches the test a
    /// lesson that is not true of the real SDK.
    public func push(_ info: RCCustomerInfo) {
        customerInfo = info
        continuation?.yield(info)
    }

    /// Close the stream, so a test can assert the store's listener task ends.
    public func finishStream() {
        continuation?.finish()
    }

    private var isEntitled: Bool {
        customerInfo.premium?.isActive ?? false
    }
}

// MARK: - Fixtures

public extension RCStoreProduct {
    /// The three products as the RevenueCat dashboard would return them, matching
    /// `StoreCatalogue` (and therefore `Config/ScrollTheQuran.storekit`) price for price.
    static let yearly = RCStoreProduct(
        productIdentifier: ProductID.yearly.rawValue,
        localizedTitle: "Premium Yearly",
        localizedPriceString: "$29.99",
        price: Decimal(string: "29.99")!,
        periodUnit: .year,
        introductoryFreeDays: 7
    )

    static let monthly = RCStoreProduct(
        productIdentifier: ProductID.monthly.rawValue,
        localizedTitle: "Premium Monthly",
        localizedPriceString: "$4.99",
        price: Decimal(string: "4.99")!,
        periodUnit: .month
    )

    static let yearlyGift = RCStoreProduct(
        productIdentifier: ProductID.yearlyGift.rawValue,
        localizedTitle: "Premium Yearly (Gift)",
        localizedPriceString: "$19.99",
        price: Decimal(string: "19.99")!,
        periodUnit: .year,
        introductoryFreeDays: 3
    )
}

public extension RCOfferings {
    /// The `default` offering with all three packages, using RevenueCat's own package
    /// identifiers where it has them (`$rc_annual`, `$rc_monthly`) and a custom one for
    /// the gift, which has no standard package type.
    static let stubDefault = RCOfferings(
        current: RCOffering(
            identifier: RevenueCatConfiguration.defaultOfferingID,
            packages: [
                RCPackage(identifier: "$rc_annual", storeProduct: .yearly),
                RCPackage(identifier: "$rc_monthly", storeProduct: .monthly),
                RCPackage(identifier: "gift_annual", storeProduct: .yearlyGift),
            ]
        )
    )
}
