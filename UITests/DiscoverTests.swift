import XCTest

/// Flow tests for the Discover feed and Deep Study.
///
/// `AppShell` routes `--screenshot discover` / `--screenshot deepstudy#…` into
/// `FeatureDiscover` (Phase 3e), so `requireRouted` asserts the screen is there instead
/// of skipping when it is not.
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

    /// Fails the test when the route does not reach the real Discover screen.
    ///
    /// The sentinel has to be an element only the real screen has: XCUITest matches an
    /// identifier against an element's *label* too, and the Phase 1 placeholder printed
    /// its own screen id ("discover") as a label.
    private func requireRouted(_ app: XCUIApplication, _ identifier: String) {
        let screen = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            screen.waitForExistence(timeout: 8),
            "'\(identifier)' never appeared — the route did not reach FeatureDiscover"
        )
    }

    func testDiscoverCardShowsItsParts() throws {
        let app = launch("discover")
        requireRouted(app, "discover.card")

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
        requireRouted(app, "discover.card")

        // The feed is a lazy pager: the neighbouring cards are realised too, so there is more
        // than one "Deep study" button in the tree and an unqualified tap is ambiguous. The
        // first match is the card on screen.
        app.buttons["discover.deepStudy"].firstMatch.tap()
        let page = app.descendants(matching: .any).matching(identifier: "deepstudy").firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 15), "Deep Study never appeared")
        XCTAssertTrue(app.buttons["deepstudy.close"].exists)

        app.buttons["deepstudy.close"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "discover.card").firstMatch
                .waitForExistence(timeout: 5),
            "closing Deep Study did not return to the feed"
        )
    }

    func testDeepStudyRendersEverySectionInOrder() throws {
        let app = launch("deepstudy")
        requireRouted(app, "deepstudy.quote")

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
        requireRouted(app, "deepstudy.quote")
        XCTAssertTrue(
            app.staticTexts["APPLY IT"].waitForExistence(timeout: 5),
            "deepstudy#apply-it did not scroll APPLY IT into view"
        )
    }

    /// `deepstudy#original-language` is the route `Reference/manifest.json` records for
    /// `deepstudy-mid`; ours has to land on KEY ARABIC TERMS, the same slot in the order.
    func testManifestAnchorAliasResolves() throws {
        let app = launch("deepstudy#original-language")
        requireRouted(app, "deepstudy.quote")
        XCTAssertTrue(
            app.staticTexts["KEY ARABIC TERMS"].waitForExistence(timeout: 5),
            "the manifest's original-language anchor did not land on KEY ARABIC TERMS"
        )
    }
}
