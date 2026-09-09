import Foundation

/// How often a plan bills.
public enum BillingPeriod: String, Sendable, Codable, CaseIterable {
    case month
    case year

    /// Billing periods per calendar year.
    public var periodsPerYear: Decimal {
        switch self {
        case .month: 12
        case .year: 1
        }
    }

    /// The noun the price line uses: "$29.99/year".
    public var suffix: String {
        rawValue
    }
}

/// A free introductory offer attached to a plan.
public struct IntroOffer: Equatable, Sendable, Codable {
    /// Number of free days, e.g. 7 for `P1W` and 3 for `P3D`.
    public let freeDays: Int

    public init(freeDays: Int) {
        self.freeDays = freeDays
    }
}

/// A purchasable plan, flattened out of StoreKit so the paywall never imports StoreKit
/// and `MockEntitlementStore` can stand in for previews, tests and snapshot runs.
public struct StorePlan: Equatable, Sendable, Identifiable, Codable {
    public let id: ProductID
    public let displayName: String
    /// The store's own formatted price, e.g. "$29.99". Preferred whenever it is shown alone.
    public let displayPrice: String
    public let price: Decimal
    public let currencyCode: String
    public let period: BillingPeriod
    public let introOffer: IntroOffer?

    public init(
        id: ProductID,
        displayName: String,
        displayPrice: String,
        price: Decimal,
        currencyCode: String = "USD",
        period: BillingPeriod,
        introOffer: IntroOffer? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.period = period
        self.introOffer = introOffer
    }

    /// This plan's price expressed as a yearly total.
    public var annualisedPrice: Decimal {
        price * period.periodsPerYear
    }
}

/// The fixture catalogue: exactly the three products in `Config/ScrollTheQuran.storekit`,
/// in `ProductID.allCases` order. Used by `MockEntitlementStore`, previews and snapshots
/// so the prices on a screenshot are the prices the store would have returned.
public enum StoreCatalogue {
    public static let yearly = StorePlan(
        id: .yearly,
        displayName: "Premium Yearly",
        displayPrice: "$29.99",
        price: Decimal(string: "29.99")!,
        period: .year,
        introOffer: IntroOffer(freeDays: 7)
    )

    public static let monthly = StorePlan(
        id: .monthly,
        displayName: "Premium Monthly",
        displayPrice: "$4.99",
        price: Decimal(string: "4.99")!,
        period: .month
    )

    public static let gift = StorePlan(
        id: .yearlyGift,
        displayName: "Premium Yearly (Gift)",
        displayPrice: "$19.99",
        price: Decimal(string: "19.99")!,
        period: .year,
        introOffer: IntroOffer(freeDays: 3)
    )

    public static let all: [StorePlan] = [yearly, monthly, gift]
}
