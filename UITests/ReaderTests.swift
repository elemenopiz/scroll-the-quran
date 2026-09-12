import XCTest

/// The Quran tab's flows: paging, the rail, the translation sheet and the notes sheet.
///
/// `AppShell` routes `--screenshot reader` (and the sheet routes) into `ReaderView`
/// (Phase 3e), so `launchReader` asserts `screen.reader` appeared instead of skipping.
///
/// **State.** The reader writes the chosen translation and any note to the App Group
/// container, which survives `simctl uninstall`. A test whose assertions depend on the
/// starting state — `testSwitchingTranslationChangesTheText` expects ITANI, and the
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

    /// Phase 4j: the rail must never leave the reader between two pages.
    ///
    /// Five scrubs to random targets down Al-Baqarah's 286 ayat. After each release the reader
    /// has to be *on* a page: exactly one page on screen, its block of type where the pager
    /// puts it on a page it swiped to (2 pt), the reference line naming one ayah — the first
    /// slice of it, if the ayah is split — and the verse text below the toolbar, not under it.
    ///
    /// The baseline is measured rather than assumed: two swipes page the reader with the
    /// pager's own gesture, which lands on a boundary by definition, and every page centres
    /// its verse block identically, so the frame recorded there is where a scrub must land.
    ///
    /// The targets come from a seeded generator, and the seed and the five fractions are
    /// printed, so a failure can be reproduced exactly.
    func testRailScrubAlwaysLandsOnAPageBoundary() throws {
        let app = try launchReader()
        defer { app.terminate() }

        let rail = app.descendants(matching: .any).matching(identifier: "reader.rail").firstMatch
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        let toolbar = app.descendants(matching: .any).matching(identifier: "reader.toolbar").firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5))
        let pager = app.descendants(matching: .any).matching(identifier: "reader.pager").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 5))

        // The settled geometry, from the pager's own paging gesture.
        pager.swipeUp()
        pager.swipeUp()
        let baseline = try onlyVisiblePage(in: app, after: "two swipes")
        let settledCentre = baseline.frame.midY
        print(String(format: "RAIL SCRUB baseline %@ centre %.1f", baseline.identifier, settledCentre))

        let seed: UInt64 = 0x4A_5241_494C // "JRAIL"
        var generator = SeededGenerator(seed: seed)
        let targets = (0 ..< 5).map { _ in Double.random(in: 0.05 ... 0.98, using: &generator) }
        print("RAIL SCRUB seed \(String(seed, radix: 16)) targets \(targets.map { String(format: "%.3f", $0) })")

        for target in targets {
            rail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
                .press(
                    forDuration: 0.2,
                    thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: target))
                )

            // 1. One page on screen, not two — and it is a page boundary the reader is on.
            let label = String(format: "a scrub to %.3f of the rail", target)
            let page = try onlyVisiblePage(in: app, after: label)
            XCTAssertEqual(
                Double(page.frame.midY), Double(settledCentre), accuracy: 2,
                "\(label) parked mid-page: \(page.identifier) sits at \(page.frame.midY), "
                    + "a page the pager settled on sits at \(settledCentre)"
            )

            // 2. Where the finger pointed, give or take the 2.19 pt pitch of a 286-ayah rail.
            let parts = page.identifier.split(separator: ".")
            let landed = try XCTUnwrap(parts.dropLast().last.flatMap { Int($0) }, "\(label): \(page.identifier)")
            let expected = max(1, Int((target * Double(ayahCount)).rounded()))
            XCTAssertLessThanOrEqual(
                abs(landed - expected), 2,
                "\(label) landed on 2:\(landed), not 2:\(expected)"
            )
            // 3. A split ayah lands on its first slice, the "(1/n)" page.
            XCTAssertEqual(parts.last.flatMap { Int($0) }, 0, "\(label) landed on a continuation page")

            // 4. The reference line names that one ayah, and nothing else.
            let reference = page.descendants(matching: .any)
                .matching(identifier: "reader.reference").firstMatch
            XCTAssertTrue(reference.waitForExistence(timeout: 5))
            let expectedPrefix = "Al-Baqarah 2:\(landed)"
            XCTAssertTrue(
                reference.label == expectedPrefix || reference.label.hasPrefix(expectedPrefix + " (1/"),
                "\(label): the page should name one ayah, got '\(reference.label)'"
            )

            // 5. The toolbar is chrome over the page, not over the words.
            let verse = page.descendants(matching: .any).matching(identifier: "reader.verse").firstMatch
            XCTAssertTrue(verse.waitForExistence(timeout: 5))
            XCTAssertGreaterThan(
                verse.frame.minY, toolbar.frame.maxY,
                "\(label): the toolbar (to \(toolbar.frame.maxY)) covers the verse "
                    + "(from \(verse.frame.minY))"
            )
        }
    }

    /// The one reader page on screen, once the pager has stopped moving.
    ///
    /// A pager parked between two pages shows two, which is the failure this test exists for,
    /// so "exactly one" is an assertion and not a convenience. The wait is for the *identity*
    /// to stop changing — deliberately not a wait on the assertion itself: a pager that parks
    /// mid-page and stays there has to fail rather than be waited out.
    private func onlyVisiblePage(in app: XCUIApplication, after label: String) throws -> XCUIElement {
        let pages = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'reader.page.'"))
        var previous = ""
        var visible: [XCUIElement] = []
        for _ in 0 ..< 25 {
            Thread.sleep(forTimeInterval: 0.2)
            visible = (0 ..< pages.count)
                .map { pages.element(boundBy: $0) }
                .filter(\.isHittable)
            let identity = visible.map(\.identifier).joined(separator: "+")
            if !identity.isEmpty, identity == previous { break }
            previous = identity
        }
        XCTAssertEqual(
            visible.count, 1,
            "after \(label) the reader shows \(visible.count) pages "
                + "(\(visible.map { "\($0.identifier) at \($0.frame.minY)" }.joined(separator: ", ")))"
        )
        return try XCTUnwrap(visible.first, "after \(label) no reader page was on screen")
    }

    // MARK: - Translation

    /// Switching translation changes the English on the page and the pill's abbreviation.
    func testSwitchingTranslationChangesTheText() throws {
        // `--reset-state` wipes the App Group container first. Without it this test starts
        // on whatever translation the *previous* run left selected — PICKTHALL, after this
        // test itself has run once — and both the "Translation: ITANI" assertion and the
        // pill's measured width (106.9 pt against the spec's 62.2) fail on a second run.
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
        XCTAssertEqual(pill.label, "Translation: ITANI")
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
    /// The envelope marker. It exists so `LayoutSpecTests`' loader — which decodes every
    /// bare JSON in the bundle as a `LayoutSpec` — leaves the reader specs to this file,
    /// which unwraps them. Only `"reader-routing"` today; the routing it names is live.
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


/// SplitMix64, so the scrub targets are random but the run is reproducible from its seed.
/// (The host tests have their own copy; a UI test target shares no code with the package.)
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
