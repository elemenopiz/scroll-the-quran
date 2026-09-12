import XCTest

/// The Quran tab's flows: paging, the rail, the translation sheet and the notes sheet.
///
/// `AppShell` routes `--screenshot reader` (and the sheet routes) into `ReaderView`
/// (Phase 3e), so `launchReader` asserts `screen.reader` appeared instead of skipping.
///
/// **State.** The reader writes the chosen translation and any note to the App Group
/// container, which survives `simctl uninstall`. A test whose assertions depend on the
/// starting state — `testSwitchingTranslationChangesTheText` expects CLEAR, and the
/// translation pill's width is measured against it — passes `--reset-state` so it does
/// not inherit whatever the previous run left behind.
final class ReaderTests: XCTestCase {
    /// Al-Baqarah, the surah the reader opens on for the screenshot routes.
    private let surah = 2
    private let ayahCount = 286

    /// Set `SCROLL_RECORD_SPECS=1` in the test runner's environment (or pass
    /// `TEST_RUNNER_SCROLL_RECORD_SPECS=1` to `xcodebuild test`) to print the observed frames
    /// instead of asserting them, which is how `UITests/Specs/reader-*.json` gets its numbers.
    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["SCROLL_RECORD_SPECS"] == "1"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launching

    private func launchReader(
        route: String = "reader",
        arguments extra: [String] = [],
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", route] + extra
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "screen.reader").firstMatch
                .waitForExistence(timeout: 10),
            "--screenshot \(route) did not reach FeatureReader: 'screen.reader' never appeared"
        )
        return app
    }

    private func page(_ app: XCUIApplication, ayah: Int, part: Int = 0) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "reader.page.\(surah).\(ayah).\(part)")
            .firstMatch
    }

    // MARK: - Layout spec

    /// Runs `UITests/Specs/reader-*.json`. They are wrapped in an envelope so the generic
    /// `LayoutSpecTests` loader ignores them while the route is unwired; see the spec's `note`.
    func testReaderLayoutSpecs() throws {
        let specs = try ReaderSpecEnvelope.loadAll()
        XCTAssertFalse(specs.isEmpty, "no reader layout specs found in the UI test bundle")

        for spec in specs {
            let app = try launchReader(route: spec.route)
            defer { app.terminate() }

            let screen = app.windows.firstMatch.frame
            XCTAssertGreaterThan(screen.width, 0, "\(spec.id): could not read the window frame")
            let scaleX = spec.reference.width / screen.width
            let scaleY = spec.reference.height / screen.height

            for element in spec.elements {
                let found = app.element(for: element)
                XCTAssertTrue(
                    found.waitForExistence(timeout: 5),
                    "\(spec.id): \(element.query.rawValue) '\(element.name)' never appeared"
                )
                guard found.exists, element.existenceOnly != true || isRecording else { continue }

                let observed = CGRect(
                    x: found.frame.minX * scaleX,
                    y: found.frame.minY * scaleY,
                    width: found.frame.width * scaleX,
                    height: found.frame.height * scaleY
                )
                if isRecording {
                    print(String(
                        format: "SPEC %@ %@ { \"x\": %.1f, \"y\": %.1f, \"width\": %.1f, \"height\": %.1f }",
                        spec.id, element.name,
                        observed.minX, observed.minY, observed.width, observed.height
                    ))
                    continue
                }
                let tolerance = element.tolerance ?? spec.tolerance
                let expected = element.frame.rect
                assertClose(observed.minX, expected.minX, tolerance, "\(spec.id) \(element.name) x")
                assertClose(observed.minY, expected.minY, tolerance, "\(spec.id) \(element.name) y")
                assertClose(observed.width, expected.width, tolerance, "\(spec.id) \(element.name) width")
                assertClose(observed.height, expected.height, tolerance, "\(spec.id) \(element.name) height")
            }
        }
    }

    // MARK: - Paging

    /// The reader opens on page 0 (the logo card and the Bismillah), so three swipes up land
    /// on ayah 3.
    func testThreeSwipesReachAyahThree() throws {
        let app = try launchReader()
        defer { app.terminate() }

        let pager = app.descendants(matching: .any).matching(identifier: "reader.pager").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        for _ in 0 ..< 3 {
            pager.swipeUp()
        }
        XCTAssertTrue(
            page(app, ayah: 3).waitForExistence(timeout: 5),
            "three swipes from the opening page should land on ayah 3"
        )
    }

    // MARK: - Rail

    /// Dragging the rail to 80 % of its length jumps to `round(0.8 x ayahCount)`.
    func testRailDragToEightyPercent() throws {
        let app = try launchReader()
        defer { app.terminate() }

        let rail = app.descendants(matching: .any).matching(identifier: "reader.rail").firstMatch
        XCTAssertTrue(rail.waitForExistence(timeout: 5))

        rail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
            .press(
                forDuration: 0.2,
                thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            )

        let expected = Int((0.8 * Double(ayahCount)).rounded())
        XCTAssertTrue(
            page(app, ayah: expected).waitForExistence(timeout: 5),
            "a drag to 80 % of the rail should land on ayah \(expected)"
        )
    }

    // MARK: - Translation

    /// Switching translation changes the English on the page and the pill's abbreviation.
    func testSwitchingTranslationChangesTheText() throws {
        // `--reset-state` wipes the App Group container first. Without it this test starts
        // on whatever translation the *previous* run left selected — PICKTHALL, after this
        // test itself has run once — and both the "Translation: CLEAR" assertion and the
        // pill's measured width (106.9 pt against the spec's 72.0) fail on a second run.
        let app = try launchReader(arguments: ["--reset-state"])
        defer { app.terminate() }

        let pager = app.descendants(matching: .any).matching(identifier: "reader.pager").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        pager.swipeUp()
        pager.swipeUp()

        let verse = app.descendants(matching: .any).matching(identifier: "reader.verse").firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        let before = verse.label

        let pill = app.descendants(matching: .any).matching(identifier: "reader.translationPill").firstMatch
        XCTAssertEqual(pill.label, "Translation: CLEAR")
        pill.tap()

        let row = app.descendants(matching: .any).matching(identifier: "translationSheet.row.pickthall").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.descendants(matching: .any).matching(identifier: "translationSheet.done").firstMatch.tap()

        let after = app.descendants(matching: .any).matching(identifier: "reader.verse").firstMatch
        XCTAssertTrue(after.waitForExistence(timeout: 5))
        XCTAssertNotEqual(after.label, before, "the verse should be in a different translation")
        XCTAssertEqual(pill.label, "Translation: PICKTHALL")
    }

    // MARK: - Notes

    /// A note autosaves and is still there after the app is relaunched.
    func testNotePersistsAcrossRelaunch() throws {
        let note = "Ayat al-Kursi, memorise"
        let app = try launchReader()

        let pager = app.descendants(matching: .any).matching(identifier: "reader.pager").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        pager.swipeUp()

        app.descendants(matching: .any).matching(identifier: "reader.action.notes").firstMatch.tap()
        let editor = app.descendants(matching: .any).matching(identifier: "notesSheet.editor").firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(note)
        app.descendants(matching: .any).matching(identifier: "notesSheet.done").firstMatch.tap()
        app.terminate()

        let relaunched = try launchReader()
        defer { relaunched.terminate() }
        let pagerAgain = relaunched.descendants(matching: .any).matching(identifier: "reader.pager").firstMatch
        XCTAssertTrue(pagerAgain.waitForExistence(timeout: 5))
        pagerAgain.swipeUp()
        relaunched.descendants(matching: .any).matching(identifier: "reader.action.notes").firstMatch.tap()
        let editorAgain = relaunched.descendants(matching: .any).matching(identifier: "notesSheet.editor").firstMatch
        XCTAssertTrue(editorAgain.waitForExistence(timeout: 5))
        XCTAssertEqual(editorAgain.value as? String, note, "the note should have been autosaved")
    }

    // MARK: - Performance

    /// Al-Baqarah — 286 ayat, several of them split into continuation pages — has to be on
    /// screen quickly.
    ///
    /// The brief's budget is 400 ms to open surah 2, and that is asserted where it can be:
    /// `ReaderPerformanceTests.openingAlBaqarahIsFast` on the host, which times building the
    /// model and its 287 pages. From here the clock also contains a cold process launch of a
    /// debug build, several seconds of it, so the number recorded by `XCTClockMetric` is a
    /// regression baseline rather than a budget. What this test does assert is the part that
    /// is the reader's: once the process is up, the first verse is on screen promptly.
    func testOpeningAlBaqarahIsFast() throws {
        _ = try launchReader()
        XCUIApplication().terminate()

        measure(metrics: [XCTClockMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--screenshot", "reader"]
            app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
            app.launch()
            _ = app.descendants(matching: .any).matching(identifier: "reader.verse").firstMatch
                .waitForExistence(timeout: 10)
            app.terminate()
        }

        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", "reader"]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        defer { app.terminate() }
        let started = Date()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "reader.verse").firstMatch
                .waitForExistence(timeout: 10),
            "the reader never drew a verse"
        )
        let elapsed = Date().timeIntervalSince(started)
        // A smoke ceiling, not the budget: most of this second is XCUITest taking its first
        // accessibility snapshot of the process, which the reader does not control. It is here
        // to catch a catastrophic regression — a reader that paginates per page change, say —
        // while `ReaderPerformanceTests` holds the 400 ms line on the work that is ours.
        XCTAssertLessThan(
            elapsed, 2.5,
            "the first verse of Al-Baqarah took \(Int(elapsed * 1000)) ms to appear after launch"
        )
    }

    // MARK: - Helpers

    private func assertClose(_ observed: CGFloat, _ expected: CGFloat, _ tolerance: Double, _ label: String) {
        XCTAssertEqual(
            Double(observed), Double(expected), accuracy: tolerance,
            "\(label): expected \(expected) +/- \(tolerance), got \(observed)"
        )
    }
}

/// The wrapper around a reader `LayoutSpec`. See `UITests/Specs/reader-dark.json` for why the
/// specs are not bare `LayoutSpec` documents.
struct ReaderSpecEnvelope: Decodable {
    /// What has to exist before the spec can run. Only `"reader-routing"` today.
    let requires: String
    let spec: LayoutSpec

    static func loadAll(in bundle: Bundle = Bundle(for: ReaderTests.self)) throws -> [LayoutSpec] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return (try? decoder.decode(ReaderSpecEnvelope.self, from: data))?.spec
            }
    }
}
