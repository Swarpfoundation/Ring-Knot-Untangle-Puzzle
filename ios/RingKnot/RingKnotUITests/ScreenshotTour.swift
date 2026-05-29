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

    private func attach(named name: String, from app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
