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

    /// Phase 4A: the rotatable-ring mechanic — tutorial, an unaligned gap, an
    /// aligned (ready-to-pull) gap, and the completion screen. Each shot is from a
    /// deterministically-controlled state driven by launch args + the test bridge.
    func test_capturePhase4Screens() {
        let app = XCUIApplication()

        // 1. Level 1 rotation tutorial.
        launch(app, args: ["-uiTestResetTutorial", "YES", "-uiTestBridge", "YES"])
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-4a-rotation-tutorial", from: app)

        // 2. A clearly unaligned gap (ring rolled off the exit).
        launch(app, args: ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.buttons["bridge.rotateMisaligned"].waitForExistence(timeout: 5))
        app.buttons["bridge.rotateMisaligned"].tap()
        sleep(1)
        attach(named: "phase-4a-gap-unaligned", from: app)

        // 3. The same ring rolled into alignment (ready-to-pull glow).
        app.buttons["bridge.rotateAligned"].tap()
        sleep(1)
        attach(named: "phase-4a-gap-aligned", from: app)

        // 4. Level complete via full rotate-then-pull moves.
        let rotationMove = app.buttons["bridge.rotationMove"]
        rotationMove.tap()
        sleep(1)
        rotationMove.tap()
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5))
        sleep(1)
        attach(named: "phase-4a-level-complete", from: app)
    }

    /// Phase 4B stills: a silver ring rolled into the ready state, the board right
    /// after a *real* pull-release removes it, and a copper ring in the ready
    /// state — evidence that alignment + the "ready" glow read for both ring kinds
    /// and that a genuine outward pull releases an aligned ring.
    func test_capturePhase4bScreens() {
        let app = XCUIApplication()

        launch(app, args: ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.buttons["bridge.rotateAligned"].waitForExistence(timeout: 5))

        // 1. Silver ring aligned + ready.
        app.buttons["bridge.rotateAligned"].tap()
        sleep(1)
        attach(named: "phase-4b-ready-state", from: app)

        // 2. Real outward pull releases it; capture the board with the silver ring
        //    gone (move counter at 1, only the copper core left).
        realPullFirstRingUpward(app: app)
        XCTAssertTrue(waitForMoves(app, equals: "1"), "real pull did not release the ring")
        sleep(1)
        attach(named: "phase-4b-pull-release", from: app)

        // 3. Align the copper ring → copper ready glow.
        app.buttons["bridge.rotateAligned"].tap()
        sleep(1)
        attach(named: "phase-4b-copper-ready", from: app)
    }

    private func waitForMoves(_ app: XCUIApplication, equals value: String,
                              timeout: TimeInterval = 5) -> Bool {
        let moves = app.staticTexts["hud.moves"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if moves.exists && moves.label == value { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Drives a deterministic Level 1 demo with pauses so an external screen
    /// recording (see tools/capture_phase4b_demo.sh) shows: unaligned start →
    /// rotate → ready → real pull-release → completion. No assertions on visuals;
    /// it is a scripted walkthrough, not a screenshot test.
    func test_phase4bDemoWalkthrough() {
        let app = XCUIApplication()
        launch(app, args: ["-uiTestSkipIntro", "YES", "-uiTestBridge", "YES"])
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["levelCard.1"].waitForExistence(timeout: 5))
        app.buttons["levelCard.1"].tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
        sleep(1)
        app.buttons["bridge.rotateMisaligned"].tap()   // show a clearly off gap
        sleep(1)
        app.buttons["bridge.rotateAligned"].tap()       // roll into the ready state
        sleep(2)
        realPullFirstRingUpward(app: app)               // real outward pull → release
        sleep(2)
        app.buttons["bridge.rotationMove"].tap()         // free the copper → complete
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5))
        sleep(2)
    }

    /// Real coordinate pull on Level 1's first ring (cell B3), straight up (North
    /// exit), reproducing the scene layout from the board element frame.
    private func realPullFirstRingUpward(app: XCUIApplication) {
        let board = app.descendants(matching: .any).matching(identifier: "game.board").firstMatch
        guard board.waitForExistence(timeout: 5) else { return }
        let f = board.frame
        let w = f.width, h = f.height
        let cell = (min(w, h) - 32) / 5
        let boardH = 5 * cell
        let originX = (w - boardH) / 2
        let originYScene = (h - boardH) / 2 + cell * 0.4
        let sceneX = originX + 2.5 * cell
        let sceneY = originYScene + (5 - 1 - 1 + 0.5) * cell
        let screenY = h - sceneY
        let start = board.coordinate(withNormalizedOffset: CGVector(dx: sceneX / w, dy: screenY / h))
        let end = board.coordinate(withNormalizedOffset: CGVector(dx: sceneX / w, dy: (screenY - 0.8 * cell) / h))
        start.press(forDuration: 0.1, thenDragTo: end)
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
