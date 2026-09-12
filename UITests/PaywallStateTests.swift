import XCTest

/// The purchase states the customer is allowed to see, driven through the real app.
///
/// Audit finding IAP-1 was not that `PaywallModel` computed the wrong thing — every model
/// transition was already unit-tested — but that **no view read any of it**. A declined
/// card, a parental-controls block and a restore that found nothing all looked identical:
/// the button stopped responding and nothing appeared. Only a test that goes through the
/// view can catch that, which is what this file is.
///
/// Each case is stood up with `--purchase-outcome <case>`, which poses
/// `MockEntitlementStore` (`Commerce.FixturePurchaseOutcome`). `--free` matters: without it
/// the fixture is born premium and a restore succeeds instead of finding nothing.
final class PaywallStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Harness

    private func launch(_ screen: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", screen, "--free", "--reset-state"] + extra
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        XCTAssertTrue(
            element(app, "screen.\(screen)").waitForExistence(timeout: 10),
            "--screenshot \(screen) did not render 'screen.\(screen)'"
        )
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The banner's text, once it exists.
    private func noticeText(_ app: XCUIApplication, _ message: String) -> String {
        let text = element(app, "paywall.notice.text")
        XCTAssertTrue(text.waitForExistence(timeout: 8), message)
        return text.label
    }

    // MARK: - Purchase outcomes

    func testAFailedPurchaseTellsTheCustomerWhy() {
        let app = launch("paywall-trial", ["--purchase-outcome", "failed"])
        element(app, "paywall.redeem").tap()
        XCTAssertEqual(
            noticeText(app, "a failed purchase left nothing on screen"),
            "We could not complete that purchase. Check your payment method and try again."
        )
    }

    func testACancelledPurchaseSaysSoWithoutSoundingLikeAFailure() {
        let app = launch("paywall-trial", ["--purchase-outcome", "cancelled"])
        element(app, "paywall.redeem").tap()
        let text = noticeText(app, "a cancelled purchase left nothing on screen")
        XCTAssertTrue(text.contains("cancelled"), "notice read '\(text)'")
        XCTAssertTrue(text.contains("not been charged"), "notice read '\(text)'")
    }

    func testAskToBuyExplainsThatApprovalIsPending() {
        let app = launch("paywall-trial", ["--purchase-outcome", "pending"])
        element(app, "paywall.redeem").tap()
        XCTAssertEqual(
            noticeText(app, "an Ask to Buy purchase left nothing on screen"),
            "Ask your family organiser to approve this purchase."
        )
    }

    /// `stalled` never answers, so the in-flight state stays up long enough to assert on.
    func testAPurchaseInFlightDisablesTheCallToAction() {
        let app = launch("paywall-trial", ["--purchase-outcome", "stalled"])
        let redeem = element(app, "paywall.redeem")
        XCTAssertTrue(redeem.isEnabled, "the call to action started out disabled")
        redeem.tap()

        // The button is the thing that must stop responding — before this fix a second tap
        // opened a second StoreKit sheet and nothing on screen said the first was working.
        let disabled = expectation(for: NSPredicate(format: "isEnabled == false"), evaluatedWith: redeem)
        XCTAssertEqual(
            XCTWaiter().wait(for: [disabled], timeout: 8), .completed,
            "the call to action stayed tappable while a purchase was in flight"
        )
        XCTAssertTrue(app.activityIndicators.firstMatch.exists, "no spinner while purchasing")
        XCTAssertFalse(element(app, "paywall.notice").exists, "an in-flight purchase is not a message")
    }

    /// The banner is positioned by hand (`PaywallMetrics.noticeTop`) into the one band the
    /// reference leaves empty, so "does it land on the price" is a real question and the
    /// answer belongs in a test rather than in someone's eye.
    func testTheBannerClearsTheTimelineAndTheFooter() {
        let app = launch("paywall-trial", ["--purchase-outcome", "failed"])
        element(app, "paywall.redeem").tap()
        let notice = element(app, "paywall.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 8))

        let lastStep = element(app, "paywall.step.day7").frame
        let noPayment = element(app, "paywall.noPaymentDueNow").frame
        let banner = notice.frame
        XCTAssertGreaterThanOrEqual(
            banner.minY, lastStep.maxY,
            "the banner overlaps the last timeline step"
        )
        XCTAssertLessThanOrEqual(
            banner.maxY, noPayment.minY,
            "the banner overlaps the footer's price block"
        )
    }

    // MARK: - Restore

    func testARestoreThatFindsNothingSaysSo() {
        let app = launch("paywall-trial")
        // "Restore Purchases" is the last of the four footer links.
        element(app, "paywall.legal.3").tap()
        XCTAssertEqual(
            noticeText(app, "a restore that found nothing left nothing on screen"),
            "We could not find a purchase to restore on this Apple Account."
        )
    }

    func testARestoreThatCannotReachTheAppStoreReadsAsAnError() {
        let app = launch("paywall-trial", ["--purchase-outcome", "failed"])
        element(app, "paywall.legal.3").tap()
        XCTAssertEqual(
            noticeText(app, "a failed restore left nothing on screen"),
            "We could not reach the App Store. Please try again."
        )
    }

    // MARK: - The banner itself

    func testTheNoticeCanBeDismissed() {
        let app = launch("paywall-trial", ["--purchase-outcome", "cancelled"])
        element(app, "paywall.redeem").tap()
        let notice = element(app, "paywall.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 8))
        element(app, "paywall.notice.dismiss").tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "the banner would not go away")
    }

    func testThePlansSheetSpeaksForItsOwnPurchases() {
        let app = launch("paywall-plans", ["--purchase-outcome", "failed"])
        let redeem = element(app, "paywall.plans.redeem")
        XCTAssertTrue(redeem.waitForExistence(timeout: 8))
        redeem.tap()
        XCTAssertTrue(
            noticeText(app, "the plans sheet's call to action failed silently").contains("could not complete"),
            "the plans sheet showed the wrong message"
        )
        // The sheet's own 340 pt are full, so the banner sits over the dim above it.
        XCTAssertLessThanOrEqual(
            element(app, "paywall.notice").frame.maxY,
            element(app, "paywall.plans.card.com.scrollthequran.yearly").frame.minY,
            "the banner landed on the plan cards"
        )
    }

    func testTheGiftOfferSpeaksForItsOwnPurchases() {
        let app = launch("gift-open", ["--purchase-outcome", "failed"])
        element(app, "gift.startTrial").tap()
        XCTAssertTrue(
            noticeText(app, "the gift offer's call to action failed silently").contains("could not complete"),
            "the gift offer showed the wrong message"
        )
        XCTAssertLessThanOrEqual(
            element(app, "paywall.notice").frame.maxY,
            element(app, "gift.lucky").frame.minY,
            "the banner landed on the price or the call to action"
        )
    }

    // MARK: - IAP-2: the gift offer's own legal affordances

    func testTheGiftOfferCarriesTermsPrivacyAndRestore() {
        let app = launch("gift-open")
        for link in ["terms", "privacy", "restore"] {
            XCTAssertTrue(
                element(app, "gift.legal.\(link)").exists,
                "the gift offer has no \(link) affordance — guideline 3.1.2(a)"
            )
        }
        // The renewal disclosure has to name the price, the period and the renewal.
        let footnote = element(app, "gift.footnote").label
        XCTAssertTrue(footnote.contains("$19.99/year"), "footnote read '\(footnote)'")
        XCTAssertTrue(footnote.lowercased().contains("renew"), "footnote read '\(footnote)'")
    }

    func testTheGiftOffersRestoreReachesTheStore() {
        let app = launch("gift-open")
        element(app, "gift.legal.restore").tap()
        XCTAssertEqual(
            noticeText(app, "Restore Purchases on the gift offer did nothing"),
            "We could not find a purchase to restore on this Apple Account."
        )
    }
}
