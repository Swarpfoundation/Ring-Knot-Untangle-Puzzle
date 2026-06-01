import XCTest

/// Phase 6D — split-tube masking + motion polish. Genuine simulator screenshots of
/// the split-tube over-arc rendering, the gap clearing a fixed clip, a blocked
/// band pulse, bridge depth, the premium knot, and clean band retirement.
final class RingKnotPhase6dUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ app: XCUIApplication, _ args: [String]) {
        app.launchArguments = ["-com.swarpfoundation.ringknot.resetProgress", "YES",
                               "-uiTestSoundOff", "YES"] + args
        app.launch()
    }

    private func openLevel(_ app: XCUIApplication, id: Int) {
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 15))
        app.buttons["home.play"].tap()
        let card = app.buttons["levelCard.\(id)"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        var tries = 0
        while !card.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        card.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 10))
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCapturePhase6dScreens() {
        let app = XCUIApplication()

        // 1. Level 1 with split-tube over-arc rendering on the contact bands.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6d-level-1-split-tube")

        // 2. The open ring's gap rolled clear of its fixed clip (ready glow).
        app.buttons["bridge.rotateAligned"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6d-level-1-gap-clears-clip")

        // 3. Blocked-band pulse: try to pull the still-held copper knot.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        app.buttons["bridge.tryReleaseBlocked"].tap()
        Thread.sleep(forTimeInterval: 0.16)
        attach(app, "phase-6d-blocked-band-pulse")

        // 4. Level 10 bridge occlusion.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 10)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6d-level-10-bridge-occlusion")

        // 5. Level 20 premium knot (copper stays on top).
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 20)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6d-level-20-premium-knot")

        // 6. Clean retirement: clear the silver ring; its bands slide+fade out.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        app.buttons["bridge.rotationMove"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6d-level-complete-clean-retire")
    }
}
