import Observation
import SwiftUI

/// Whether the reader has paid for unlimited Discover and Deep Study.
///
/// `FeatureDiscover` does not depend on `Commerce`, so the protocol is declared here and
/// kept deliberately tiny: one boolean. `AppShell` adapts `Commerce.EntitlementProviding`
/// onto it (`DiscoverEntitlementBridge`) and injects the adapter, so there is exactly one
/// entitlement store in the process and this module never learns what StoreKit is.
@MainActor
public protocol EntitlementProviding: AnyObject {
    /// True when the free-tier daily card limit does not apply.
    var isSubscribed: Bool { get }
}

/// The stand-in used by previews, snapshots and tests until StoreKit is wired.
@MainActor
@Observable
public final class MockEntitlementStore: EntitlementProviding {
    public var isSubscribed: Bool

    public init(isSubscribed: Bool = false) {
        self.isSubscribed = isSubscribed
    }
}

private struct EntitlementsKey: EnvironmentKey {
    static let defaultValue: (any EntitlementProviding)? = nil
}

public extension EnvironmentValues {
    /// The active entitlement source. `nil` means "not injected", which the Discover
    /// gate treats as *not* subscribed so the free tier is the safe default.
    var entitlements: (any EntitlementProviding)? {
        get { self[EntitlementsKey.self] }
        set { self[EntitlementsKey.self] = newValue }
    }
}

/// Asking for the paywall.
///
/// Two things in this module are premium: the fourth Discover card of the day, and Deep
/// Study at all. Neither can present the real paywall itself — `FeaturePaywall` is on the
/// other side of the dependency arrow, exactly like `Router` — so the shell hands down a
/// closure and presents `PaywallFlow` over the tab bar when it is called.
public struct RequestPremiumAction: Sendable {
    /// Why the paywall is being raised. The paywall itself is the same screen either way;
    /// the reason exists so the shell can log it and so a caller can tell "wired" from
    /// "wired for something else".
    public enum Reason: String, Sendable, CaseIterable {
        /// The free reader has already opened their three cards today.
        case discoverLimit
        /// Deep Study is premium-only.
        case deepStudy
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

    /// Whether anything is listening. Where nothing is — previews, snapshots, the host
    /// tests — the caller falls back to its own local sheet rather than doing nothing.
    public var isWired: Bool {
        handler != nil
    }
}

private struct RequestPremiumKey: EnvironmentKey {
    static let defaultValue = RequestPremiumAction()
}

public extension EnvironmentValues {
    /// Injected by `AppShell` as `RequestPremiumAction { gate.request($0) }`.
    var requestPremium: RequestPremiumAction {
        get { self[RequestPremiumKey.self] }
        set { self[RequestPremiumKey.self] = newValue }
    }
}
