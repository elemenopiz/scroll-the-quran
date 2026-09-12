import XCTest

/// End-to-end checks for the paywall and the gift offer, driven through `--screenshot`.
///
/// The app renders these screens from `Config/ScrollTheQuran.storekit` (the scheme's
/// StoreKit configuration), so asserting on the price strings here is the app-hosted
/// half of the commerce tests: it proves the catalogue reaches the UI.
///
/// `RootView` routes every paywall and gift screen (Phase 3e), so `launch` asserts the
/// screen appeared rather than skipping when it does not.
final class PaywallTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ screen: String) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", screen]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        let root = app.descendants(matching: .any).matching(identifier: "screen.\(screen)").firstMatch
        XCTAssertTrue(
            root.waitForExistence(timeout: 8),
            "--screenshot \(screen) did not render 'screen.\(screen)'"
        )
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testTrialPaywallShowsStoreKitPrices() throws {
        let app = try launch("paywall-trial")
        XCTAssertTrue(element(app, "paywall.headline").exists)
        XCTAssertEqual(element(app, "paywall.price").label, "$29.99/year")
        XCTAssertEqual(element(app, "paywall.priceNote").label, "($2.49/mo)")
        XCTAssertEqual(element(app, "paywall.redeem").label, "Redeem 7 days for $0.00")
        XCTAssertTrue(element(app, "paywall.viewAllPlans").exists)
        XCTAssertTrue(element(app, "paywall.legal.3").exists, "Restore Purchases must be reachable")
        for step in ["today", "day5", "day7"] {
            XCTAssertTrue(element(app, "paywall.step.\(step)").exists, "missing timeline step \(step)")
        }
    }

    func testViewAllPlansOpensTheHalfSheet() throws {
        let app = try launch("paywall-trial")
        element(app, "paywall.viewAllPlans").tap()
        let yearly = element(app, "paywall.plans.card.com.scrollthequran.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 4))
        XCTAssertTrue(element(app, "paywall.plans.card.com.scrollthequran.monthly").exists)
        XCTAssertTrue(element(app, "paywall.plans.saveBadge").exists)
    }

    func testPlansSheetQuotesBothPlans() throws {
        let app = try launch("paywall-plans")
        let yearly = element(app, "paywall.plans.card.com.scrollthequran.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 4))
        XCTAssertTrue(yearly.label.contains("$29.99/year"), "yearly card label was '\(yearly.label)'")
        XCTAssertTrue(yearly.label.contains("$0.00/week"), "yearly card label was '\(yearly.label)'")
        let monthly = element(app, "paywall.plans.card.com.scrollthequran.monthly")
        XCTAssertTrue(monthly.label.contains("$4.99/month"), "monthly card label was '\(monthly.label)'")
        XCTAssertTrue(monthly.label.contains("$1.15/week"), "monthly card label was '\(monthly.label)'")
        XCTAssertEqual(element(app, "paywall.plans.saveBadge").label, "SAVE 50%")
    }

    func testTappingTheSealedEnvelopeRevealsTheOffer() throws {
        let app = try launch("gift-closed")
        XCTAssertTrue(element(app, "gift.headline").exists)
        element(app, "gift.reveal").tap()
        XCTAssertTrue(element(app, "gift.offerCard").waitForExistence(timeout: 4))
        XCTAssertTrue(element(app, "gift.startTrial").exists)
    }

    func testGiftOfferQuotesTheDiscountedPlan() throws {
        let app = try launch("gift-open")
        XCTAssertTrue(element(app, "gift.lucky").exists)
        let price = element(app, "gift.price")
        XCTAssertTrue(price.label.contains("$19.99"), "price row label was '\(price.label)'")
        XCTAssertTrue(price.label.contains("$29.99"), "price row label was '\(price.label)'")
        XCTAssertEqual(element(app, "gift.startTrial").label, "Start FREE trial")
        XCTAssertTrue(element(app, "gift.footnote").label.contains("3 days free, then $19.99/year"))
        XCTAssertTrue(element(app, "gift.close").exists)
    }
}
