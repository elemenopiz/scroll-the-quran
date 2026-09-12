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
    public private(set) var isRestoring = false
    /// The one thing the paywall has to say back — a failure, an Ask to Buy approval that
    /// has not landed yet, a cancellation, a restore that found nothing. There is exactly
    /// one, because two of these can never be true at once and the views only have room
    /// for one line (audit IAP-1).
    public private(set) var notice: PaywallNotice?

    /// The failure half of `notice`, kept as its own name because that is what the audit,
    /// the tests and `PaywallModelTests` all talk about.
    public var errorMessage: String? {
        if case let .error(text) = notice { return text }
        return nil
    }

    /// Set when a purchase is waiting on Ask to Buy approval. Nothing is unlocked yet;
    /// the `Transaction.updates` listener finishes the job if the organiser approves.
    public var pendingMessage: String? {
        if case let .pending(text) = notice { return text }
        return nil
    }

    /// True while either a purchase or a restore is in flight. Every call to action on
    /// every paywall surface is disabled and spinning while it is.
    public var isBusy: Bool {
        isPurchasing || isRestoring
    }

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

    /// Clears whatever the last attempt left on screen. The banner's own close button and
    /// the next attempt both go through here, so a stale message cannot outlive its cause.
    public func dismissNotice() {
        notice = nil
    }

    public func purchase(_ id: ProductID) async -> Bool {
        guard !isBusy else { return false }
        isPurchasing = true
        notice = nil
        defer { isPurchasing = false }
        do {
            let outcome = try await store.purchase(id)
            switch outcome {
            case .purchased:
                notice = nil
            case .pending:
                notice = .pending(PaywallCopy.askToBuyPending)
            case .cancelled:
                // Not an error, but not silence either: "the button did nothing" is the
                // rejection this whole finding is about.
                notice = .info(PaywallCopy.purchaseCancelled)
            }
            return outcome == .purchased
        } catch let error as CommerceError {
            notice = .error(Self.message(for: error))
            return false
        } catch {
            notice = .error(error.localizedDescription)
            return false
        }
    }

    public func restore() async -> Bool {
        guard !isBusy else { return false }
        isRestoring = true
        notice = nil
        defer { isRestoring = false }
        do {
            try await store.restore()
            if store.isPremium {
                return true
            }
            // `AppStore.sync()` succeeded and came back with nothing. Silence here reads as
            // a broken button to a customer who is certain they already paid.
            notice = .info(PaywallCopy.nothingToRestore)
            return false
        } catch {
            notice = .error(PaywallCopy.restoreFailed)
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
    /// Where VoiceOver's cursor belongs after a stage change.
    ///
    /// Audit A11Y-3: `PlansSheet` and `GiftOfferView` are drawn into this `ZStack` rather
    /// than presented with `.sheet`/`.fullScreenCover` — deliberate, so the snapshot routes
    /// render synchronously — and the cost is that SwiftUI posts no screen-changed
    /// notification. A VoiceOver user's cursor stayed on the screen that had just gone
    /// away, and might never discover the gift offer existed.
    @AccessibilityFocusState private var focusedStage: PaywallStage?
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
        .onChange(of: model.stage) { _, stage in
            // Both halves matter: the notification tells VoiceOver the context changed at
            // all, and the focus state says *where* to land rather than leaving it to
            // whatever SwiftUI decides is first.
            AccessibilityNotification.ScreenChanged().post()
            focusedStage = stage
        }
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
                links: links,
                // The half sheet carries its own copy of the banner, so the screen behind
                // it must not draw a second one into the dimmed band.
                notice: model.stage == .trial ? model.notice : nil,
                isBusy: model.isBusy,
                onDismissNotice: model.dismissNotice
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
                    onDismiss: { model.show(.trial) },
                    focus: $focusedStage,
                    notice: model.notice,
                    isBusy: model.isBusy,
                    onDismissNotice: model.dismissNotice
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
            onPurchase: { buy(.yearlyGift) },
            // The gift screen is an independent purchase surface for a real auto-renewing
            // subscription, so it carries its own Terms, Privacy and Restore — a reviewer
            // who lands here never passes the trial paywall's footer (audit IAP-2).
            onRestore: { Task {
                if await model.restore() {
                    onPurchased()
                }
            } },
            links: links,
            focus: $focusedStage,
            notice: model.notice,
            isBusy: model.isBusy,
            onDismissNotice: model.dismissNotice
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
