import XCTest

/// Phase 4B real-gesture coverage. These tests perform actual coordinate drags on
/// the SpriteKit board (not just the DEBUG bridge), to prove the rotate-then-pull
/// rules hold under a genuine touch:
///
///  * A straight outward pull on a **misaligned** ring does not release it.
///  * The same pull on a ring the bridge has **aligned** does release it.
///
/// The drag start is computed from the board element's frame using the scene's
/// known layout maths, so it lands on Level 1's first silver ring (cell B3). A
/// straight radial drag keeps a roughly constant bearing from the centre, so it
/// adds no rotation — isolating the *pull* half of the gesture. Rotation itself
/// stays bridge-driven (raw circular drags around a SpriteKit node are not a
/// reliable XCUITest primitive); see docs/qa.md for the coverage split.
final class RingKnotRealGestureUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestBridge", "YES",
            "-uiTestSkipIntro", "YES"
        ]
        app.launch()
        return app
    }

    func test40_RealPullOnMisalignedRingDoesNotRelease() {
        let app = launch()
        openLevel1(app: app)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0")

        // S1 starts misaligned; a straight upward pull must be refused.
        pullFirstRingUpward(app: app)
        XCTAssertTrue(labelStays(moves, equalTo: "0", forSeconds: 1.0),
                      "A real pull before alignment must not remove the ring")
        XCTAssertFalse(app.buttons["completion.next"].exists)
    }

    func test41_RealPullReleasesBridgeAlignedRing() {
        let app = launch()
        openLevel1(app: app)
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))

        // Align deterministically via the bridge, then release with a real drag.
        app.buttons["bridge.rotateAligned"].tap()
        XCTAssertTrue(labelStays(moves, equalTo: "0", forSeconds: 0.4),
                      "Aligning must not count as a move")
        pullFirstRingUpward(app: app)
        XCTAssertTrue(waitForLabel(moves, to: "1"),
                      "A real outward pull on an aligned ring should release it")
    }

    // MARK: - Board geometry helpers

    /// Press on Level 1's first silver ring (cell B3) and drag straight up by
    /// ~0.8 cell — its North exit — reproducing the scene's layout maths from the
    /// board element's frame.
    private func pullFirstRingUpward(app: XCUIApplication) {
        let board = app.descendants(matching: .any).matching(identifier: "game.board").firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5), "game.board not found")
        let f = board.frame
        let w = f.width, h = f.height
        let cell = (min(w, h) - 32) / 5            // padding 16 each side, 5 cols
        let boardH = 5 * cell
        let originX = (w - boardH) / 2
        let originYScene = (h - boardH) / 2 + cell * 0.4

        // B3 → col 2, row 1 (0-based). Scene y is up; convert to screen y (down).
        let sceneX = originX + 2.5 * cell
        let sceneY = originYScene + (5 - 1 - 1 + 0.5) * cell
        let screenY = h - sceneY

        let startN = CGVector(dx: sceneX / w, dy: screenY / h)
        let endN = CGVector(dx: sceneX / w, dy: (screenY - 0.8 * cell) / h)
        let start = board.coordinate(withNormalizedOffset: startN)
        let end = board.coordinate(withNormalizedOffset: endN)
        start.press(forDuration: 0.08, thenDragTo: end)
    }

    private func openLevel1(app: XCUIApplication) {
        let play = app.buttons["home.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let card = app.buttons["levelCard.1"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].waitForExistence(timeout: 5))
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
