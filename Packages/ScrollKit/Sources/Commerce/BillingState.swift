import Foundation

/// Where the customer's subscription stands with Apple's billing system.
///
/// This is deliberately *not* the same question as `isPremium`. A subscription in the
/// **grace period** is still entitled — the customer keeps every feature — but the payment
/// has failed and Apple is retrying; a subscription in **billing retry** without a grace
/// period has already lost its entitlement. Both cases want the same nudge ("update your
/// payment method"), and neither is visible from `Transaction.currentEntitlements` alone,
/// which is why `Product.SubscriptionInfo.status(for:)` is read separately.
///
/// The IAP audit flagged the missing renewal-state read: without it the app silently drops
/// a paying customer to the free tier the day their card expires, with nothing on screen
/// explaining why.
public enum BillingState: String, Sendable, Equatable, CaseIterable, Codable {
    /// Never subscribed, or the subscription lapsed long enough ago that StoreKit reports
    /// nothing for the group.
    case notSubscribed
    /// Active and renewing.
    case subscribed
    /// Payment failed; Apple is retrying and access continues until the grace period ends.
    case inGracePeriod
    /// Payment failed with no grace period: access has stopped while Apple retries.
    case inBillingRetry
    /// The subscription ended.
    case expired
    /// Refunded or revoked by Apple.
    case revoked

    /// True while the customer should be asked to fix their payment method.
    public var needsPaymentUpdate: Bool {
        self == .inGracePeriod || self == .inBillingRetry
    }

    /// The banner headline Settings shows, or `nil` when there is nothing to say.
    public var bannerTitle: String? {
        needsPaymentUpdate ? "Update your payment method" : nil
    }

    /// The sentence under the headline. Grace period still has access; billing retry does not.
    public var bannerMessage: String? {
        switch self {
        case .inGracePeriod:
            "We could not renew your subscription. Your access continues for now — update your payment method in the App Store to keep it."
        case .inBillingRetry:
            "We could not renew your subscription, so Premium is paused. Update your payment method in the App Store to restore it."
        default:
            nil
        }
    }

    /// Which state wins when the group reports more than one. Being subscribed beats a
    /// warning; a warning beats a dead subscription.
    var precedence: Int {
        switch self {
        case .notSubscribed: 0
        case .expired: 1
        case .revoked: 2
        case .inBillingRetry: 3
        case .inGracePeriod: 4
        case .subscribed: 5
        }
    }

    /// The more relevant of two states for one subscription group.
    public func combined(with other: BillingState) -> BillingState {
        precedence >= other.precedence ? self : other
    }
}
