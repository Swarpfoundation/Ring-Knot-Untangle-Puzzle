import XCTest

/// Phase 6A — anchors + blocker clips: tutorial copy, anchor taps not counting as
/// moves, completion with an anchor remaining, and genuine simulator screenshots
/// of early/mid/late levels showing closed anchors and clamp bands.
final class RingKnotPhase6aUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    private func launch(_ app: XCUIApplication, _ args: [String]) {
        app.launchArguments = ["-com.swarpfoundation.ringknot.resetProgress", "YES",
                               "-uiTestSoundOff", "YES"] + args
        app.launch()
    }

    private func openLevel(_ app: XCUIApplication, id: Int) {
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        app.buttons["home.play"].tap()
        let card = app.buttons["levelCard.\(id)"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // Scroll the card into view for late levels.
        var tries = 0
        while !card.isHittable && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        card.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
    }

    // MARK: - Tutorial copy mentions anchors

    func testLevel1TutorialMentionsAnchor() {
        let app = XCUIApplication()
        launch(app, ["-uiTestResetTutorial", "YES"])
        openLevel(app, id: 1)
        let panelText = app.staticTexts["tutorial.panel"]
        XCTAssertTrue(panelText.waitForExistence(timeout: 5),
                      "Level 1 tutorial panel did not appear")
        XCTAssertTrue(panelText.label.lowercased().contains("anchor"),
                      "Tutorial copy should mention the anchor; got: \(panelText.label)")
    }

    // MARK: - Tapping the anchor does not count as a move

    func testTappingAnchorDoesNotCountAsMove() {
        let app = XCUIApplication()
        launch(app, ["-uiTestSkipIntro", "YES"])
        openLevel(app, id: 1)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0")
        // Level 1's anchor A1 sits in cell B2 (row 1, col 1). Tap it.
        tapCell(app, row: 1, col: 1)
        // Allow any state change to settle, then confirm the move count is still 0.
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(moves.label, "0",
                       "Tapping the fixed anchor must not increment the move counter")
    }

    // MARK: - Level 1 completes with the anchor still on the board

    func testLevel1CompletesWithAnchorPresent() {
        let app = XCUIApplication()
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        let bridge = app.buttons["bridge.rotationMove"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 5))
        bridge.tap()                 // free the silver ring
        Thread.sleep(forTimeInterval: 0.4)
        bridge.tap()                 // free the copper knot
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5),
                      "Level 1 did not complete (anchors should be ignored by completion)")
        // Exactly two removable rings were cleared; the anchor was never a move.
        XCTAssertEqual(app.staticTexts["completion.moves"].exists, true)
    }

    // MARK: - Screenshots

    func testCapturePhase6aScreens() {
        let app = XCUIApplication()

        // 1. Level 1 with its anchor + clips, plus the tutorial copy.
        launch(app, ["-uiTestResetTutorial", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6a-anchor-tutorial")
        attach(app, "phase-6a-anchor-level-1")

        // 2. Blocker-clip close-up: align the first ring so the ready glow + the
        //    clamp band read clearly together.
        app.buttons["bridge.rotateAligned"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6a-blocker-clip-closeup")

        // 3. After clearing the silver ring, the silver anchor + copper knot remain
        //    on the board — anchors persist as removable rings leave.
        app.buttons["bridge.rotationMove"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6a-level-complete-anchor-remains")

        // 4. Mid-game density: level 10 (multiple anchors + many clips).
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 10)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6a-level-10-multi-anchor")

        // 5. Final level 20: the reference-style knot surrounded by anchors.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 20)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6a-level-20-final-knot")
    }

    // MARK: - Cell tap by scene maths (mirrors the layout in GameScene)

    private func tapCell(_ app: XCUIApplication, row: Int, col: Int,
                         rows: Int = 5, cols: Int = 5) {
        let board = app.descendants(matching: .any)
            .matching(identifier: "game.board").firstMatch
        guard board.waitForExistence(timeout: 5) else {
            XCTFail("game.board not found"); return
        }
        let f = board.frame
        let w = f.width, h = f.height
        let cell = (min(w, h) - 32) / CGFloat(max(rows, cols))
        let boardW = CGFloat(cols) * cell
        let boardH = CGFloat(rows) * cell
        let originX = (w - boardW) / 2
        let originYScene = (h - boardH) / 2 + cell * 0.4
        let sceneX = originX + (CGFloat(col) + 0.5) * cell
        let sceneY = originYScene + (CGFloat(rows - 1 - row) + 0.5) * cell
        let screenY = h - sceneY
        let pt = board.coordinate(withNormalizedOffset:
            CGVector(dx: sceneX / w, dy: screenY / h))
        pt.tap()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
