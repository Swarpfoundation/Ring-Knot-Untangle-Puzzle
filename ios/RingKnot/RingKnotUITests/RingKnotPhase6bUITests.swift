import XCTest

/// Phase 6B — interlock geometry + art polish. Confirms the refined tutorial copy
/// and captures genuine simulator screenshots of the polished anchors/clips on
/// early, mid, and late boards (including a blocked-feedback shot).
final class RingKnotPhase6bUITests: XCTestCase {

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
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
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

    /// Tutorial copy mentions anchors and clips (Phase 6B wording).
    func testLevel1TutorialMentionsAnchorAndClip() {
        let app = XCUIApplication()
        launch(app, ["-uiTestResetTutorial", "YES"])
        openLevel(app, id: 1)
        let panel = app.staticTexts["tutorial.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let label = panel.label.lowercased()
        XCTAssertTrue(label.contains("anchor"), "tutorial should mention anchors: \(label)")
        XCTAssertTrue(label.contains("clip"), "tutorial should mention clips: \(label)")
    }

    /// Six genuine polished-board screenshots.
    func testCapturePhase6bScreens() {
        let app = XCUIApplication()

        // 1. Level 1 polished anchor + clips (tutorial visible).
        launch(app, ["-uiTestResetTutorial", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6b-level-1-polished-anchor")

        // 2. First ring aligned: ready glow + clip highlight read together.
        app.buttons["bridge.rotateAligned"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6b-level-1-clip-highlight")

        // 3. Blocked feedback: align the still-blocked copper knot and try to pull
        //    it while its blocker remains — the blocker ring + clamp flash amber.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        app.buttons["bridge.tryReleaseBlocked"].tap()   // refused → blocker flash
        Thread.sleep(forTimeInterval: 0.18)             // catch mid-flash
        attach(app, "phase-6b-blocked-feedback")

        // 4. Level 10 layered interlocks.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 10)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6b-level-10-layered-interlocks")

        // 5. Level 20 polished final knot.
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestUnlockAll", "YES"])
        openLevel(app, id: 20)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6b-level-20-polished-final-knot")

        // 6. Anchors remain as removable rings are cleared (Level 1, silver gone).
        launch(app, ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        openLevel(app, id: 1)
        app.buttons["bridge.rotationMove"].tap()        // free the silver ring
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "phase-6b-level-complete-anchors-remain")
    }
}
