import Commerce
import DesignSystem
import Observation
import SwiftUI

/// Which paywall surface is on screen.
public enum PaywallStage: String, Sendable, CaseIterable {
    case trial
    case plans
    case giftClosed
    case giftOpen
}

/// Drives the paywall: which surface is up, which plan is selected, and whether a purchase
/// is in flight. The store is injected so previews and `--screenshot` runs can use
/// `MockEntitlementStore`.
@MainActor
@Observable
public final class PaywallModel {
    public private(set) var stage: PaywallStage
    public var selectedPlan: ProductID = .yearly
    public private(set) var isPurchasing = false
    public private(set) var errorMessage: String?
    /// Set when a purchase is waiting on Ask to Buy approval. Nothing is unlocked yet;
    /// the `Transaction.updates` listener finishes the job if the organiser approves.
    public private(set) var pendingMessage: String?

    @ObservationIgnored public let store: any EntitlementProviding
    @ObservationIgnored private let offers: any OneTimeOfferStoring

    public init(
        store: any EntitlementProviding,
        offers: any OneTimeOfferStoring = InMemoryOneTimeOfferStore(),
        stage: PaywallStage = .trial
    ) {
        self.store = store
        self.offers = offers
        self.stage = stage
    }

    public var plans: [StorePlan] {
        store.products
    }

    public var introEligible: Bool {
        store.introOfferEligible
    }

    public var yearly: StorePlan? {
        store.plan(.yearly) ?? StoreCatalogue.yearly
    }

    public var gift: StorePlan? {
        store.plan(.yearlyGift) ?? StoreCatalogue.gift
    }

    /// True once the gift offer has been shown, so it is never offered twice.
    public var seenOneTimeOffer: Bool {
        offers.seenOneTimeOffer
    }

    public func load() async {
        await store.load()
    }

    public func show(_ stage: PaywallStage) {
        self.stage = stage
    }

    /// Dismissing the trial paywall earns the one-time gift offer, once.
    /// Returns `true` when the caller should leave the paywall entirely.
    @discardableResult
    public func dismissTrial() -> Bool {
        guard !offers.seenOneTimeOffer else { return true }
        offers.seenOneTimeOffer = true
        stage = .giftClosed
        return false
    }

    public func purchase(_ id: ProductID) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let outcome = try await store.purchase(id)
            switch outcome {
            case .purchased:
                errorMessage = nil
                pendingMessage = nil
            case .pending:
                errorMessage = nil
                pendingMessage = PaywallCopy.askToBuyPending
            case .cancelled:
                break
            }
            return outcome == .purchased
        } catch let error as CommerceError {
            pendingMessage = nil
            errorMessage = Self.message(for: error)
            return false
        } catch {
            pendingMessage = nil
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func restore() async -> Bool {
        do {
            try await store.restore()
            return store.isPremium
        } catch {
            errorMessage = "We could not reach the App Store. Please try again."
            return false
        }
    }

    static func message(for error: CommerceError) -> String {
        switch error {
        case .productUnavailable:
            "That plan is not available right now."
        case .unverifiedTransaction:
            "We could not verify that purchase."
        case let .storeKit(message):
            message
        }
    }
}

/// The entry point `RootView` presents: the trial paywall, the plans half sheet on top of
/// it, and the one-time gift offer once the paywall is dismissed.
public struct PaywallFlow: View {
    @State private var model: PaywallModel
    @Environment(\.scenePhase) private var scenePhase
    private let onDismiss: () -> Void
    private let onPurchased: () -> Void
    private let links: PaywallLegalLinks

    public init(
        store: any EntitlementProviding,
        offers: any OneTimeOfferStoring = InMemoryOneTimeOfferStore(),
        stage: PaywallStage = .trial,
        links: PaywallLegalLinks = .default,
        onDismiss: @escaping () -> Void,
        onPurchased: @escaping () -> Void
    ) {
        _model = State(initialValue: PaywallModel(store: store, offers: offers, stage: stage))
        self.links = links
        self.onDismiss = onDismiss
        self.onPurchased = onPurchased
    }

    public var body: some View {
        ZStack {
            switch model.stage {
            case .trial, .plans:
                trial
            case .giftClosed, .giftOpen:
                gift
            }
        }
        .task { await model.load() }
        // A subscription can lapse, be refunded or be approved while the app is in the
        // background, and StoreKit does not always redeliver a transaction for that.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.load() }
        }
    }

    private var trial: some View {
        ZStack {
            PaywallTrialView(
                plan: model.yearly,
                introEligible: model.introEligible,
                onClose: {
                    if model.dismissTrial() {
                        onDismiss()
                    }
                },
                onRedeem: { buy(model.selectedPlan) },
                onViewAllPlans: { model.show(.plans) },
                onRestore: { Task {
                    if await model.restore() {
                        onPurchased()
                    }
                } },
                // Injected rather than defaulted, so the composition root owns the real URLs
                // and App Review's live-link requirement (3.1.2(a)) is satisfied by
                // construction rather than by whatever this view happened to hard-code.
                links: links
            )
            // The half sheet takes over: the paywall behind it must not stay in the
            // accessibility tree, or VoiceOver walks straight into unreachable buttons.
            .accessibilityHidden(model.stage == .plans)
            if model.stage == .plans {
                PlansSheet(
                    plans: model.plans,
                    selection: $model.selectedPlan,
                    introEligible: model.introEligible,
                    onRedeem: { buy(model.selectedPlan) },
                    onDismiss: { model.show(.trial) }
                )
            }
        }
    }

    private var gift: some View {
        GiftOfferView(
            plan: model.gift,
            standardPlan: model.yearly,
            introEligible: model.introEligible,
            isOpen: model.stage == .giftOpen,
            onDismiss: onDismiss,
            onPurchase: { buy(.yearlyGift) }
        )
    }

    private func buy(_ id: ProductID) {
        Task {
            if await model.purchase(id) {
                onPurchased()
            }
        }
    }
}

#Preview("Trial") {
    PaywallFlow(store: MockEntitlementStore(), onDismiss: {}, onPurchased: {})
}

#Preview("Plans") {
    PaywallFlow(store: MockEntitlementStore(), stage: .plans, onDismiss: {}, onPurchased: {})
}
