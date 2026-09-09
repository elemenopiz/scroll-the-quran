import XCTest

/// Flow tests for the Discover feed and Deep Study.
///
/// The app does not route `--screenshot discover` / `--screenshot deepstudy#…` into
/// `FeatureDiscover` yet — that wiring is Phase 3e's, and `AppShell` is not this task's
/// to edit. Until it lands, `TabRoot` renders the Phase 1 placeholder for the Discover
/// tab, so every test here starts by looking for the `discover` container and skips
/// with a clear message when it is not there. Once 3e wires
/// `DiscoverScreens.screen(id:anchor:…)` in, these become real assertions with no edit.
///
/// The recorded layout specs are parked beside them as
/// `UITests/Specs/discover-dark.json.disabled` and `deepstudy-top.json.disabled`;
/// dropping the `.disabled` suffix enrols them in `LayoutSpecTests`.
final class DiscoverTests: XCTestCase {
    private let fixedDate = "2026-09-14"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", route]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = fixedDate
        app.launch()
        return app
    }

    /// Skips the test when the route still lands on the Phase 1 placeholder.
    private func requireRouted(_ app: XCUIApplication, _ identifier: String) throws {
        let screen = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        guard screen.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                """
                '\(identifier)' is not on screen: FeatureDiscover is not routed yet. \
                Phase 3e wires ScreenRoute -> DiscoverScreens.screen(id:anchor:feed:themes:studies:today:).
                """
            )
        }
    }

    func testDiscoverCardShowsItsParts() throws {
        let app = launch("discover")
        try requireRouted(app, "discover")

        for identifier in [
            "discover.card", "discover.themeChip", "discover.reference",
            "discover.quote", "discover.meaning", "discover.didYouKnow",
            "discover.deepStudy",
        ] {
            let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 3), "missing \(identifier)")
        }

        for action in ["save", "comment", "share", "read"] {
            XCTAssertTrue(
                app.buttons["discover.actions.\(action)"].exists,
                "missing action discover.actions.\(action)"
            )
        }
    }

    func testDeepStudyOpensFromTheCardAndCloses() throws {
        let app = launch("discover")
        try requireRouted(app, "discover")

        app.buttons["discover.deepStudy"].tap()
        let page = app.descendants(matching: .any).matching(identifier: "deepstudy").firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5), "Deep Study never appeared")
        XCTAssertTrue(app.buttons["deepstudy.close"].exists)

        app.buttons["deepstudy.close"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "discover").firstMatch
                .waitForExistence(timeout: 5),
            "closing Deep Study did not return to the feed"
        )
    }

    func testDeepStudyRendersEverySectionInOrder() throws {
        let app = launch("deepstudy")
        try requireRouted(app, "deepstudy")

        XCTAssertTrue(app.staticTexts["MEANING"].waitForExistence(timeout: 3))
        // The three list-shaped sections are further down; scroll to the foot of the page.
        let disclaimer = app.descendants(matching: .any)
            .matching(identifier: "deepstudy.disclaimer").firstMatch
        var swipes = 0
        while !disclaimer.isHittable, swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(disclaimer.exists, "never reached the footer disclaimer")
        for identifier in ["deepstudy.save", "deepstudy.note", "deepstudy.copyAll", "deepstudy.share"] {
            XCTAssertTrue(app.buttons[identifier].exists, "missing \(identifier)")
        }
    }

    func testDeepStudyAnchorScrollsToTheSection() throws {
        let app = launch("deepstudy#apply-it")
        try requireRouted(app, "deepstudy")
        XCTAssertTrue(
            app.staticTexts["APPLY IT"].waitForExistence(timeout: 5),
            "deepstudy#apply-it did not scroll APPLY IT into view"
        )
    }

    /// `deepstudy#original-language` is the route `Reference/manifest.json` records for
    /// `deepstudy-mid`; ours has to land on KEY ARABIC TERMS, the same slot in the order.
    func testManifestAnchorAliasResolves() throws {
        let app = launch("deepstudy#original-language")
        try requireRouted(app, "deepstudy")
        XCTAssertTrue(
            app.staticTexts["KEY ARABIC TERMS"].waitForExistence(timeout: 5),
            "the manifest's original-language anchor did not land on KEY ARABIC TERMS"
        )
    }
}
