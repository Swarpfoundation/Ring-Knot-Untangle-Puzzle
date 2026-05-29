import XCTest

final class RingKnotUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAppWithFreshProgress() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestBridge", "YES"
        ]
        app.launch()
        return app
    }

    func test01_AppLaunchesToHomeScreen() {
        let app = launchAppWithFreshProgress()
        let play = app.buttons["home.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "Play button never appeared")
    }

    func test02_TapPlayOpensLevelSelect() {
        let app = launchAppWithFreshProgress()
        let play = app.buttons["home.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let grid = app.scrollViews["levelSelect.grid"]
        let level1 = app.buttons["levelCard.1"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5) || level1.waitForExistence(timeout: 5),
                      "Level select grid never appeared")
    }

    func test03_OpenLevel1() {
        let app = launchAppWithFreshProgress()
        openLevel1(app: app)
        let hudLevel = app.staticTexts["hud.levelNumber"]
        XCTAssertTrue(hudLevel.waitForExistence(timeout: 5))
        XCTAssertEqual(hudLevel.label, "Level 1")
    }

    func test04_ValidMoveIncrementsMoveCounter() {
        let app = launchAppWithFreshProgress()
        openLevel1(app: app)
        let movesLabel = app.staticTexts["hud.moves"]
        XCTAssertTrue(movesLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(movesLabel.label, "0")
        // Use the DEBUG-only bridge
        app.buttons["bridge.nextMove"].tap()
        XCTAssertTrue(waitForLabel(movesLabel, to: "1"))
    }

    func test05_InvalidMoveBeforePrereq() {
        let app = launchAppWithFreshProgress()
        // Use level 1 — C1 requires S1, so attempting C1 first is blocked.
        openLevel1(app: app)
        let movesLabel = app.staticTexts["hud.moves"]
        XCTAssertTrue(movesLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(movesLabel.label, "0")
        app.buttons["bridge.invalidMove"].tap()
        // The move counter still increments because blocked attempts are tracked.
        XCTAssertTrue(waitForLabel(movesLabel, to: "1"))
        // But the level should NOT be complete after a single invalid attempt.
        XCTAssertFalse(app.buttons["completion.next"].exists)
    }

    func test06_HintRevealsArrow() {
        let app = launchAppWithFreshProgress()
        openLevel1(app: app)
        let hint = app.buttons["hud.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        hint.tap()
        // We only verify the button does not crash the app and the HUD survives.
        let hudLevel = app.staticTexts["hud.levelNumber"]
        XCTAssertTrue(hudLevel.exists)
    }

    func test07_CompleteLevel1ShowsCompletionUI() {
        let app = launchAppWithFreshProgress()
        openLevel1(app: app)
        let movesLabel = app.staticTexts["hud.moves"]
        XCTAssertTrue(movesLabel.waitForExistence(timeout: 5))
        let bridge = app.buttons["bridge.nextMove"]
        // Level 1 has 2 rings (S1 then C1).
        bridge.tap()
        XCTAssertTrue(waitForLabel(movesLabel, to: "1"))
        bridge.tap()
        XCTAssertTrue(waitForLabel(movesLabel, to: "2"))
        let nextButton = app.buttons["completion.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5),
                      "Completion overlay did not appear")
    }

    // MARK: - Helpers

    private func openLevel1(app: XCUIApplication) {
        openLevel(app: app, id: 1)
    }

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

    private func waitForLabel(_ element: XCUIElement, to value: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.label == value { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }
}
