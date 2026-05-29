import XCTest

final class ScreenshotTour: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func test_captureFourScreens() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestBridge", "YES"
        ]
        app.launch()
        sleep(1)
        attach(named: "phase-2-home", from: app)

        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-2-level-select", from: app)

        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-2-gameplay-level-1", from: app)

        let bridge = app.buttons["bridge.nextMove"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 5))
        bridge.tap()
        sleep(1)
        bridge.tap()
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-2-level-complete", from: app)
    }

    /// Phase 3: six genuine screenshots, each from a deterministically-controlled
    /// app state (intro flags driven by launch arguments).
    func test_capturePhase3Screens() {
        let app = XCUIApplication()

        // 1. Onboarding (first run).
        launch(app, args: ["-uiTestResetIntros", "YES"])
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-onboarding", from: app)

        // 2. Home (intros skipped).
        launch(app, args: ["-uiTestSkipIntro", "YES"])
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-home", from: app)

        // 3. Level select.
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-level-select", from: app)

        // 4. Settings.
        launch(app, args: ["-uiTestSkipIntro", "YES"])
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.switches["settings.sound"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-settings", from: app)

        // 5. Gameplay with the Level 1 tutorial.
        launch(app, args: ["-uiTestResetTutorial", "YES", "-uiTestBridge", "YES"])
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-gameplay-tutorial", from: app)

        // 6. Level complete.
        launch(app, args: ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        let bridge = app.buttons["bridge.nextMove"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 5))
        bridge.tap()
        sleep(1)
        bridge.tap()
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-3-level-complete", from: app)
    }

    private func launch(_ app: XCUIApplication, args: [String]) {
        app.terminate()
        app.launchArguments = ["-com.swarpfoundation.ringknot.resetProgress", "YES"] + args
        app.launch()
    }

    private func attach(named name: String, from app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
