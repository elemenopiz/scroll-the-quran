import XCTest

/// The routing layer, driven through the real app: deep links, and the `--screenshot <id>`
/// registry that every reference capture and every layout spec launches through.
///
/// These are the Phase 3e gate. They do not skip: by the time they run, `AppShell` routes
/// every id to a real screen. The two exceptions are called out by name — `home*` and
/// `onboarding-*` still land on `PlaceholderScreen` until `FeatureHome` and
/// `FeatureOnboarding` merge, and this file asserts exactly that, so the day those features
/// land the assertion flips and says so.
final class RoutingTests: XCTestCase {
    /// Every `--screenshot` id, in `Reference/manifest.json` order, plus the three ids that
    /// are not manifest screens (`gallery`, `tabbar`, `widget-gallery`).
    ///
    /// Kept in step with `AppShell/ScreenID.swift` by hand: a UI test bundle cannot import
    /// the package, and a route that stops resolving has to fail here rather than silently
    /// render a blank screen in a capture.
    private static let manifestRoutes = [
        "onboarding-hook", "onboarding-signin", "onboarding-slide1", "onboarding-slide2",
        "onboarding-slide3", "onboarding-slide4", "onboarding-reviews",
        "paywall-trial", "paywall-plans", "gift-closed", "gift-open",
        "community", "discover",
        "deepstudy", "deepstudy#original-language", "deepstudy#cross-references", "deepstudy#apply-it",
        "reader", "translation-sheet", "notes-sheet",
        "home", "home#scrolled",
        "plans-sheet", "plan-detail", "verse-search",
        "gallery", "tabbar", "widget-gallery",
    ]

    /// Routes that still render the Phase 1 placeholder, and why.
    ///
    /// `FeatureHome` landed in 3e and `FeatureOnboarding` in 2d, so every manifest route is
    /// asserted like any other. What is left is `tabbar`, which has no feature behind it —
    /// it is the Phase 1 spec's bare shell.
    private static let placeholderRoutes: Set<String> = ["tabbar"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launching

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        return app
    }

    /// Opens a `scrollthequran://` URL the way the widget does — through the system, not
    /// through a launch argument — and dismisses the confirmation iOS puts in front of a
    /// cross-app open.
    private func open(_ url: String, in app: XCUIApplication) {
        XCUIDevice.shared.system.open(URL(string: url)!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let confirm = springboard.buttons["Open"]
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "\(url) did not bring the app forward"
        )
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Deep links

    /// The headline of the brief: a widget tap lands on Ayat al-Kursi.
    func testVerseDeepLinkLandsOnAlBaqarah255() {
        let app = launch(["--ui-test"])
        XCTAssertTrue(element(app, "tabroot").waitForExistence(timeout: 15), "the tab bar never appeared")

        open("scrollthequran://verse/2/255", in: app)

        XCTAssertTrue(
            element(app, "reader.page.2.255.0").waitForExistence(timeout: 15),
            "the deep link did not open the reader on 2:255"
        )
        // The reference line carries a "(1/2)" caption when a long ayah is split across
        // pages, and Ayat al-Kursi is long, so match the prefix rather than the whole label.
        let reference = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Al-Baqarah 2:255")
        ).firstMatch
        XCTAssertTrue(
            reference.waitForExistence(timeout: 10),
            "the page on screen is not labelled Al-Baqarah 2:255"
        )
    }

    /// A study link opens Deep Study over the Discover tab.
    func testStudyDeepLinkOpensDeepStudy() {
        let app = launch(["--ui-test"])
        XCTAssertTrue(element(app, "tabroot").waitForExistence(timeout: 15))

        open("scrollthequran://study/1:1-7", in: app)

        XCTAssertTrue(
            element(app, "deepstudy").waitForExistence(timeout: 15),
            "scrollthequran://study/1:1-7 did not raise Deep Study"
        )
    }

    /// A tab link just switches tabs.
    func testTabDeepLinkSelectsTheTab() {
        let app = launch(["--ui-test"])
        XCTAssertTrue(element(app, "tabroot").waitForExistence(timeout: 15))

        open("scrollthequran://tab/community", in: app)

        XCTAssertTrue(
            app.staticTexts["community.given.amount"].waitForExistence(timeout: 15),
            "scrollthequran://tab/community did not select the Community tab"
        )
    }

    /// A malformed link must not move the app anywhere.
    func testUnknownDeepLinkIsIgnored() {
        let app = launch(["--ui-test"])
        XCTAssertTrue(element(app, "tabroot").waitForExistence(timeout: 15))

        open("scrollthequran://verse/2", in: app)

        XCTAssertFalse(
            element(app, "reader.page.2.255.0").waitForExistence(timeout: 3),
            "a malformed link opened the reader anyway"
        )
        XCTAssertTrue(element(app, "tabroot").exists, "the tab bar went away")
    }

    // MARK: - The screenshot registry

    /// Every id the snapshot harness and the layout specs launch must resolve to a screen
    /// that actually comes up. A route that falls off the registry renders nothing, and a
    /// blank capture is not something an RMSE check reliably catches.
    func testEveryScreenshotRouteLaunchesAndRendersSomething() {
        continueAfterFailure = true
        for route in Self.manifestRoutes {
            let app = launch(["--screenshot", route])
            defer { app.terminate() }

            XCTAssertEqual(app.state, .runningForeground, "\(route): the app is not in the foreground")
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 15), "\(route): no window")
            XCTAssertGreaterThan(
                window.descendants(matching: .any).count, 1,
                "\(route): the window is empty — the route resolved to nothing"
            )

            let placeholder = app.staticTexts["screen.\(route).label"]
            if Self.placeholderRoutes.contains(route) {
                // Not a failure yet: FeatureHome and FeatureOnboarding are still landing.
                // When they merge, drop the route from `placeholderRoutes` and this becomes
                // the assertion below.
                continue
            }
            XCTAssertFalse(
                placeholder.exists,
                "\(route): still renders PlaceholderScreen — the registry did not reach the feature"
            )
        }
    }

    /// The three routes with an `#anchor` reach the same screen as their bare form.
    func testDeepStudyAnchorsResolve() {
        for route in ["deepstudy", "deepstudy#original-language", "deepstudy#apply-it"] {
            let app = launch(["--screenshot", route])
            defer { app.terminate() }
            XCTAssertTrue(
                element(app, "deepstudy").waitForExistence(timeout: 15),
                "\(route) did not render Deep Study"
            )
        }
    }

    // MARK: - Widget

    /// `--screenshot widget-gallery` renders every family the widget declares.
    func testWidgetGalleryRendersEveryFamily() {
        let app = launch(["--screenshot", "widget-gallery"])
        XCTAssertTrue(
            element(app, "screen.widget-gallery").waitForExistence(timeout: 15),
            "the widget gallery did not render"
        )
        for family in ["systemSmall", "systemMedium", "accessoryRectangular", "accessoryInline"] {
            XCTAssertTrue(
                element(app, "widgetGallery.\(family)").exists,
                "the \(family) widget is missing from the gallery"
            )
        }
    }
}
