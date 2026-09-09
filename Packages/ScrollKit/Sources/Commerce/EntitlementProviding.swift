import Foundation

/// What `purchase(_:)` came back with. `pending` is Ask to Buy / deferred approval:
/// nothing is unlocked yet, the `Transaction.updates` listener finishes the job.
public enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
}

/// Errors the store surfaces to the paywall.
public enum CommerceError: Error, Equatable, Sendable {
    /// The product id is not in the store's catalogue (bad configuration, or offline).
    case productUnavailable(ProductID)
    /// StoreKit could not verify the transaction's signature.
    case unverifiedTransaction
    /// Anything StoreKit itself threw, flattened to a message.
    case storeKit(String)
}

/// The seam between the paywall and StoreKit. `StoreKitEntitlementStore` is the real
/// implementation; `MockEntitlementStore` backs previews, unit tests and `--screenshot`
/// runs so the paywall renders identical prices with no network and no store.
///
/// Conformers are `@Observable` classes on the main actor, so SwiftUI re-renders when
/// `isPremium` or `products` change.
@MainActor
public protocol EntitlementProviding: AnyObject {
    /// True while any product in the subscription group is entitled.
    var isPremium: Bool { get }
    /// The catalogue, in `ProductID.allCases` order. Empty until `load()` has run.
    var products: [StorePlan] { get }
    /// False once the customer has already used the introductory offer for this group,
    /// which is what turns "Redeem 7 days for $0.00" into a plain price.
    var introOfferEligible: Bool { get }

    /// Fetches the catalogue and the current entitlements. Safe to call repeatedly.
    func load() async
    func purchase(_ id: ProductID) async throws -> PurchaseOutcome
    func restore() async throws
}

public extension EntitlementProviding {
    /// The plan for an id, if the catalogue has it.
    func plan(_ id: ProductID) -> StorePlan? {
        products.first { $0.id == id }
    }
}

/// Where "the customer has already been shown the one-time gift offer" is remembered.
/// `UserState` backs this in the app; `InMemoryOneTimeOfferStore` backs tests. It is a
/// protocol rather than a `UserDefaults` call so `Commerce` keeps no dependencies.
@MainActor
public protocol OneTimeOfferStoring: AnyObject {
    var seenOneTimeOffer: Bool { get set }
}

/// Non-persistent conformer for previews, snapshots and tests.
@MainActor
public final class InMemoryOneTimeOfferStore: OneTimeOfferStoring {
    public var seenOneTimeOffer: Bool

    public init(seenOneTimeOffer: Bool = false) {
        self.seenOneTimeOffer = seenOneTimeOffer
    }
}

/// `UserDefaults`-backed conformer, used until `UserState` owns the flag.
@MainActor
public final class DefaultsOneTimeOfferStore: OneTimeOfferStoring {
    public static let key = "commerce.seenOneTimeOffer"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var seenOneTimeOffer: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}
