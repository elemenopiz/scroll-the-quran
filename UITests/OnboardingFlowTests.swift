import XCTest

/// Drives the whole first-run funnel on the simulator: hook -> four slides -> reviews,
/// plus the sign-in sheet the hook's secondary button opens.
///
/// `App/RootView.swift` renders `RootPhase.onboarding` through
/// `FeatureOnboardingModule.view(forScreenID:onFinished:)`, so these run against the
/// real app rather than a harness.
final class OnboardingFlowTests: XCTestCase {
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

    /// The funnel screen behind a `--screenshot` route. A failure here means the
    /// onboarding phase is not routed through `FeatureOnboardingModule` any more.
    private func funnel(_ app: XCUIApplication, screen: String) throws -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: "screen.\(screen)").firstMatch
        XCTAssertTrue(
            element.waitForExistence(timeout: 10),
            "screen.\(screen) never appeared: is RootView still routing .onboarding to the funnel?"
        )
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

    // The hook's frame assertions live in `UITests/Specs/onboarding-hook.json` and run
    // through `LayoutSpecTests`, which is this project's mechanism for a layout spec.
    // Duplicating them here only bought a second app launch.
}
