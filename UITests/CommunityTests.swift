import XCTest

/// The Community tab's flows, driven through the real app.
///
/// `AppShell/TabRoot` hands the tab to `FeatureCommunity` (Phase 3e), so these are real
/// assertions: `requireCommunity` waits for the screen and fails the test if it is not
/// there. It used to skip while the tab was the Phase-1 placeholder.
final class CommunityTests: XCTestCase {
    /// Frames in the 393x852 pt space `Reference/community-dark.png` was captured in, measured off
    /// that capture by scanning runs of constant colour (the scan lines are in
    /// `FeatureCommunity/CommunityStyle.swift`).
    private enum Reference {
        static let size = CGSize(width: 393, height: 852)
        /// Green card: row y=560 runs x=60..1113, col x=70 runs y=306..832 (px, @3x).
        static let givingCard = CGRect(x: 20, y: 102, width: 353, height: 176)
        /// First organisation card top edge, col x=300: the artwork starts at y=1243 px.
        static let firstCardTop: CGFloat = 414.3
        /// Vote pill: x=895..1070, y=1771..1859 px.
        static let voteButton = CGRect(x: 298.3, y: 590.3, width: 58.7, height: 29.3)
        static let tolerance: CGFloat = 6
        /// Deep-page `y` values get a wider band. The reference was captured on a 393x852 pt
        /// screen and the simulator is 402x874, so normalising divides every fixed-size run of
        /// content by 852/874 = 0.9748. That is invisible at the top of the page (the giving card
        /// is anchored there) but by the vote pill, ~300 pt of fixed content below the card, it
        /// has eaten about 6 pt — a scaling artefact, not a layout error. Measured drift at the
        /// pill is 5.7 pt; 9 keeps the assertion meaningful without failing on the artefact.
        static let stackTolerance: CGFloat = 9
    }

    private func launch(_ app: XCUIApplication = XCUIApplication()) -> XCUIApplication {
        app.launchArguments = ["--screenshot", "community"]
        app.launchEnvironment["SCROLL_FIXED_DATE"] = "2026-09-14"
        app.launch()
        return app
    }

    /// Waits for `CommunityView` and fails if the route does not reach it.
    ///
    /// `screen.community.label` is the Phase-1 placeholder's static text; it is asserted
    /// absent so a regression back to the placeholder reads as "the placeholder is on
    /// screen" rather than as a missing identifier somewhere further down the test.
    private func requireCommunity(_ app: XCUIApplication) throws {
        XCTAssertTrue(
            app.staticTexts["community.given.amount"].waitForExistence(timeout: 10),
            "CommunityView is not on screen for --screenshot community"
        )
        XCTAssertFalse(
            app.staticTexts["screen.community.label"].exists,
            "AppShell is rendering PlaceholderScreen for the Community tab again"
        )
    }

    private func scale(_ app: XCUIApplication) -> CGPoint {
        let window = app.windows.firstMatch.frame
        guard window.width > 0, window.height > 0 else { return CGPoint(x: 1, y: 1) }
        return CGPoint(
            x: Reference.size.width / window.width,
            y: Reference.size.height / window.height
        )
    }

    private func referenceFrame(_ element: XCUIElement, in app: XCUIApplication) -> CGRect {
        let factor = scale(app)
        return CGRect(
            x: element.frame.minX * factor.x,
            y: element.frame.minY * factor.y,
            width: element.frame.width * factor.x,
            height: element.frame.height * factor.y
        )
    }

    // MARK: Tests

    func testCommunityScreenShowsTheGivingCardAndEveryCharity() throws {
        let app = launch()
        try requireCommunity(app)

        XCTAssertTrue(app.descendants(matching: .any)["community.givenCard"].exists)
        XCTAssertTrue(app.staticTexts["community.given.amount"].exists)
        XCTAssertEqual(app.staticTexts["community.given.amount"].label, "$0", "the total is not given yet")
        XCTAssertTrue(app.staticTexts["community.title"].exists)

        for id in ["islamic-relief", "penny-appeal", "human-appeal"] {
            XCTAssertTrue(
                app.buttons["community.vote.\(id)"].exists,
                "no vote button for \(id)"
            )
        }
    }

    func testGivingCardAndVoteButtonMatchTheReferenceGeometry() throws {
        let app = launch()
        try requireCommunity(app)

        let card = referenceFrame(app.descendants(matching: .any)["community.givenCard"], in: app)
        XCTAssertEqual(card.minX, Reference.givingCard.minX, accuracy: Reference.tolerance)
        XCTAssertEqual(card.minY, Reference.givingCard.minY, accuracy: Reference.tolerance)
        XCTAssertEqual(card.width, Reference.givingCard.width, accuracy: Reference.tolerance)
        XCTAssertEqual(card.height, Reference.givingCard.height, accuracy: Reference.tolerance)

        let vote = referenceFrame(app.buttons["community.vote.islamic-relief"], in: app)
        XCTAssertEqual(vote.minX, Reference.voteButton.minX, accuracy: Reference.tolerance)
        XCTAssertEqual(vote.minY, Reference.voteButton.minY, accuracy: Reference.stackTolerance)
        XCTAssertEqual(vote.height, Reference.voteButton.height, accuracy: Reference.tolerance)

        let firstCard = referenceFrame(app.descendants(matching: .any)["community.card.islamic-relief"], in: app)
        XCTAssertEqual(firstCard.minY, Reference.firstCardTop, accuracy: Reference.stackTolerance)
    }

    /// The DoD: a vote survives a cold launch.
    func testVotePersistsAcrossRelaunch() throws {
        let app = launch()
        try requireCommunity(app)

        let vote = app.buttons["community.vote.penny-appeal"]
        XCTAssertTrue(vote.waitForExistence(timeout: 5))
        XCTAssertEqual(vote.label, "Vote for Penny Appeal")
        vote.tap()
        XCTAssertTrue(
            vote.label.hasPrefix("Voted for Penny Appeal"),
            "the button did not switch to its Voted state, got '\(vote.label)'"
        )
        // Give UserStore's debounced write time to land before the process goes away.
        Thread.sleep(forTimeInterval: 1)
        app.terminate()

        let relaunched = launch(XCUIApplication())
        let restored = relaunched.buttons["community.vote.penny-appeal"]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue(
            restored.label.hasPrefix("Voted for Penny Appeal"),
            "the vote did not survive the relaunch, got '\(restored.label)'"
        )
        XCTAssertEqual(
            relaunched.buttons["community.vote.islamic-relief"].label,
            "Vote for Islamic Relief Worldwide",
            "the vote is meant to be exclusive"
        )

        // Leave the device as we found it, so the next test starts from no vote.
        restored.tap()
        Thread.sleep(forTimeInterval: 1)
    }

    func testVotingIsExclusiveAndCanBeWithdrawn() throws {
        let app = launch()
        try requireCommunity(app)

        let relief = app.buttons["community.vote.islamic-relief"]
        let human = app.buttons["community.vote.human-appeal"]
        XCTAssertTrue(relief.waitForExistence(timeout: 5))

        relief.tap()
        XCTAssertTrue(relief.label.hasPrefix("Voted for"))

        human.tap()
        XCTAssertTrue(human.label.hasPrefix("Voted for"))
        XCTAssertFalse(relief.label.hasPrefix("Voted for"), "two organisations cannot both hold the vote")

        human.tap()
        XCTAssertFalse(human.label.hasPrefix("Voted for"), "tapping the voted card again withdraws the vote")
        Thread.sleep(forTimeInterval: 1)
    }
}
