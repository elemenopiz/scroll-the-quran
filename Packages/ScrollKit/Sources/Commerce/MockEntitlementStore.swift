import Foundation
import Observation

/// A store with no StoreKit behind it.
///
/// It backs SwiftUI previews, the `--screenshot` snapshot runs (where the real store may
/// not have finished loading, or may not be configured at all) and the unit tests that
/// exercise the paywall's own state machine. `catalogue` mirrors
/// `Config/ScrollTheQuran.storekit` exactly, so the prices on screen match the store.
@MainActor
@Observable
public final class MockEntitlementStore: EntitlementProviding {
    public private(set) var isPremium: Bool
    public private(set) var products: [StorePlan]
    public var introOfferEligible: Bool
    /// Settable so a snapshot, a UI test or a preview can stand the app in the grace period
    /// or in billing retry without a StoreKit session. `nil` means "follow `isPremium`".
    public var forcedBillingState: BillingState?

    /// Set to make `purchase(_:)` report something other than `.purchased`.
    public var nextOutcome: PurchaseOutcome = .purchased
    /// Set to make `purchase(_:)` or `restore()` throw.
    public var nextError: CommerceError?
    /// Set when the customer is meant to *have* a purchase to restore, so `restore()` grants
    /// the entitlement the way `AppStore.sync()` plus a re-read of `currentEntitlements`
    /// would. A StoreKit test store cannot demonstrate this: it never stops returning a
    /// transaction, so there is nothing there for a restore to bring back.
    public var restoreGrantsPremium = false

    public private(set) var purchaseCount = 0
    public private(set) var restoreCount = 0
    public private(set) var loadCount = 0

    public init(
        isPremium: Bool = false,
        products: [StorePlan] = StoreCatalogue.all,
        introOfferEligible: Bool = true,
        billingState: BillingState? = nil
    ) {
        self.isPremium = isPremium
        self.products = products
        self.introOfferEligible = introOfferEligible
        forcedBillingState = billingState
    }

    public var billingState: BillingState {
        forcedBillingState ?? (isPremium ? .subscribed : .notSubscribed)
    }

    public func load() async {
        loadCount += 1
    }

    @discardableResult
    public func purchase(_ id: ProductID) async throws -> PurchaseOutcome {
        purchaseCount += 1
        if let error = nextError {
            throw error
        }
        guard products.contains(where: { $0.id == id }) else {
            throw CommerceError.productUnavailable(id)
        }
        if nextOutcome == .purchased {
            isPremium = true
            introOfferEligible = false
        }
        return nextOutcome
    }

    public func restore() async throws {
        restoreCount += 1
        if let error = nextError {
            throw error
        }
        if restoreGrantsPremium {
            grant()
        }
    }

    /// Test hook: pretend the subscription lapsed.
    public func expire() {
        isPremium = false
        forcedBillingState = .expired
    }

    /// Test hook: pretend the customer's card failed. Grace period keeps access, billing
    /// retry does not — which is exactly the difference Settings has to explain.
    public func enterBillingTrouble(_ state: BillingState) {
        forcedBillingState = state
        isPremium = state == .inGracePeriod
    }

    /// Test hook: grant the entitlement without going through `purchase(_:)`, the way a
    /// restore or a renewal landing on the `Transaction.updates` listener would.
    public func grant() {
        isPremium = true
        forcedBillingState = nil
        introOfferEligible = false
    }

    /// The three products in `Config/ScrollTheQuran.storekit`. Lives on `StoreCatalogue`
    /// so it is reachable from non-isolated contexts such as default argument values.
    public static var catalogue: [StorePlan] {
        StoreCatalogue.all
    }
}
