import Commerce
import SwiftUI

/// Routing seam for `--screenshot <id>` and for `RootView`.
///
/// `AppShell` maps a `ScreenID` raw value onto one of these so the composition root never
/// needs to know about `PaywallStage`. Passing a `MockEntitlementStore` renders the exact
/// prices from `Config/ScrollTheQuran.storekit` with no store round-trip, which is what
/// the snapshot harness wants.
public enum PaywallScreens {
    /// The four screen ids this feature owns, matching `Reference/manifest.json`.
    public static let screenIDs = ["paywall-trial", "paywall-plans", "gift-closed", "gift-open"]

    public static func stage(forScreenID id: String) -> PaywallStage? {
        switch id {
        case "paywall-trial": .trial
        case "paywall-plans": .plans
        case "gift-closed": .giftClosed
        case "gift-open": .giftOpen
        default: nil
        }
    }

    /// The flow rooted at the screen behind `id`, or `nil` when the id is not ours.
    @MainActor @ViewBuilder
    public static func view(
        forScreenID id: String,
        store: any EntitlementProviding,
        offers: any OneTimeOfferStoring,
        onDismiss: @escaping () -> Void,
        onPurchased: @escaping () -> Void
    ) -> some View {
        if let stage = stage(forScreenID: id) {
            PaywallFlow(
                store: store,
                offers: offers,
                stage: stage,
                onDismiss: onDismiss,
                onPurchased: onPurchased
            )
        }
    }
}
