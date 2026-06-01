import XCTest

/// Phase 4A UI coverage for the rotatable-ring release mechanic. Rotation
/// gestures around a SpriteKit node are not reliably reproducible with raw
/// XCUITest coordinates, so alignment-sensitive assertions go through the
/// DEBUG-only test bridge (compiled out of Release builds). The bridge exposes
/// deterministic hooks: roll the next solution ring to aligned / misaligned, try
/// a release at the current gap, and perform a full rotate-then-pull move.
final class RingKnotPhase4UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    private func launchSkippingIntros() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestBridge", "YES",
            "-uiTestSkipIntro", "YES"
        ]
        app.launch()
        return app
    }

    private func launchWithTutorial() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestBridge", "YES",
            "-uiTestResetTutorial", "YES"
        ]
        app.launch()
        return app
    }

    // MARK: - Tutorial teaches rotation

    func test30_Level1TutorialShowsRotationPrompt() {
        let app = launchWithTutorial()
        openLevel(app: app, id: 1)
        let prompt = NSPredicate(format: "label CONTAINS[c] %@", "Rotate the open ring")
        let element = app.descendants(matching: .any).matching(prompt).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5),
                      "Level 1 tutorial should prompt the player to rotate the open ring")
    }

    // MARK: - Alignment is required before release

    func test31_PullBeforeAlignmentDoesNotRemove() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0")

        // Roll the gap away from the exit, then try to pull: nothing should leave.
        app.buttons["bridge.rotateMisaligned"].tap()
        app.buttons["bridge.tryRelease"].tap()

        XCTAssertTrue(labelStays(moves, equalTo: "0", forSeconds: 1.0),
                      "A pull before alignment must not remove the ring")
        XCTAssertFalse(app.buttons["completion.next"].exists)
    }

    func test32_RotateToAlignThenPullRemovesAndCountsOnce() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0")

        // Rotation alone never advances the move counter.
        app.buttons["bridge.rotateAligned"].tap()
        XCTAssertTrue(labelStays(moves, equalTo: "0", forSeconds: 0.6),
                      "Rolling the gap into alignment is not a move")

        // Now the aligned ring releases on a pull, counting exactly one move.
        app.buttons["bridge.tryRelease"].tap()
        XCTAssertTrue(waitForLabel(moves, to: "1"),
                      "An aligned ring should release and count one move")
    }

    func test33_HintOnUnalignedRingKeepsHUD() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        let hint = app.buttons["hud.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        hint.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].exists,
                      "HUD should survive a hint on an unaligned ring")
        XCTAssertEqual(app.staticTexts["hud.moves"].label, "0",
                       "A hint is guidance only and must not count as a move")
    }

    // MARK: - Full rotation-aware move + progression

    func test34_RotationMoveCompletesLevel1AndUnlocksLevel2() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))

        let rotationMove = app.buttons["bridge.rotationMove"]
        rotationMove.tap()
        XCTAssertTrue(waitForLabel(moves, to: "1"))
        rotationMove.tap()
        XCTAssertTrue(waitForLabel(moves, to: "2"))

        let levelSelect = app.buttons["completion.levelSelect"]
        XCTAssertTrue(levelSelect.waitForExistence(timeout: 5),
                      "Completion overlay did not appear after rotation moves")
        levelSelect.tap()
        let card2 = app.buttons["levelCard.2"]
        XCTAssertTrue(card2.waitForExistence(timeout: 5))
        XCTAssertTrue(card2.isEnabled, "Level 2 should unlock after completing Level 1")
    }

    // MARK: - Settings replay tutorial still works under the new mechanic

    func test35_SettingsReplayTutorialReArmsRotationTutorial() {
        let app = launchSkippingIntros()
        app.buttons["home.settings"].tap()
        let replay = app.buttons["settings.replayTutorial"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()   // dismisses settings, re-arms the Level 1 tutorial
        openLevel(app: app, id: 1)
        let prompt = NSPredicate(format: "label CONTAINS[c] %@", "Rotate the open ring")
        let element = app.descendants(matching: .any).matching(prompt).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5),
                      "Replaying the tutorial should show the rotation prompt again")
    }

    // MARK: - Helpers

    private func openLevel(app: XCUIApplication, id: Int) {
        let play = app.buttons["home.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let card = app.buttons["levelCard.\(id)"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        if !card.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        card.tap()
    }

    @discardableResult
    private func waitForLabel(_ element: XCUIElement, to value: String,
                              timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.label == value { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Assert a label holds `value` for the whole window (catches a wrong release
    /// that would flip it).
    private func labelStays(_ element: XCUIElement, equalTo value: String,
                            forSeconds seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if !element.exists || element.label != value { return false }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return element.exists && element.label == value
    }
}
