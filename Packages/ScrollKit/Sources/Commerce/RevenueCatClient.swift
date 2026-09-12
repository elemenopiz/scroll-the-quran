import Foundation

/// The seam between `RevenueCatEntitlementStore` and the RevenueCat SDK.
///
/// **Nothing here imports `RevenueCat`, and nothing in the shipped app uses it yet.** The
/// app's purchase path is StoreKit 2 (`StoreKitEntitlementStore`) and stays that way until
/// the orchestrator adds the `purchases-ios` dependency — see `docs/infra/revenuecat.md`
/// for the two lines that change in `Package.swift` and `project.yml`, and for why the
/// paywall itself is staying native.
///
/// The value types below mirror the shapes RevenueCat returns, field for field, so the
/// real adapter is a translation layer with no decisions in it:
///
/// ```swift
/// import RevenueCat
///
/// final class LivePurchasesClient: RevenueCatClient {
///     func configure(apiKey: String, appUserID: String?) {
///         Purchases.configure(with: .init(withAPIKey: apiKey).with(appUserID: appUserID))
///     }
///     func offerings() async throws -> RCOfferings {
///         RCOfferings(try await Purchases.shared.offerings())   // one initialiser, below
///     }
///     …
/// }
/// ```
///
/// Keeping the protocol here means the store is unit-testable with `StubRevenueCatClient`
/// on a machine with no network, no App Store account and no SDK checked out, which is
/// exactly the situation `swift test` runs in.
@MainActor
public protocol RevenueCatClient: AnyObject {
    /// `Purchases.configure(with:)`. Safe to call more than once; the second call is a
    /// no-op in the real SDK.
    ///
    /// `appUserID` is RevenueCat's alias for the customer. Pass `nil` and RevenueCat
    /// generates an anonymous id — which is the right default here, because Sign in with
    /// Apple is optional and the raw Apple identifier must not be sent to a third party.
    /// If an id is ever passed it should be the same `apple_sub_hash` the Supabase schema
    /// stores (`supabase/README.md`), never `credential.user` itself.
    func configure(apiKey: String, appUserID: String?)

    /// `Purchases.shared.offerings()`.
    func offerings() async throws -> RCOfferings

    /// `Purchases.shared.purchase(package:)`, with RevenueCat's cancellation flag and its
    /// `paymentPendingError` already folded into the result.
    func purchase(_ package: RCPackage) async throws -> RCPurchaseResult

    /// `Purchases.shared.restorePurchases()`.
    func restore() async throws -> RCCustomerInfo

    /// The customer info RevenueCat has right now, or `nil` before the first fetch.
    /// `Purchases.shared.customerInfo()`.
    func customerInfo() async throws -> RCCustomerInfo

    /// `Purchases.shared.customerInfoStream` — renewals, expiries, refunds, Ask to Buy
    /// approvals and purchases made on another device all arrive here.
    ///
    /// The store holds one task on this for its whole lifetime, which is what makes an
    /// entitlement that changes outside the app show up without a relaunch.
    var customerInfoUpdates: AsyncStream<RCCustomerInfo> { get }

    /// `Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers:)`.
    ///
    /// Has a default that reports "eligible" for everything, because the five members
    /// above are the protocol the brief asked for and a client that does not implement
    /// this should not be forced to lie in the other direction: showing the trial to
    /// someone who has used it is a cosmetic wrong, hiding it from someone who has not is
    /// a lost sale.
    func introEligibility(for productIDs: [ProductID]) async -> [ProductID: Bool]
}

public extension RevenueCatClient {
    func introEligibility(for productIDs: [ProductID]) async -> [ProductID: Bool] {
        Dictionary(uniqueKeysWithValues: productIDs.map { ($0, true) })
    }
}

// MARK: - Identifiers

/// The strings that have to match the RevenueCat dashboard exactly. They are spelled out
/// once, here, the same way `ProductID` is the only place a product identifier is spelled.
public enum RevenueCatConfiguration {
    /// The entitlement every plan grants. Dashboard → Entitlements.
    public static let premiumEntitlementID = "premium"
    /// The offering the paywall reads. Dashboard → Offerings; must be marked *current*.
    public static let defaultOfferingID = "default"
}

// MARK: - Value types

/// How often a `RCStoreProduct` bills. RevenueCat's `SubscriptionPeriod.Unit`, minus the
/// units this app does not sell.
public enum RCPeriodUnit: String, Sendable, Equatable, Codable {
    case day, week, month, year
}

/// `RevenueCat.StoreProduct`, flattened.
public struct RCStoreProduct: Sendable, Equatable {
    public let productIdentifier: String
    public let localizedTitle: String
    /// The store's own formatted price, e.g. "$29.99".
    public let localizedPriceString: String
    public let price: Decimal
    public let currencyCode: String
    public let periodUnit: RCPeriodUnit
    public let periodValue: Int
    /// Free days in the introductory offer, when it is a free trial. `nil` for no offer,
    /// and for a paid introductory offer — the paywall only renders free trials.
    public let introductoryFreeDays: Int?

    public init(
        productIdentifier: String,
        localizedTitle: String,
        localizedPriceString: String,
        price: Decimal,
        currencyCode: String = "USD",
        periodUnit: RCPeriodUnit,
        periodValue: Int = 1,
        introductoryFreeDays: Int? = nil
    ) {
        self.productIdentifier = productIdentifier
        self.localizedTitle = localizedTitle
        self.localizedPriceString = localizedPriceString
        self.price = price
        self.currencyCode = currencyCode
        self.periodUnit = periodUnit
        self.periodValue = periodValue
        self.introductoryFreeDays = introductoryFreeDays
    }

    /// The app's product id, or `nil` for a product RevenueCat knows about and the app
    /// does not. An offering with a stray package must not crash the paywall.
    public var productID: ProductID? {
        ProductID(rawValue: productIdentifier)
    }
}

/// `RevenueCat.Package`.
public struct RCPackage: Sendable, Equatable, Identifiable {
    /// RevenueCat's package identifier — `$rc_annual`, `$rc_monthly`, or a custom one.
    public let identifier: String
    public let storeProduct: RCStoreProduct

    public init(identifier: String, storeProduct: RCStoreProduct) {
        self.identifier = identifier
        self.storeProduct = storeProduct
    }

    public var id: String {
        identifier
    }

    public var productID: ProductID? {
        storeProduct.productID
    }
}

/// `RevenueCat.Offering`.
public struct RCOffering: Sendable, Equatable {
    public let identifier: String
    public let packages: [RCPackage]

    public init(identifier: String, packages: [RCPackage]) {
        self.identifier = identifier
        self.packages = packages
    }
}

/// `RevenueCat.Offerings`.
public struct RCOfferings: Sendable, Equatable {
    /// The offering marked *current* in the dashboard.
    public let current: RCOffering?
    public let all: [String: RCOffering]

    public init(current: RCOffering?, all: [String: RCOffering] = [:]) {
        self.current = current
        var byID = all
        if let current, byID[current.identifier] == nil {
            byID[current.identifier] = current
        }
        self.all = byID
    }

    /// The offering the paywall should render: the current one, falling back to the one
    /// named `default` if the dashboard's *current* flag was never set.
    public var paywallOffering: RCOffering? {
        current ?? all[RevenueCatConfiguration.defaultOfferingID]
    }
}

/// `RevenueCat.EntitlementInfo`, reduced to the fields that decide `BillingState`.
public struct RCEntitlementInfo: Sendable, Equatable {
    public let identifier: String
    /// Whether the customer may use the feature *right now*. Stays true through a grace
    /// period, which is the whole reason `BillingState` exists separately from `isPremium`.
    public let isActive: Bool
    public let willRenew: Bool
    /// The product that granted the entitlement.
    public let productIdentifier: String
    public let expirationDate: Date?
    /// Set when Apple reported a payment problem. RevenueCat does not expose "grace
    /// period" as a state; this field plus `isActive` is how you tell the two apart.
    public let billingIssueDetectedAt: Date?
    /// Set when the customer turned off auto-renew. Not a billing problem.
    public let unsubscribeDetectedAt: Date?

    public init(
        identifier: String = RevenueCatConfiguration.premiumEntitlementID,
        isActive: Bool,
        willRenew: Bool = true,
        productIdentifier: String = ProductID.yearly.rawValue,
        expirationDate: Date? = nil,
        billingIssueDetectedAt: Date? = nil,
        unsubscribeDetectedAt: Date? = nil
    ) {
        self.identifier = identifier
        self.isActive = isActive
        self.willRenew = willRenew
        self.productIdentifier = productIdentifier
        self.expirationDate = expirationDate
        self.billingIssueDetectedAt = billingIssueDetectedAt
        self.unsubscribeDetectedAt = unsubscribeDetectedAt
    }
}

/// `RevenueCat.CustomerInfo`, reduced to what the store reads.
public struct RCCustomerInfo: Sendable, Equatable {
    /// `customerInfo.entitlements.all`, keyed by entitlement id.
    public let entitlements: [String: RCEntitlementInfo]
    /// `customerInfo.activeSubscriptions` — product identifiers, not entitlement ids.
    public let activeSubscriptions: Set<String>
    public let originalAppUserID: String

    public init(
        entitlements: [String: RCEntitlementInfo] = [:],
        activeSubscriptions: Set<String> = [],
        originalAppUserID: String = ""
    ) {
        self.entitlements = entitlements
        self.activeSubscriptions = activeSubscriptions
        self.originalAppUserID = originalAppUserID
    }

    /// The `premium` entitlement, if RevenueCat has ever reported it.
    public var premium: RCEntitlementInfo? {
        entitlements[RevenueCatConfiguration.premiumEntitlementID]
    }

    /// Nobody has ever bought anything.
    public static let empty = RCCustomerInfo()

    /// A customer with `premium` active on `id`, for previews and stubs.
    public static func entitled(
        to id: ProductID = .yearly,
        expiring: Date? = nil,
        billingIssueDetectedAt: Date? = nil
    ) -> RCCustomerInfo {
        RCCustomerInfo(
            entitlements: [
                RevenueCatConfiguration.premiumEntitlementID: RCEntitlementInfo(
                    isActive: true,
                    productIdentifier: id.rawValue,
                    expirationDate: expiring,
                    billingIssueDetectedAt: billingIssueDetectedAt
                ),
            ],
            activeSubscriptions: [id.rawValue]
        )
    }
}

/// What a purchase ended in. RevenueCat throws for cancellation and for Ask to Buy; the
/// client folds both into this so the store has one thing to switch on.
public enum RCPurchaseResult: Sendable, Equatable {
    case purchased(RCCustomerInfo)
    /// `userCancelled == true`.
    case cancelled
    /// `ErrorCode.paymentPendingError` — Ask to Buy. Nothing is unlocked; the entitlement
    /// arrives later on `customerInfoUpdates`, if the family organiser approves.
    case pending
}

/// Errors the client raises. Deliberately small: the store flattens every one of them to
/// `CommerceError` before the paywall sees it.
public enum RevenueCatError: Error, Equatable, Sendable {
    /// `configure(apiKey:appUserID:)` was never called, or the key was empty.
    case notConfigured
    /// The offering has no package for that product — a dashboard that does not match
    /// `ProductID`, which is the most likely RevenueCat misconfiguration.
    case packageUnavailable(ProductID)
    /// Anything else the SDK threw, flattened to its message.
    case underlying(String)
}

// MARK: - Flattening RevenueCat

public extension StorePlan {
    /// The paywall's view of a RevenueCat package. `nil` for a package whose product is
    /// not one of ours.
    init?(package: RCPackage) {
        guard let id = package.productID else { return nil }
        let product = package.storeProduct
        self.init(
            id: id,
            displayName: product.localizedTitle,
            displayPrice: product.localizedPriceString,
            price: product.price,
            currencyCode: product.currencyCode,
            period: product.periodUnit == .month ? .month : .year,
            introOffer: product.introductoryFreeDays.map(IntroOffer.init(freeDays:))
        )
    }
}

public extension BillingState {
    /// Maps RevenueCat's entitlement onto the app's own vocabulary.
    ///
    /// RevenueCat has no renewal-state enum to copy — there is no `.inGracePeriod` to read.
    /// What it gives you is `isActive` and `billingIssueDetectedAt`, and the two together
    /// say the same thing StoreKit's `RenewalState` does:
    ///
    /// | `isActive` | `billingIssueDetectedAt` | meaning |
    /// |---|---|---|
    /// | true  | nil     | renewing normally → `.subscribed` |
    /// | true  | a date  | Apple is retrying and access continues → `.inGracePeriod` |
    /// | false | a date  | Apple is retrying and access has stopped → `.inBillingRetry` |
    /// | false | nil     | it ended → `.expired`, or `.notSubscribed` if there was never one |
    ///
    /// **`.revoked` is unreachable from here, and that is a property of RevenueCat, not an
    /// omission.** A refund removes the entitlement client-side, so it is indistinguishable
    /// from an expiry; RevenueCat surfaces refunds through server webhooks
    /// (`CANCELLATION` with `reason: CUSTOMER_SUPPORT`), not through `CustomerInfo`. If the
    /// app ever needs to tell a refund from a lapse, that is the mechanism — not a field on
    /// this type. `StoreKitEntitlementStore` keeps `.revoked` because
    /// `Transaction.revocationDate` does distinguish them.
    init(entitlement: RCEntitlementInfo?) {
        guard let entitlement else {
            self = .notSubscribed
            return
        }
        switch (entitlement.isActive, entitlement.billingIssueDetectedAt != nil) {
        case (true, false):
            self = .subscribed
        case (true, true):
            self = .inGracePeriod
        case (false, true):
            self = .inBillingRetry
        case (false, false):
            // An entitlement object that has never been active at all (RevenueCat does not
            // normally return one) is "never subscribed", not "expired".
            self = entitlement.expirationDate == nil ? .notSubscribed : .expired
        }
    }
}
