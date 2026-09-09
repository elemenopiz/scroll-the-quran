import Observation
import SwiftUI

/// Whether the reader has paid for unlimited Discover.
///
/// `Commerce` does not export an entitlement type yet (it is still the Phase 1 marker
/// module, and `FeatureDiscover` does not depend on it), so the protocol is declared
/// here and kept deliberately tiny: one boolean. When `Commerce.EntitlementStore` lands,
/// AppShell conforms it to this protocol and injects it — nothing in this module changes.
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
