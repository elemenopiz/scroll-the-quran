import Commerce
import FeatureDiscover
import FeatureHome
import Foundation
import Observation

/// Why the paywall was raised from inside the app, rather than as part of the first-run
/// funnel. The screen is the same either way; the reason is what a test asserts on and
/// what the accessibility identifier carries, so a failure says *which* gate fired.
public enum PremiumReason: String, Sendable, CaseIterable {
    /// The free reader has already opened `DiscoverGate.freeCardsPerDay` cards today.
    case discoverLimit
    /// Deep Study, from the Discover card's "Deep study >".
    case deepStudy
    /// Deep Study, from Home's Verse Search.
    case verseSearch
    /// Starting or continuing a reading plan.
    case readingPlan
}

/// The one place that decides whether the in-app paywall is up.
///
/// Every locked surface hands its module's own seam a reason; the seams all land here, and
/// `TabRoot` presents `PaywallFlow` over the tab bar when `reason` is non-nil. Keeping it
/// in one observable object rather than four `@State` booleans means two gates cannot fight
/// over the same sheet slot, and the funnel's paywall and the gate's paywall are the same
/// view with the same store behind them.
@MainActor
@Observable
public final class PremiumGate {
    /// Non-nil while the paywall should be on screen.
    public private(set) var reason: PremiumReason?
    /// Every reason raised this session, oldest first. Diagnostics only.
    public private(set) var history: [PremiumReason] = []

    @ObservationIgnored private let isPremium: () -> Bool

    /// - Parameter isPremium: asked before raising anything, so a race between a purchase
    ///   landing on the `Transaction.updates` listener and a tap on a locked control cannot
    ///   show a paywall to somebody who has just paid.
    public init(isPremium: @escaping () -> Bool = { false }) {
        self.isPremium = isPremium
    }

    public func request(_ reason: PremiumReason) {
        guard !isPremium() else { return }
        history.append(reason)
        self.reason = reason
    }

    public func dismiss() {
        reason = nil
    }

    // MARK: - Feature seams

    /// The action `FeatureDiscover` reads out of its environment.
    public var discoverRequest: RequestPremiumAction {
        RequestPremiumAction { [weak self] reason in
            self?.request(PremiumReason(reason))
        }
    }

    /// The action `FeatureHome` is handed through `HomeEnvironment`.
    public var homeRequest: HomePremiumRequest {
        HomePremiumRequest { [weak self] reason in
            self?.request(PremiumReason(reason))
        }
    }
}

extension PremiumReason {
    init(_ reason: RequestPremiumAction.Reason) {
        switch reason {
        case .discoverLimit: self = .discoverLimit
        case .deepStudy: self = .deepStudy
        }
    }

    init(_ reason: HomePremiumRequest.Reason) {
        switch reason {
        case .readingPlan: self = .readingPlan
        case .verseSearch: self = .verseSearch
        }
    }
}

extension PaymentIssue {
    /// The `FeatureHome` half of `Commerce.BillingState`. Only the two states worth a banner
    /// cross the seam; everything else is `nil` and Settings says nothing.
    init?(_ state: BillingState) {
        switch state {
        case .inGracePeriod: self = .gracePeriod
        case .inBillingRetry: self = .billingRetry
        default: return nil
        }
    }
}
