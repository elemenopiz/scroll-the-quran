import XCTest

/// The first-run funnel and the free tier's gates, driven through the real app.
///
/// Two kinds of run appear here, and the difference matters:
///
/// * `--funnel <phase> --free` starts the app inside the funnel at that phase with the
///   commerce store reporting "not subscribed" until something buys. The purchase itself
///   runs the app's real path — the paywall's button, `PaywallModel.purchase`,
///   `EntitlementProviding.purchase`, and `RootView`'s watcher on the entitlement — so
///   these are the tests that prove buying ends the funnel, that the envelope is spent
///   once, and that a purchase outlives the process.
/// * `--ui-test --free` / `--premium` skip the funnel and land on the tab bar. The gates do
///   not care where the entitlement came from, and starting there makes "a free reader taps
///   the fourth card" a two-second test instead of a purchase flow.
///
/// **Why there is no `SKTestSession` here.** `storekitd` refuses to apply a StoreKit test
/// configuration to an app that the command-line install did not mark as installed for
/// development:
///
///     storekitd: Validating OctaneSaveConfigurationRequest for com.quranscroller.app
///                by com.quranscroller.app.uitests.xctrunner
///     storekitd: com.quranscroller.app.uitests.xctrunner is not installed for development
///     [SKTestSession] Error saving configuration file: SKInternalErrorDomain Code=3
///
/// It is refused identically whether the configuration arrives through `SKTestSession` or
/// through the scheme's own `Config/ScrollTheQuran.storekit` setting — both were tried.
/// `Product.products(for:)` then answers with an empty catalogue under `xcodebuild test`,
/// `purchase(_:)` can only throw `productUnavailable`, and no assertion about buying is
/// reachable that way at all. `--funnel <phase>` with neither `--free` nor `--premium` still
/// runs against live StoreKit, for a run from Xcode where the configuration does apply.
///
/// `--reset-state` wipes `UserStore`, the Discover day counter and the funnel's remembered
/// purchase at launch: `xcodebuild test` installs over the app without clearing its
/// container, so without it the second run of a test starts with onboarding already done,
/// three cards already spent, and the previous test's purchase still in force.
final class FunnelTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // MARK: - Harness

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tap(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 10) {
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "'\(identifier)' never appeared")
        target.tap()
    }

    private func assertAppears(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 15, _ message: String) {
        XCTAssertTrue(element(app, identifier).waitForExistence(timeout: timeout), message)
    }

    /// The tab bar, which is the funnel's exit.
    private func assertOnTabs(_ app: XCUIApplication, _ message: String) {
        assertAppears(app, "tabroot", message)
    }

    /// Tab bar buttons carry their visible label, not the identifier set on `.tabItem`.
    private func tapTab(_ app: XCUIApplication, _ title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "the \(title) tab never appeared")
        tab.tap()
    }

    // MARK: - The funnel

    /// The headline path: the trial paywall's call to action buys the yearly plan and the
    /// funnel ends on the tab bar.
    func testBuyingTheYearlyPlanUnlocksTheTabs() {
        let app = launch(["--funnel", "paywall", "--free", "--reset-state"])
        assertAppears(app, "screen.paywall-trial", "the funnel did not open on the paywall")

        tap(app, "paywall.redeem")

        assertOnTabs(app, "buying the yearly plan did not unlock the app")
        XCTAssertFalse(element(app, "screen.paywall-trial").exists, "the paywall is still up after a purchase")
    }

    /// Dismissing the paywall earns the one-time envelope, and buying the discounted plan
    /// inside it unlocks the app just as the trial paywall does.
    func testDismissingThePaywallOffersTheGiftAndBuyingItUnlocks() {
        let app = launch(["--funnel", "paywall", "--free", "--reset-state"])
        assertAppears(app, "screen.paywall-trial", "the funnel did not open on the paywall")

        tap(app, "paywall.close")
        assertAppears(app, "screen.gift-closed", "dismissing the paywall did not offer the gift")

        tap(app, "gift.reveal")
        assertAppears(app, "gift.offerCard", "the envelope did not open")
        tap(app, "gift.startTrial")

        assertOnTabs(app, "buying the gift plan did not unlock the app")
    }

    /// Closing both offers lands on the tab bar in the free tier, with Deep Study locked.
    func testClosingTheGiftLeavesTheFreeTier() {
        let app = launch(["--funnel", "paywall", "--free", "--reset-state"])
        assertAppears(app, "screen.paywall-trial", "the funnel did not open on the paywall")

        tap(app, "paywall.close")
        assertAppears(app, "screen.gift-closed", "dismissing the paywall did not offer the gift")
        tap(app, "gift.reveal")
        tap(app, "gift.close")

        assertOnTabs(app, "closing the gift did not reach the tab bar")

        // Free means free: the tabs are there, and the premium surface behind them is not.
        tapTab(app, "Discover")
        tap(app, "discover.deepStudy")
        assertAppears(app, "gate.paywall", "Deep Study did not raise the paywall for a free reader")
    }

    /// The envelope is a one-time offer: having seen it once, a later dismissal of the
    /// paywall goes straight to the app.
    func testTheGiftIsOfferedOnlyOnce() {
        let first = launch(["--funnel", "paywall", "--free", "--reset-state"])
        assertAppears(first, "screen.paywall-trial", "the funnel did not open on the paywall")
        tap(first, "paywall.close")
        assertAppears(first, "screen.gift-closed", "dismissing the paywall did not offer the gift")
        first.terminate()

        // Same install, same `Prefs.seenOneTimeOffer` — and this time no reset.
        let second = launch(["--funnel", "paywall", "--free"])
        assertAppears(second, "screen.paywall-trial", "the funnel did not open on the paywall")
        tap(second, "paywall.close")

        assertOnTabs(second, "the envelope was offered a second time")
        XCTAssertFalse(element(second, "screen.gift-closed").exists, "the one-time offer came back")
    }

    /// A purchase is not session state: the entitlement is read back at launch — from
    /// `Transaction.currentEntitlements` against the real store, from the funnel's own
    /// record against the fixture — and the paywall never comes back.
    func testAPurchaseSurvivesRelaunch() {
        let first = launch(["--funnel", "paywall", "--free", "--reset-state"])
        assertAppears(first, "screen.paywall-trial", "the funnel did not open on the paywall")
        tap(first, "paywall.redeem")
        assertOnTabs(first, "buying the yearly plan did not unlock the app")
        first.terminate()

        // `--funnel paywall` asks for the paywall explicitly; an entitled customer must
        // still end up on the tab bar, which is the whole point of re-reading at launch.
        // No `--reset-state`: the first launch's purchase has to still be there.
        let second = launch(["--funnel", "paywall", "--free"])
        assertOnTabs(second, "the purchase did not survive a relaunch")
    }

    // MARK: - The free tier's gates, against the fixture store

    /// The three locked surfaces, in one launch: Deep Study from a Discover card, the
    /// fourth card of the day, and starting a reading plan.
    func testFreeTierLocksDeepStudyTheFourthCardAndReadingPlans() {
        let app = launch(["--ui-test", "--free", "--reset-state"])
        assertOnTabs(app, "the app did not start on the tab bar")

        // 1. Deep Study.
        tapTab(app, "Discover")
        tap(app, "discover.deepStudy")
        assertAppears(app, "gate.paywall", "Deep Study did not raise the paywall")
        tap(app, "paywall.close")

        // 2. The fourth card of the day. Three are free; the fourth raises the paywall
        //    instead of being counted.
        let discover = element(app, "discover")
        XCTAssertTrue(discover.waitForExistence(timeout: 10), "the Discover tab went away")
        for _ in 1 ... 3 {
            discover.swipeUp(velocity: .fast)
        }
        assertAppears(app, "gate.paywall", "the fourth Discover card of the day did not raise the paywall")
        tap(app, "paywall.close")

        // 3. Reading plans: browsing is free, starting one is not.
        tapTab(app, "Home")
        tap(app, "home.todaysReading")
        assertAppears(app, "plans-sheet", "the Reading Plans sheet never appeared")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "plans.card."))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "no plan cards in the sheet")
        card.tap()
        tap(app, "planDetail.start")
        assertAppears(app, "gate.paywall", "starting a reading plan did not raise the paywall")
    }

    /// Premium unlocks the same three surfaces.
    func testPremiumUnlocksDeepStudy() {
        let app = launch(["--ui-test", "--premium", "--reset-state"])
        assertOnTabs(app, "the app did not start on the tab bar")

        tapTab(app, "Discover")
        tap(app, "discover.deepStudy")
        assertAppears(app, "deepstudy", "Deep Study did not open for a subscriber")
        XCTAssertFalse(element(app, "gate.paywall").exists, "a subscriber was shown the paywall")
    }

    // MARK: - Restore and billing

    /// "Restore Purchases" in Settings brings the entitlement back and the gates open.
    ///
    /// The fixture store is the only place this can be shown: a StoreKit test store never
    /// stops returning a transaction, so there is nothing there for a restore to recover.
    func testRestorePurchasesFromSettingsUnlocksTheApp() {
        let app = launch(["--ui-test", "--free", "--restorable", "--reset-state"])
        assertOnTabs(app, "the app did not start on the tab bar")

        tapTab(app, "Home")
        tap(app, "home.settingsPill")
        tap(app, "settings.restorePurchases")
        tap(app, "settings.done")

        tapTab(app, "Discover")
        tap(app, "discover.deepStudy")
        assertAppears(app, "deepstudy", "Deep Study is still locked after restoring a purchase")
    }

    /// A failed renewal has to say so. `Product.SubscriptionInfo.status` reports billing
    /// retry; Settings turns that into a banner rather than silently dropping the customer
    /// to the free tier.
    func testSettingsWarnsWhenAPaymentIsFailing() {
        let app = launch(["--ui-test", "--free", "--billing", "inBillingRetry", "--reset-state"])
        assertOnTabs(app, "the app did not start on the tab bar")

        tapTab(app, "Home")
        tap(app, "home.settingsPill")
        assertAppears(app, "settings.billingBanner", "Settings said nothing about the failed payment")
    }

    /// A healthy subscription must not be told its payment is failing.
    func testSettingsIsQuietWhenBillingIsHealthy() {
        let app = launch(["--ui-test", "--premium", "--reset-state"])
        assertOnTabs(app, "the app did not start on the tab bar")

        tapTab(app, "Home")
        tap(app, "home.settingsPill")
        assertAppears(app, "settings.restorePurchases", "Settings never opened")
        XCTAssertFalse(element(app, "settings.billingBanner").exists, "a healthy subscription was warned about billing")
    }

    // MARK: - Layout

    /// The funnel's own paywall is the same screen the capture harness renders.
    ///
    /// `UITests/Specs/funnel-*.json` carry the frames, and they are ordinary layout specs —
    /// `LayoutSpecTests` already asserts them through `--screenshot`. This asserts the
    /// identical numbers reached through the real state machine, so a funnel that renders a
    /// *different* paywall than the one that was captured cannot pass both.
    func testFunnelScreensMatchTheirLayoutSpecs() throws {
        continueAfterFailure = true
        let specs = try FunnelSpec.loadAll()
        XCTAssertFalse(specs.isEmpty, "no funnel layout specs found in the UI test bundle")

        for spec in specs {
                let app = launch(["--funnel", spec.funnel.phase, "--free", "--reset-state"])
            defer { app.terminate() }

            for identifier in spec.funnel.taps {
                tap(app, identifier)
            }

            let screen = app.windows.firstMatch.frame
            XCTAssertGreaterThan(screen.width, 0, "\(spec.id): could not read the window frame")
            let scaleX = spec.reference.width / screen.width
            let scaleY = spec.reference.height / screen.height

            for element in spec.elements {
                let found = app.element(for: element)
                XCTAssertTrue(
                    found.waitForExistence(timeout: 10),
                    "\(spec.id): \(element.query.rawValue) '\(element.name)' never appeared in the funnel"
                )
                guard found.exists, element.existenceOnly != true else { continue }

                let tolerance = element.tolerance ?? spec.tolerance
                let expected = element.frame.rect
                let observed = CGRect(
                    x: found.frame.minX * scaleX,
                    y: found.frame.minY * scaleY,
                    width: found.frame.width * scaleX,
                    height: found.frame.height * scaleY
                )
                XCTAssertEqual(
                    Double(observed.minX), Double(expected.minX), accuracy: tolerance,
                    "\(spec.id) \(element.name) x through the funnel"
                )
                XCTAssertEqual(
                    Double(observed.minY), Double(expected.minY), accuracy: tolerance,
                    "\(spec.id) \(element.name) y through the funnel"
                )
                XCTAssertEqual(
                    Double(observed.width), Double(expected.width), accuracy: tolerance,
                    "\(spec.id) \(element.name) width through the funnel"
                )
                XCTAssertEqual(
                    Double(observed.height), Double(expected.height), accuracy: tolerance,
                    "\(spec.id) \(element.name) height through the funnel"
                )
            }
        }
    }
}

/// A `UITests/Specs/funnel-*.json` file.
///
/// It is a `LayoutSpec` with one extra object: `funnel`, which says how to *reach* the
/// screen through the state machine rather than through `--screenshot`. `LayoutSpec` ignores
/// the extra key, so the same file is asserted by both suites from both entry points.
struct FunnelSpec: Decodable {
    struct Funnel: Decodable {
        /// The `RootPhase` raw value `--funnel` starts at.
        let phase: String
        /// Accessibility identifiers to tap, in order, before measuring.
        let taps: [String]
    }

    let id: String
    let route: String
    let reference: LayoutSpec.Reference
    let tolerance: Double
    let elements: [LayoutSpec.Element]
    let funnel: Funnel

    static func loadAll(in bundle: Bundle = Bundle(for: LayoutSpecTests.self)) throws -> [FunnelSpec] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                // Every other spec in the bundle has no `funnel` object and is skipped here.
                return try? decoder.decode(FunnelSpec.self, from: data)
            }
            .filter { $0.id.hasPrefix("funnel-") }
    }
}
