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
