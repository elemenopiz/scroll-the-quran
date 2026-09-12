import Foundation
import Observation

/// `EntitlementProviding` backed by RevenueCat instead of StoreKit directly.
///
/// **Not wired into the app.** `AppShell` still injects `StoreKitEntitlementStore`, and
/// swapping it is a deliberate decision the orchestrator makes once the SDK dependency
/// exists — see `docs/infra/revenuecat.md`. Because it conforms to the same protocol, that
/// swap is one line at the composition root and no change at any call site: the paywall
/// only ever sees `isPremium`, `products`, `introOfferEligible` and `billingState`.
///
/// What this class is responsible for, beyond translation:
///
/// * **The entitlement, not the product, decides `isPremium`.** All three products grant
///   `premium`, so asking "is `premium` active" is right and enumerating product ids is
///   not — a plan added in the dashboard tomorrow unlocks the app with no release.
///   `entitledProductIDs` is kept alongside for the "which plan do they have" question.
/// * **The update stream is held for the object's lifetime**, so a renewal, a refund, an
///   Ask to Buy approval or a purchase made on another device lands without a relaunch.
///   This is the piece that is easy to leave out and impossible to notice in testing.
/// * **Grace period is preserved.** `BillingState.init(entitlement:)` keeps the difference
///   between "paying customer whose card just failed" and "no longer entitled", which
///   `isPremium` alone flattens; Settings raises its banner off `needsPaymentUpdate`.
@MainActor
@Observable
public final class RevenueCatEntitlementStore: EntitlementProviding {
    public private(set) var isPremium = false
    public private(set) var products: [StorePlan] = []
    public private(set) var introOfferEligible = true
    public private(set) var billingState: BillingState = .notSubscribed
    /// Product ids RevenueCat reports as active subscriptions. Not what gates the app —
    /// that is `isPremium` — but it is what Settings shows as "your plan".
    public private(set) var entitledProductIDs: Set<String> = []
    /// The last failure, for the paywall to render. Cleared by the next success.
    public private(set) var lastError: CommerceError?
    /// True once `load()` has completed at least once, successfully or not, so the paywall
    /// can tell "still loading" from "loaded and empty".
    public private(set) var hasLoaded = false

    @ObservationIgnored private let client: any RevenueCatClient
    @ObservationIgnored private var packagesByProductID: [ProductID: RCPackage] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?

    /// - Parameters:
    ///   - client: the SDK wrapper. `StubRevenueCatClient` in tests and previews.
    ///   - apiKey: the RevenueCat **public** SDK key for Apple (`appl_…`), read from
    ///     `Info.plist` at the call site — never a literal here, and never the secret key.
    ///     Empty means "already configured elsewhere", so a second store does not
    ///     reconfigure the SDK.
    ///   - appUserID: `nil` for RevenueCat's anonymous id, which is the default the app
    ///     should keep: Sign in with Apple is optional and `credential.user` must not be
    ///     handed to a third party. See `RevenueCatClient.configure(apiKey:appUserID:)`.
    public init(client: any RevenueCatClient, apiKey: String = "", appUserID: String? = nil) {
        self.client = client
        if !apiKey.isEmpty {
            client.configure(apiKey: apiKey, appUserID: appUserID)
        }
        updates = Task { [weak self] in
            for await info in client.customerInfoUpdates {
                guard let self else { return }
                apply(info)
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Catalogue

    /// Fetches the offering and the current entitlements. Safe to call repeatedly.
    ///
    /// A failure here leaves whatever was already loaded in place rather than blanking the
    /// paywall: an offerings call that times out on a bad connection should not make a
    /// paying customer look unsubscribed.
    public func load() async {
        do {
            let offerings = try await client.offerings()
            if let offering = offerings.paywallOffering {
                var byID: [ProductID: RCPackage] = [:]
                for package in offering.packages {
                    if let id = package.productID {
                        byID[id] = package
                    }
                }
                packagesByProductID = byID
                // ProductID.allCases order, so the paywall's plan sheet is ordered by the
                // app's own catalogue and not by whatever order the dashboard returned.
                products = ProductID.allCases.compactMap { byID[$0].flatMap(StorePlan.init(package:)) }
            }
            lastError = nil
        } catch {
            lastError = Self.flatten(error)
        }

        do {
            apply(try await client.customerInfo())
        } catch {
            lastError = Self.flatten(error)
        }

        await refreshIntroEligibility()
        hasLoaded = true
    }

    // MARK: - Purchasing

    @discardableResult
    public func purchase(_ id: ProductID) async throws -> PurchaseOutcome {
        guard let package = packagesByProductID[id] else {
            // The dashboard's offering does not carry this product. Same symptom as an
            // unavailable StoreKit product, so the paywall gets the same error.
            let error = CommerceError.productUnavailable(id)
            lastError = error
            throw error
        }
        do {
            switch try await client.purchase(package) {
            case let .purchased(info):
                apply(info)
                await refreshIntroEligibility()
                lastError = nil
                return .purchased
            case .pending:
                // Ask to Buy: nothing is unlocked. The entitlement, if it ever arrives,
                // comes through customerInfoUpdates.
                return .pending
            case .cancelled:
                return .cancelled
            }
        } catch {
            let flattened = Self.flatten(error)
            lastError = flattened
            throw flattened
        }
    }

    public func restore() async throws {
        do {
            apply(try await client.restore())
            await refreshIntroEligibility()
            lastError = nil
        } catch {
            let flattened = Self.flatten(error)
            lastError = flattened
            throw flattened
        }
    }

    // MARK: - Entitlements

    /// The one place entitlement state moves, so the stream and the direct calls cannot
    /// drift apart.
    private func apply(_ info: RCCustomerInfo) {
        let premium = info.premium
        isPremium = premium?.isActive ?? false
        billingState = BillingState(entitlement: premium)
        entitledProductIDs = info.activeSubscriptions
    }

    private func refreshIntroEligibility() async {
        // Eligibility is per product; the paywall asks one question ("is the trial on the
        // table"), and the headline yearly plan is the one it asks it about.
        let eligibility = await client.introEligibility(for: [.yearly])
        introOfferEligible = eligibility[.yearly] ?? !isPremium
    }

    /// Everything the paywall can be shown is a `CommerceError`.
    ///
    /// `.storeKit` is the catch-all case even though RevenueCat is not StoreKit: the enum
    /// is part of the frozen `Commerce` surface and its payload is a message, so widening
    /// it would be a breaking change to every call site for no gain on screen. The
    /// customer reads the message, not the case name.
    private static func flatten(_ error: any Error) -> CommerceError {
        switch error {
        case let commerce as CommerceError:
            commerce
        case let RevenueCatError.packageUnavailable(id):
            .productUnavailable(id)
        case RevenueCatError.notConfigured:
            .storeKit("The store is not available right now. Please try again in a moment.")
        case let RevenueCatError.underlying(message):
            .storeKit(message)
        default:
            .storeKit(error.localizedDescription)
        }
    }
}
