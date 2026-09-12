import Commerce
import Foundation

/// Everything the process environment tells the app about how it was started.
/// Parsed once in `RootView` so screenshots and UI tests are deterministic.
public struct LaunchOptions: Equatable, Sendable {
    /// Set by `--screenshot <id>`: route straight to that screen with fixture data.
    public let screenshot: ScreenRoute?
    /// Set by `SCROLL_FIXED_DATE=2026-09-14`: pins "today" so streaks and feeds are stable.
    public let fixedDate: Date?
    /// Set by `--ui-test`: skip the first-run funnel and use fixture commerce, so a test
    /// that is not about onboarding starts on the tab bar.
    public let isUITest: Bool
    /// Set by `--open-url <url>`: the deep link to replay at launch. The UI tests use it
    /// where they cannot reach `simctl openurl`; the real entry point is `onOpenURL`.
    public let openURL: URL?
    /// Set by `--funnel [phase]`: run the first-run funnel against **live StoreKit** (the
    /// scheme's `Config/ScrollTheQuran.storekit`), starting at `phase`. This is how the
    /// funnel tests buy a real test transaction; without it a UI-test run uses fixture
    /// commerce and skips straight to the tab bar.
    public let funnelPhase: RootPhase?
    /// Set by `--reset-state`: wipe `UserStore` and the Discover day counter at launch, so
    /// a funnel or gating test starts from a genuinely fresh install.
    public let resetState: Bool
    /// Set by `--premium` / `--free`: what `MockEntitlementStore` should report. `nil` under
    /// fixture commerce means premium — a capture and a test that is not about gating want
    /// the unlocked app.
    public let forcedEntitlement: Bool?
    /// Set by `--billing <state>`: what `MockEntitlementStore` should report as the
    /// subscription group's renewal state, so a UI test can stand the app in billing retry
    /// without waiting out a simulated renewal.
    public let forcedBillingState: BillingState?
    /// Set by `--restorable`: the fixture store has a purchase waiting to be restored, so
    /// "Restore Purchases" unlocks the app. A StoreKit test store cannot express this — it
    /// never forgets a transaction — so the fixture is the only place to test the wiring.
    public let hasRestorablePurchase: Bool
    /// Set by `--purchase-outcome <success|cancelled|failed|pending|stalled>`: what the
    /// fixture store's `purchase(_:)` does. The paywall has a different thing to say for
    /// each, and before Phase 4d it said none of them (audit finding IAP-1), so each one
    /// needs a way to be stood up from a launch argument.
    public let purchaseOutcome: FixturePurchaseOutcome?

    public init(
        screenshot: ScreenRoute? = nil,
        fixedDate: Date? = nil,
        isUITest: Bool = false,
        openURL: URL? = nil,
        funnelPhase: RootPhase? = nil,
        resetState: Bool = false,
        forcedEntitlement: Bool? = nil,
        forcedBillingState: BillingState? = nil,
        hasRestorablePurchase: Bool = false,
        purchaseOutcome: FixturePurchaseOutcome? = nil
    ) {
        self.screenshot = screenshot
        self.fixedDate = fixedDate
        self.isUITest = isUITest
        self.openURL = openURL
        self.funnelPhase = funnelPhase
        self.resetState = resetState
        self.forcedEntitlement = forcedEntitlement
        self.forcedBillingState = forcedBillingState
        self.hasRestorablePurchase = hasRestorablePurchase
        self.purchaseOutcome = purchaseOutcome
    }

    public init(arguments: [String], environment: [String: String]) {
        screenshot = LaunchOptions.value(of: "--screenshot", in: arguments).flatMap(ScreenRoute.init(rawValue:))
        isUITest = arguments.contains("--ui-test")
        openURL = LaunchOptions.value(of: "--open-url", in: arguments).flatMap(URL.init(string:))
        resetState = arguments.contains("--reset-state")
        if arguments.contains("--funnel") {
            // `--funnel` on its own starts at the hook; `--funnel paywall` skips the seven
            // onboarding taps a test that is about the paywall does not need to repeat.
            funnelPhase = LaunchOptions.value(of: "--funnel", in: arguments)
                .flatMap(RootPhase.init(rawValue:)) ?? .onboarding
        } else {
            funnelPhase = nil
        }
        hasRestorablePurchase = arguments.contains("--restorable")
        forcedBillingState = LaunchOptions.value(of: "--billing", in: arguments)
            .flatMap(BillingState.init(rawValue:))
        purchaseOutcome = LaunchOptions.value(of: "--purchase-outcome", in: arguments)
            .flatMap(FixturePurchaseOutcome.init(rawValue:))
        if arguments.contains("--premium") {
            forcedEntitlement = true
        } else if arguments.contains("--free") {
            forcedEntitlement = false
        } else {
            forcedEntitlement = nil
        }

        if let raw = environment["SCROLL_FIXED_DATE"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd"
            fixedDate = formatter.date(from: raw)
        } else {
            fixedDate = nil
        }
    }

    /// The value following `flag`, or nil when the flag is absent, last, or followed by
    /// another flag — `--funnel --reset-state` must not read "--reset-state" as a phase.
    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else { return nil }
        let value = arguments[next]
        return value.hasPrefix("--") ? nil : value
    }

    /// True when the app is being driven headlessly for a snapshot.
    public var isSnapshotRun: Bool {
        screenshot != nil
    }

    /// Snapshots and UI tests get `MockEntitlementStore` instead of live StoreKit: a
    /// capture has to quote the same prices every time, with no store round-trip.
    ///
    /// Inside the funnel the choice is explicit rather than implied. `--funnel <phase>` on
    /// its own runs against live StoreKit and the scheme's `Config/ScrollTheQuran.storekit`,
    /// which is what a run from Xcode wants; adding `--free` or `--premium` says "the store
    /// reports this", and that answer can only come from the fixture. `xcodebuild test` from
    /// the command line has to take the second road: `storekitd` refuses to apply a StoreKit
    /// test configuration — `SKTestSession` and the scheme's own setting both — to an app the
    /// command-line install did not mark as installed for development, so the catalogue comes
    /// back empty there and no purchase is possible at all. See `UITests/FunnelTests.swift`.
    public var usesFixtureCommerce: Bool {
        if funnelPhase != nil {
            return forcedEntitlement != nil
        }
        return isSnapshotRun || isUITest
    }

    /// True when a fixture purchase has to outlive the process.
    ///
    /// Only the funnel needs it — "a purchase survives a relaunch" is one of its tests — and
    /// letting it leak into `--ui-test` runs would carry one test's purchase into the next.
    public var fixtureRemembersPurchases: Bool {
        funnelPhase != nil && usesFixtureCommerce
    }

    /// What `MockEntitlementStore` reports under fixture commerce. Premium unless `--free`
    /// asks for the free tier: every existing capture and UI test predates the gates and
    /// expects the unlocked app, and a test about gating says so explicitly.
    public var fixtureIsPremium: Bool {
        forcedEntitlement ?? true
    }

    /// True when the first-run funnel should be skipped regardless of stored preferences.
    /// `--funnel` wins: it exists precisely to sit in the funnel.
    public var startsOnTabs: Bool {
        funnelPhase == nil && (isUITest || openURL != nil)
    }

    public static let live = LaunchOptions(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )
}
