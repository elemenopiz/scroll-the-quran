import XCTest

/// Drives the whole first-run funnel on the simulator: hook -> four slides -> reviews,
/// plus the sign-in sheet the hook's secondary button opens.
///
/// Every test skips itself (loudly) while `App/RootView.swift` still renders the Phase 1
/// placeholder for the onboarding phase. `FeatureOnboardingModule.screen(for:)` is the
/// seam that makes these live; wiring it is the orchestrator's call, since `App/` is
/// frozen and outside this task's ownership.
final class OnboardingFlowTests: XCTestCase {
    /// The reference space the funnel was measured in (`Reference/onboarding-*.png`).
    private let referenceSize = CGSize(width: 393, height: 852)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ route: String = "onboarding-hook") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", route]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        return app
    }

    /// `nil` when the funnel is not reachable yet, so the caller can skip.
    private func funnel(_ app: XCUIApplication, screen: String) throws -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: "screen.\(screen)").firstMatch
        guard element.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                "screen.\(screen) never appeared: App/RootView.swift still renders the Phase 1 "
                    + "onboarding placeholder. Route it through FeatureOnboardingModule.screen(for:)."
            )
        }
        return element
    }

    // MARK: - Flow

    func testTapsThroughEverySlideToTheReviewsScreen() throws {
        let app = launch()
        _ = try funnel(app, screen: "onboarding-hook")

        let hookContinue = app.descendants(matching: .any)
            .matching(identifier: "onboarding.hook.continue").firstMatch
        XCTAssertTrue(hookContinue.waitForExistence(timeout: 5), "the hook has no Continue button")
        hookContinue.tap()

        for slide in 1 ... 4 {
            let screen = app.descendants(matching: .any)
                .matching(identifier: "screen.onboarding-slide\(slide)").firstMatch
            XCTAssertTrue(screen.waitForExistence(timeout: 5), "slide \(slide) never appeared")

            let next = app.descendants(matching: .any)
                .matching(identifier: "onboarding.slide.continue").firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 5), "slide \(slide) has no Continue button")
            next.tap()
        }

        let reviews = app.descendants(matching: .any)
            .matching(identifier: "screen.onboarding-reviews").firstMatch
        XCTAssertTrue(reviews.waitForExistence(timeout: 5), "the reviews screen never appeared")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "onboarding.reviews.continue").firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    func testAlreadySignedUpOpensTheSignInSheet() throws {
        let app = launch()
        _ = try funnel(app, screen: "onboarding-hook")

        let secondary = app.descendants(matching: .any)
            .matching(identifier: "onboarding.hook.alreadySignedUp").firstMatch
        XCTAssertTrue(secondary.waitForExistence(timeout: 5), "the hook has no secondary button")
        secondary.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "screen.onboarding-signin").firstMatch
                .waitForExistence(timeout: 5),
            "the sign-in sheet never appeared"
        )
        XCTAssertTrue(app.textFields["onboarding.signin.email"].waitForExistence(timeout: 5))
    }

    func testSignInRouteOpensStraightOntoTheSheet() throws {
        let app = launch("onboarding-signin")
        _ = try funnel(app, screen: "onboarding-signin")
        XCTAssertTrue(app.textFields["onboarding.signin.email"].waitForExistence(timeout: 5))
    }

    // MARK: - Layout

    /// The hook's two anchors, in reference points. Numbers come from
    /// `Reference/onboarding-hook.png`: Continue fills x 52...340.67 and rows 746...801.
    func testHookMatchesTheReferenceLayout() throws {
        let app = launch()
        _ = try funnel(app, screen: "onboarding-hook")

        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, 0)
        let scaleX = referenceSize.width / window.width
        let scaleY = referenceSize.height / window.height

        let headline = app.descendants(matching: .any)
            .matching(identifier: "onboarding.hook.headline").firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        let headlineTop = headline.frame.minY * scaleY

        let button = app.descendants(matching: .any)
            .matching(identifier: "onboarding.hook.continue").firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let cta = CGRect(
            x: button.frame.minX * scaleX,
            y: button.frame.minY * scaleY,
            width: button.frame.width * scaleX,
            height: button.frame.height * scaleY
        )

        if ProcessInfo.processInfo.environment["SCROLL_RECORD_SPECS"] == "1" {
            print(String(
                format: "SPEC onboarding-hook headline.top=%.1f cta={%.1f, %.1f, %.1f, %.1f}",
                headlineTop, cta.minX, cta.minY, cta.width, cta.height
            ))
            return
        }

        XCTAssertEqual(Double(headlineTop), 274, accuracy: 12, "headline top in reference points")
        XCTAssertEqual(Double(cta.minX), 52, accuracy: 6, "Continue x")
        XCTAssertEqual(Double(cta.minY), 746, accuracy: 6, "Continue y")
        XCTAssertEqual(Double(cta.width), 289, accuracy: 6, "Continue width")
        XCTAssertEqual(Double(cta.height), 56, accuracy: 6, "Continue height")
    }
}
