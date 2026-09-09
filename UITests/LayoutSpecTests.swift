import XCTest

/// Runs every spec in `UITests/Specs/*.json`: launch the route, find each element,
/// and assert its frame in reference points is within tolerance.
///
/// Set `SCROLL_RECORD_SPECS=1` in the scheme's test environment to print the observed
/// frames instead of asserting them, which is how a new spec gets its numbers.
/// (`xcodebuild` build settings do not reach the test runner's environment; edit the
/// scheme, or flip the flag locally while recording.)
final class LayoutSpecTests: XCTestCase {
    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["SCROLL_RECORD_SPECS"] == "1"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testLayoutSpecs() throws {
        let specs = try LayoutSpec.loadAll()
        XCTAssertFalse(specs.isEmpty, "no layout specs found in the UI test bundle")

        for spec in specs {
            let app = XCUIApplication()
            app.launchArguments = ["--screenshot", spec.route]
            app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
            app.launch()
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
                guard found.exists else { continue }

                let observed = CGRect(
                    x: found.frame.minX * scaleX,
                    y: found.frame.minY * scaleY,
                    width: found.frame.width * scaleX,
                    height: found.frame.height * scaleY
                )

                if isRecording {
                    print(String(
                        format: "SPEC %@ %@ -> \"frame\": { \"x\": %.1f, \"y\": %.1f, \"width\": %.1f, \"height\": %.1f }",
                        spec.id, element.name, observed.minX, observed.minY, observed.width, observed.height
                    ))
                    continue
                }
                if element.existenceOnly == true {
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

    private func assertClose(_ observed: CGFloat, _ expected: CGFloat, _ tolerance: Double, _ label: String) {
        XCTAssertEqual(
            Double(observed), Double(expected), accuracy: tolerance,
            "\(label): expected \(expected) +/- \(tolerance), got \(observed)"
        )
    }
}
