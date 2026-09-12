import Foundation

/// What Home is allowed to unlock, and what it has to say about the customer's billing.
///
/// `FeatureHome` does not depend on `Commerce` — it never learns what StoreKit is — so the
/// entitlement crosses the seam as this value and the paywall crosses it as a closure,
/// exactly the way `HomeNavigation` already carries navigation.
///
/// `isPremium` defaults to **true**. A preview, a `--screenshot` capture and a host test all
/// want the unlocked screen, and defaulting the other way would mean a forgotten wiring
/// silently locks a paying customer out of a plan they bought. The app always passes the
/// real value, and `AppShell`'s tests assert that it does.
public struct HomePremiumStatus: Sendable, Equatable {
    public var isPremium: Bool
    /// Set while Apple is retrying a failed payment, which Settings explains in a banner.
    public var paymentIssue: PaymentIssue?

    public init(isPremium: Bool = true, paymentIssue: PaymentIssue? = nil) {
        self.isPremium = isPremium
        self.paymentIssue = paymentIssue
    }

    /// Everything unlocked, nothing to warn about — the default for previews and captures.
    public static let unlocked = HomePremiumStatus(isPremium: true)
    /// The free tier.
    public static let free = HomePremiumStatus(isPremium: false)
}

/// A billing problem worth telling the customer about, flattened out of
/// `Commerce.BillingState` so this module keeps no dependency on it.
public enum PaymentIssue: String, Sendable, Equatable, CaseIterable {
    /// Payment failed; access continues while Apple retries.
    case gracePeriod
    /// Payment failed with no grace period: Premium is paused.
    case billingRetry

    public var title: String {
        "Update your payment method"
    }

    public var message: String {
        switch self {
        case .gracePeriod:
            "We could not renew your subscription. Your access continues for now — update your payment method in the App Store to keep it."
        case .billingRetry:
            "We could not renew your subscription, so Premium is paused. Update your payment method in the App Store to restore it."
        }
    }
}

/// Raising the paywall from Home.
///
/// Two surfaces here are premium: starting a reading plan, and Verse Search's "Study This
/// Verse", which opens Deep Study. Neither can present `PaywallFlow` itself, so the shell
/// hands down a closure. `nil` — a preview, a capture, a host test — makes the control
/// inert rather than unlocking it, the same convention `navigation` already uses.
public struct HomePremiumRequest: Sendable {
    /// Which locked surface was tapped. The paywall is the same screen either way; the
    /// reason is what the shell logs and what a test asserts on.
    public enum Reason: String, Sendable, CaseIterable {
        case readingPlan
        case verseSearch
    }

    public typealias Handler = @MainActor @Sendable (Reason) -> Void

    private let handler: Handler?

    public init(_ handler: Handler? = nil) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction(_ reason: Reason) {
        handler?(reason)
    }

    public var isWired: Bool {
        handler != nil
    }
}
