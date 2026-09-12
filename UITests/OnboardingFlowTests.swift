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
        assertSignInSheetContents(app)
    }

    func testSignInRouteOpensStraightOntoTheSheet() throws {
        let app = launch("onboarding-signin")
        _ = try funnel(app, screen: "onboarding-signin")
        assertSignInSheetContents(app)
    }

    /// Both routes onto the sheet must offer the real `SignInWithAppleButton` and the
    /// local email field. The Apple button is the only account path that exists — there
    /// is no code flow behind the email field — so its absence is a shipping defect,
    /// not a cosmetic one.
    private func assertSignInSheetContents(_ app: XCUIApplication) {
        XCTAssertTrue(
            app.textFields["onboarding.signin.email"].waitForExistence(timeout: 5),
            "the sign-in sheet has no email field"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "onboarding.signin.apple").firstMatch
                .waitForExistence(timeout: 5),
            "the sign-in sheet has no Sign in with Apple button"
        )
    }

    // MARK: - The account the sign-in creates

    /// Audit SEC-2. Onboarding wrote the credential to its own sink and nowhere else, so
    /// `UserStore` never heard about it and Settings told a reader who had just signed in with
    /// Apple that they were not signed in — forever, on every launch.
    ///
    /// `--signed-in` hands the shell's `CompositeAccountSink` a fixture credential through the
    /// same method the real one arrives on. Apple's authorisation sheet is a system process
    /// XCUITest cannot drive, and the simulator has no Apple ID to drive it with, so this is
    /// the closest a test can stand to the real thing: everything after the credential — both
    /// sinks, the store, the row, the sign-out — is the shipping code path.
    func testASignedInAccountShowsInSettingsAndCanBeSignedOutOf() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launchArguments = ["--ui-test", "--reset-state", "--signed-in"]
        app.launch()
        XCTAssertTrue(element(app, "home.settingsPill").waitForExistence(timeout: 10), "the app did not reach Home")

        // Relaunched *without* the flag, so what Settings shows below came off the disk and
        // the Keychain rather than out of the launch argument: the account has to survive the
        // process that created it.
        app.terminate()
        app.launchArguments = ["--ui-test"]
        app.launch()

        let settingsPill = element(app, "home.settingsPill")
        XCTAssertTrue(settingsPill.waitForExistence(timeout: 10), "the app did not reach Home")
        settingsPill.tap()

        let account = element(app, "settings.account")
        XCTAssertTrue(account.waitForExistence(timeout: 5), "settings has no account row")
        XCTAssertFalse(
            account.label.contains("Not signed in"),
            "the account row still says 'Not signed in' after Sign in with Apple: \(account.label)"
        )
        XCTAssertTrue(
            account.label.contains("Signed in"),
            "the account row does not say the reader is signed in: \(account.label)"
        )
        XCTAssertTrue(
            account.label.contains("reader@example.com"),
            "the address Apple handed over is not shown: \(account.label)"
        )

        let signOut = element(app, "settings.signOut")
        XCTAssertTrue(signOut.waitForExistence(timeout: 3), "a signed-in account has no way to sign out")
        signOut.tap()

        // Both sinks: the flag and the address here, and the identity in the keychain, which
        // `UserStore.signOut()` clears through the record the composite attached to it.
        var label = ""
        for _ in 0 ..< 20 {
            label = element(app, "settings.account").label
            if label.hasPrefix("Not signed in") { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(label.hasPrefix("Not signed in"), "after signing out the account row reads: \(label)")
        XCTAssertFalse(
            element(app, "settings.signOut").exists,
            "the sign-out row is still there after signing out"
        )
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Layout

    // The hook's frame assertions live in `UITests/Specs/onboarding-hook.json` and run
    // through `LayoutSpecTests`, which is this project's mechanism for a layout spec.
    // Duplicating them here only bought a second app launch.
}
