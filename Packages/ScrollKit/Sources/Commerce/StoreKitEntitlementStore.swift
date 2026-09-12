import Foundation
import Observation
import StoreKit

/// The live StoreKit 2 store.
///
/// * `Product.products(for:)` loads the catalogue.
/// * `Transaction.currentEntitlements` decides `isPremium`.
/// * A `Transaction.updates` listener started in `init` catches renewals, refunds,
///   Ask to Buy approvals and purchases made on another device.
/// * Every verified transaction is finished exactly once, after the entitlement set
///   has been refreshed.
@MainActor
@Observable
public final class StoreKitEntitlementStore: EntitlementProviding {
    public private(set) var isPremium: Bool = false
    public private(set) var products: [StorePlan] = []
    public private(set) var introOfferEligible: Bool = true
    /// The subscription group's renewal state, read from `Product.SubscriptionInfo.status`.
    /// Grace period and billing retry are invisible to `currentEntitlements`, so they are
    /// asked for separately and surfaced to Settings as a "update your payment method" banner.
    public private(set) var billingState: BillingState = .notSubscribed
    /// The last error `load()`, `purchase(_:)` or `restore()` hit, for the paywall to show.
    public private(set) var lastError: CommerceError?

    /// Product ids that are currently entitled, in no particular order.
    public private(set) var entitledProductIDs: Set<String> = []

    @ObservationIgnored private var storeProducts: [ProductID: Product] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?

    public init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await handle(result)
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Catalogue

    public func load() async {
        do {
            let fetched = try await Product.products(for: ProductID.allRawValues)
            var byID: [ProductID: Product] = [:]
            for product in fetched {
                if let id = ProductID(rawValue: product.id) {
                    byID[id] = product
                }
            }
            storeProducts = byID
            products = ProductID.allCases.compactMap { byID[$0].map(StorePlan.init(product:)) }
            lastError = nil
        } catch {
            lastError = .storeKit(error.localizedDescription)
        }
        await refreshEntitlements()
        await refreshIntroEligibility()
    }

    // MARK: - Purchasing

    @discardableResult
    public func purchase(_ id: ProductID) async throws -> PurchaseOutcome {
        guard let product = storeProducts[id] else {
            let error = CommerceError.productUnavailable(id)
            lastError = error
            throw error
        }
        do {
            switch try await product.purchase() {
            case let .success(verification):
                let transaction = try Self.verified(verification)
                await refreshEntitlements()
                await transaction.finish()
                await refreshIntroEligibility()
                lastError = nil
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch let error as CommerceError {
            lastError = error
            throw error
        } catch {
            let wrapped = CommerceError.storeKit(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            let wrapped = CommerceError.storeKit(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
        await refreshEntitlements()
        await refreshIntroEligibility()
    }

    // MARK: - Entitlements

    /// Recomputes `isPremium` from `Transaction.currentEntitlements`, skipping anything
    /// unverified, revoked or already expired.
    public func refreshEntitlements() async {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.revocationDate == nil
            else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() {
                continue
            }
            entitled.insert(transaction.productID)
        }
        entitledProductIDs = entitled
        isPremium = ProductID.allRawValues.contains { entitled.contains($0) }
        await refreshBillingState()
    }

    /// Reads the subscription group's renewal state.
    ///
    /// `Transaction.currentEntitlements` answers "may they use it"; it cannot tell a healthy
    /// subscription from one whose card just failed. `Product.SubscriptionInfo.status(for:)`
    /// is the only API that reports `.inGracePeriod` and `.inBillingRetryPeriod`, and both
    /// deserve the same nudge before the customer silently loses access.
    ///
    /// Unverified statuses are ignored the same way unverified transactions are.
    private func refreshBillingState() async {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: ProductID.subscriptionGroupID)
            var state: BillingState = .notSubscribed
            for status in statuses {
                guard case .verified = status.renewalInfo, case .verified = status.transaction else { continue }
                state = state.combined(with: BillingState(status.state))
            }
            billingState = state
        } catch {
            // No StoreKit configuration, or the store is unreachable: fall back to what the
            // entitlement set already told us rather than inventing a warning.
            billingState = isPremium ? .subscribed : .notSubscribed
        }
    }

    private func refreshIntroEligibility() async {
        guard let subscription = storeProducts[.yearly]?.subscription else {
            introOfferEligible = !isPremium
            return
        }
        introOfferEligible = await subscription.isEligibleForIntroOffer
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
        await refreshIntroEligibility()
    }

    static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value): value
        case .unverified: throw CommerceError.unverifiedTransaction
        }
    }
}

// MARK: - Flattening StoreKit

extension StorePlan {
    /// Builds the paywall's view of a StoreKit product.
    init(product: Product) {
        let id = ProductID(rawValue: product.id) ?? .yearly
        let period: BillingPeriod = product.subscription?.subscriptionPeriod.unit == .month ? .month : .year
        var intro: IntroOffer?
        if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            intro = IntroOffer(freeDays: StorePlan.days(in: offer.period))
        }
        self.init(
            id: id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            price: product.price,
            currencyCode: product.priceFormatStyle.currencyCode,
            period: period,
            introOffer: intro
        )
    }

    /// `P1W` -> 7, `P3D` -> 3, `P1M` -> 30.
    static func days(in period: Product.SubscriptionPeriod) -> Int {
        let perUnit = switch period.unit {
        case .day: 1
        case .week: 7
        case .month: 30
        case .year: 365
        @unknown default: 1
        }
        return perUnit * period.value
    }
}

// MARK: - Renewal state

extension BillingState {
    /// Maps StoreKit's `RenewalState` onto the app's own vocabulary.
    init(_ state: Product.SubscriptionInfo.RenewalState) {
        switch state {
        case .subscribed: self = .subscribed
        case .inGracePeriod: self = .inGracePeriod
        case .inBillingRetryPeriod: self = .inBillingRetry
        case .expired: self = .expired
        case .revoked: self = .revoked
        default: self = .notSubscribed
        }
    }
}
