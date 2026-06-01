import XCTest

/// Phase 6C — true tube occlusion + neighbour-aware bridge geometry. Captures
/// genuine simulator screenshots of the contact-band rendering on early/mid/late
/// boards, plus a blocked-band highlight and the copper knot staying visible.
final class RingKnotPhase6cUITests: XCTestCase {

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
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        var tries = 0
        while !card.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        card.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCapturePhase6cScreens() {
        let app = XCUIApplication()

        // 1. Level 1: the clamp now spans the true contact between the rings.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6c-level-1-true-contact")

        // 2. Blocked-band highlight: try to pull the still-held copper knot.
        app.buttons["bridge.tryReleaseBlocked"].tap()
        Thread.sleep(forTimeInterval: 0.18)
        attach(app, "phase-6c-level-1-blocker-highlight")

        // 3. Level 10: layered bridge depth.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 10)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6c-level-10-bridge-depth")

        // 4. Level 20: dense board with over/under tube occlusion.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 20)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6c-level-20-tube-occlusion")
        // Same board emphasises the copper knot staying visible amid the clips.
        attach(app, "phase-6c-copper-knot-visible")

        // 5. Anchors + their bands remain as removable rings are cleared.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        app.buttons["bridge.rotationMove"].tap()        // free the silver ring
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6c-level-complete-anchors-remain")
    }
}
