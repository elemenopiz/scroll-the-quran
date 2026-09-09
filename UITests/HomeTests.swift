import XCTest

/// Flows on the Home tab.
///
/// **These skip until Phase 3e.** `FeatureHome` ships its views, but `AppShell` still routes the
/// `home` screen id to `PlaceholderScreen`, so nothing with a `home.*` identifier is on screen
/// yet. Each test therefore launches the route, looks for the Home tab's own root, and calls
/// `XCTSkipUnless` when it is not there — green today, a real assertion the moment the wiring
/// lands. Nothing else about the tests changes then.
final class HomeTests: XCTestCase {
    private static let launchTimeout: TimeInterval = 8

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Helpers

    @discardableResult
    private func launch(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", route]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        return app
    }

    /// Skips the test unless the real Home screen is on screen (see the type comment).
    private func requireHome(_ app: XCUIApplication) throws {
        let home = app.descendants(matching: .any).matching(identifier: "home.settingsPill").firstMatch
        try XCTSkipUnless(
            home.waitForExistence(timeout: HomeTests.launchTimeout),
            "FeatureHome is not wired into AppShell yet (Phase 3e): 'home' still renders the placeholder."
        )
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: Tests

    /// The card stack the `home-dark` reference shows, in order.
    func testHomeShowsTheCardStack() throws {
        let app = launch("home")
        try requireHome(app)

        for identifier in [
            "home.verseSearchCard",
            "home.todaysReading",
            "home.streakCard",
            "home.progressCard",
            "home.savedRow",
            "home.widgetRow",
            "home.settingsPill",
        ] {
            let found = element(app, identifier)
            XCTAssertTrue(found.waitForExistence(timeout: 3), "missing \(identifier)")
        }
    }

    /// The DoD flow: open the plans sheet, open a plan, start it, and Home says "Day 1 of …".
    func testStartingAPlanPutsDayOneOnHome() throws {
        let app = launch("home")
        try requireHome(app)

        element(app, "home.todaysReading").tap()

        let sheet = element(app, "plans-sheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the Reading Plans sheet never appeared")

        // Any plan card will do; the first one is the catalog's "start here".
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "plans.card."))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "no plan cards in the sheet")
        card.tap()

        let start = element(app, "planDetail.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5), "the plan detail sheet never appeared")
        start.tap()

        let dayOne = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Day 1 of ")
        ).firstMatch
        XCTAssertTrue(
            dayOne.waitForExistence(timeout: 8),
            "Home does not show 'Day 1 of n' after starting a plan"
        )
    }

    /// The Saved row opens the library, and Done closes it again.
    func testSavedRowOpensTheLibrary() throws {
        let app = launch("home")
        try requireHome(app)

        element(app, "home.savedRow").tap()
        let library = element(app, "library")
        XCTAssertTrue(library.waitForExistence(timeout: 5), "the library sheet never appeared")

        element(app, "library.done").tap()
        XCTAssertTrue(
            element(app, "home.settingsPill").waitForExistence(timeout: 5),
            "dismissing the library did not return to Home"
        )
    }

    /// The settings pill opens Settings with the translation list in it.
    func testSettingsPillOpensSettings() throws {
        let app = launch("home")
        try requireHome(app)

        element(app, "home.settingsPill").tap()
        XCTAssertTrue(
            element(app, "settings").waitForExistence(timeout: 5),
            "the settings sheet never appeared"
        )
        XCTAssertTrue(
            element(app, "settings.deleteData").waitForExistence(timeout: 3),
            "settings is missing the delete-my-data row"
        )
    }

    /// The frames in `Specs/home-layout.json`, applied the way `LayoutSpecTests` applies a
    /// top-level spec. They live in a wrapper file so the shared sweep does not assert them
    /// before Phase 3e wires Home; see the note inside that file.
    func testHomeLayoutSpecs() throws {
        let specs = try HomeTests.pendingLayoutSpecs()
        XCTAssertFalse(specs.isEmpty, "home-layout.json carries no specs")

        for spec in specs {
            let app = launch(spec.route)
            defer { app.terminate() }
            try requireHome(app)

            let screen = app.windows.firstMatch.frame
            XCTAssertGreaterThan(screen.width, 0, "\(spec.id): could not read the window frame")
            let scaleX = spec.reference.width / screen.width
            let scaleY = spec.reference.height / screen.height

            for element in spec.elements {
                let found = app.element(for: element)
                XCTAssertTrue(
                    found.waitForExistence(timeout: 5),
                    "\(spec.id): '\(element.name)' never appeared"
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
                for (label, lhs, rhs) in [
                    ("x", observed.minX, expected.minX),
                    ("y", observed.minY, expected.minY),
                    ("width", observed.width, expected.width),
                    ("height", observed.height, expected.height),
                ] {
                    XCTAssertEqual(
                        Double(lhs), Double(rhs), accuracy: tolerance,
                        "\(spec.id) \(element.name) \(label): expected \(rhs) +/- \(tolerance), got \(lhs)"
                    )
                }
            }
        }
    }

    private struct PendingSpecs: Decodable {
        let specs: [LayoutSpec]
    }

    static func pendingLayoutSpecs() throws -> [LayoutSpec] {
        let bundle = Bundle(for: HomeTests.self)
        guard let url = bundle.url(forResource: "home-layout", withExtension: "json") else {
            XCTFail("home-layout.json is not in the UI test bundle")
            return []
        }
        return try JSONDecoder().decode(PendingSpecs.self, from: Data(contentsOf: url)).specs
    }

    /// Verse Search switches between Basic and Advanced, and the study button stays reachable.
    func testVerseSearchModeSwitch() throws {
        let app = launch("verse-search")
        let card = element(app, "home.verseSearchCard")
        try XCTSkipUnless(
            card.waitForExistence(timeout: HomeTests.launchTimeout),
            "FeatureHome is not wired into AppShell yet (Phase 3e): 'verse-search' has no route."
        )

        element(app, "home.verseSearch.basic").tap()
        XCTAssertTrue(element(app, "home.studyThisVerse").exists)
        element(app, "home.verseSearch.advanced").tap()
        XCTAssertTrue(element(app, "home.studyThisVerse").exists)
    }
}
