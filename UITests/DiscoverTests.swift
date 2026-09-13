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

    private func launch(_ route: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot", route] + extra
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

    /// The owner's complaint: "when you scroll the verses on the original app all of them
    /// have the same placement". `--discover-index N` makes the Nth card of the day's feed
    /// the first page, so three very different units — a two-ayah one, the corpus's longest
    /// (Luqman 31:13-19, seven ayat) and its shortest (At-Tawbah 9:119) — can be framed the
    /// same way and compared. `DiscoverCardLayoutTests` proves the arithmetic over all 326;
    /// this proves the views actually lay out that way.
    func testEveryCardHasTheSameGeometry() throws {
        var frames: [(index: Int, frame: CGRect)] = []
        // On the fixed date's feed, 0 is the capture card (Al-Ankabut 29:68-69, whose
        // quote is six lines), 150 is the corpus's longest passage (Luqman 31:13-19, 215
        // words — the one card whose quote still truncates) and 25 is Al-Baqarah
        // 2:285-286, which drops both MEANING and DID YOU KNOW. If the Phase 4m body plan
        // could change a card's height, these three would show it.
        for index in [0, 150, 25] {
            let app = launch("discover", extra: ["--discover-index", "\(index)"])
            requireRouted(app, "discover.card")
            let card = app.descendants(matching: .any).matching(identifier: "discover.card").firstMatch
            frames.append((index, card.frame))
            app.terminate()
        }

        let first = try XCTUnwrap(frames.first)
        for other in frames.dropFirst() {
            // A point of slack: the card's accessibility frame is the union of its
            // children's, and those are snapped to the @3x pixel grid, so two cards whose
            // arithmetic is identical can report heights 2/3 pt apart.
            XCTAssertEqual(
                Double(other.frame.minY), Double(first.frame.minY), accuracy: 1,
                "card \(other.index) starts at a different y than card \(first.index)"
            )
            XCTAssertEqual(
                Double(other.frame.height), Double(first.frame.height), accuracy: 1,
                "card \(other.index) is a different height than card \(first.index)"
            )
        }
    }

    /// Amendment 2: no translation badge on the card or the Deep Study header, and no
    /// Arabic line on the card. `ITANI` is the bundled default's badge; the reader
    /// toolbar's pill is where it still belongs.
    func testTheCardCarriesNoBadgeAndNoArabic() throws {
        let app = launch("discover")
        requireRouted(app, "discover.card")
        XCTAssertFalse(app.staticTexts["ITANI"].exists, "the translation badge is back on the card")

        let quote = app.descendants(matching: .any).matching(identifier: "discover.quote").firstMatch
        XCTAssertTrue(quote.exists)
        // The muted Arabic layer is `accessibilityHidden`, so it cannot be asserted away by
        // label; its absence shows in the quote's height, which is a whole number of English
        // line boxes and nothing else. Since Phase 4m that number is the passage's own line
        // count rather than a fixed four, so the test checks the multiple, not a ceiling.
        let pitch = 16 * 1.371
        let lines = Double(quote.frame.height) / pitch
        XCTAssertEqual(
            lines, lines.rounded(), accuracy: 0.06,
            "the quote block is \(quote.frame.height) pt, not a whole number of \(pitch) pt lines — "
                + "the Arabic slot looks like it is back"
        )
    }

    /// Phase 4m, the owner's ask: "ideally the entirety of the verse fits on the card. the
    /// meaning/did you know can be cut off." Card 0 of the fixed-date feed is Al-Ankabut
    /// 29:68-69, whose passage needs six lines where the Phase 4i slot gave four; card 25
    /// is Al-Baqarah 2:285-286, long enough that both MEANING and DID YOU KNOW give way.
    func testTheQuoteTakesTheLinesItNeedsAndTheProseGivesWay() throws {
        let app = launch("discover", extra: ["--discover-index", "0"])
        requireRouted(app, "discover.card")
        let quote = app.descendants(matching: .any).matching(identifier: "discover.quote").firstMatch
        XCTAssertGreaterThan(
            quote.frame.height, 4 * 16 * 1.371 + 1,
            "the quote is still capped at the old four-line slot"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "discover.meaning").firstMatch.exists,
            "MEANING should still be on a card whose quote is six lines"
        )
        app.terminate()

        let long = launch("discover", extra: ["--discover-index", "25"])
        requireRouted(long, "discover.card")
        // The feed is a lazy pager and the neighbouring cards are realised too, so
        // "does a DID YOU KNOW box exist" is not the question — "is one inside *this*
        // card" is.
        let card = long.descendants(matching: .any).matching(identifier: "discover.card").firstMatch
        let boxes = long.descendants(matching: .any)
            .matching(identifier: "discover.didYouKnow").allElementsBoundByIndex
        XCTAssertFalse(
            boxes.contains { card.frame.intersects($0.frame) },
            "DID YOU KNOW should have given way to Al-Baqarah 2:285-286's passage"
        )
        XCTAssertTrue(
            long.buttons["discover.deepStudy"].firstMatch.exists,
            "\"Deep study ›\" must stay on the card whatever the body plan"
        )
    }

    func testDeepStudyHeaderCarriesNoBadge() throws {
        let app = launch("deepstudy")
        requireRouted(app, "deepstudy.quote")
        XCTAssertFalse(app.staticTexts["ITANI"].exists, "the translation badge is back on the Deep Study header")
    }

    func testDeepStudyOpensFromTheCardAndCloses() throws {
        let app = launch("discover")
        requireRouted(app, "discover.card")

        // The feed is a lazy pager: the neighbouring cards are realised too, so there is more
        // than one "Deep study" button in the tree and an unqualified tap is ambiguous. The
        // first match is the card on screen.
        // On a cold simulator the first tap after the feed appears can land while the pager
        // is still settling and go nowhere; the page is only ever a tap away, so tap again
        // (bounded) rather than fail on scheduler noise.
        let page = app.descendants(matching: .any).matching(identifier: "deepstudy").firstMatch
        for attempt in 1...3 {
            app.buttons["discover.deepStudy"].firstMatch.tap()
            if page.waitForExistence(timeout: attempt == 3 ? 15 : 5) { break }
        }
        XCTAssertTrue(page.exists, "Deep Study never appeared")
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
