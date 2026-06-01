import XCTest

/// Phase 3 UI coverage: onboarding, settings, the Level 1 tutorial, completion
/// stats, sequential unlock, and reset. State is made deterministic with the
/// DEBUG launch-argument overrides applied in `Preferences.applyUITestOverrides`.
final class RingKnotPhase3UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    /// Fresh progress, intros skipped, DEBUG bridge on. The common case for
    /// gameplay-focused checks.
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

    /// Fresh progress with BOTH intros re-armed (onboarding is shown).
    private func launchWithOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestResetIntros", "YES"
        ]
        app.launch()
        return app
    }

    /// Fresh progress, onboarding skipped but the Level 1 tutorial re-armed.
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

    // MARK: - Onboarding

    func test10_OnboardingAppearsAndCompletes() {
        let app = launchWithOnboarding()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5),
                      "Onboarding did not appear on a fresh first launch")
        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.exists, "Onboarding primary button missing")

        // Page through to the end (3 pages: Next, Next, Start).
        let home = app.buttons["home.play"]
        for _ in 0..<4 {
            if home.exists { break }
            primary.tap()
        }
        XCTAssertTrue(home.waitForExistence(timeout: 5),
                      "Did not reach Home after finishing onboarding")
    }

    func test11_OnboardingSkipGoesToHome() {
        let app = launchWithOnboarding()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        // Tap via a hit-point coordinate: the Skip button sits inside a paging
        // TabView and XCUITest's auto "scroll to visible" can fail on it.
        skip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5),
                      "Skipping onboarding did not land on Home")
    }

    // MARK: - Settings

    func test12_SettingsOpensFromHome() {
        let app = launchSkippingIntros()
        let settings = app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.switches["settings.sound"].waitForExistence(timeout: 5),
                      "Settings screen did not open")
        XCTAssertTrue(app.switches["settings.haptics"].exists)
        XCTAssertTrue(app.staticTexts["settings.version"].exists)
    }

    func test13_SoundTogglePersistsAcrossRelaunch() {
        let app = launchSkippingIntros()
        app.buttons["home.settings"].tap()
        let sound = app.switches["settings.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        let before = sound.value as? String
        // Tap the trailing edge where the switch control sits; tapping the row
        // centre lands on the "Sound" label and does not toggle.
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let after = waitForSwitchValueChange(sound, from: before)
        XCTAssertNotEqual(before, after, "Sound switch value did not change on tap")

        // Relaunch WITHOUT resetting preferences (progress reset only).
        app.terminate()
        let relaunch = XCUIApplication()
        relaunch.launchArguments += [
            "-com.swarpfoundation.ringknot.resetProgress", "YES",
            "-uiTestSkipIntro", "YES"
        ]
        relaunch.launch()
        relaunch.buttons["home.settings"].tap()
        let soundAgain = relaunch.switches["settings.sound"]
        XCTAssertTrue(soundAgain.waitForExistence(timeout: 5))
        XCTAssertEqual(soundAgain.value as? String, after,
                       "Sound setting did not persist across relaunch")
    }

    // MARK: - Level 1 tutorial

    func test14_Level1TutorialAppears() {
        let app = launchWithTutorial()
        openLevel(app: app, id: 1)
        let panel = app.otherElements["tutorial.panel"]
        let panelText = app.staticTexts["tutorial.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5) || panelText.waitForExistence(timeout: 5),
                      "Level 1 tutorial panel did not appear")
    }

    func test15_HintWorksAfterTutorialDismissed() {
        // Intros skipped, so no tutorial: confirm Hint is functional on Level 1.
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        let hint = app.buttons["hud.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        hint.tap()
        XCTAssertTrue(app.staticTexts["hud.levelNumber"].exists,
                      "HUD disappeared after tapping Hint")
    }

    // MARK: - Completion stats + progression

    func test16_CompletionShowsStats() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        completeLevel1(app: app)
        XCTAssertTrue(app.buttons["completion.next"].waitForExistence(timeout: 5),
                      "Completion overlay did not appear")
        XCTAssertTrue(app.staticTexts["completion.moves"].exists, "Missing moves stat")
        XCTAssertTrue(app.staticTexts["completion.par"].exists, "Missing par stat")
        XCTAssertTrue(app.staticTexts["completion.best"].exists, "Missing best stat")
        // First-ever clear is always a new best.
        XCTAssertTrue(app.staticTexts["completion.newBest"].exists,
                      "First clear should show New Best")
    }

    func test17_Level2UnlockedAfterCompletingLevel1() {
        let app = launchSkippingIntros()
        openLevel(app: app, id: 1)
        completeLevel1(app: app)
        let levelSelect = app.buttons["completion.levelSelect"]
        XCTAssertTrue(levelSelect.waitForExistence(timeout: 5))
        levelSelect.tap()
        let card2 = app.buttons["levelCard.2"]
        XCTAssertTrue(card2.waitForExistence(timeout: 5), "Level 2 card not found")
        XCTAssertTrue(card2.isEnabled, "Level 2 should be unlocked after completing Level 1")
    }

    // MARK: - Reset

    func test18_ResetProgressReShowsOnboarding() {
        let app = launchSkippingIntros()
        app.buttons["home.settings"].tap()
        let reset = app.buttons["settings.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        // Scope to the live alert: a SwiftUI alert button identifier can also
        // surface on the backing hierarchy, so an unscoped query is ambiguous.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Reset confirmation alert missing")
        // `.firstMatch` resolves the duplicate-identifier ambiguity SwiftUI
        // can introduce for alert buttons.
        let confirm = alert.buttons.matching(identifier: "settings.resetConfirm").firstMatch
        if confirm.exists {
            confirm.tap()
        } else {
            alert.buttons["Reset"].firstMatch.tap()
        }
        // Reset replays intros, so onboarding should reappear.
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5),
                      "Onboarding did not re-show after Reset Progress")
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

    private func completeLevel1(app: XCUIApplication) {
        let moves = app.staticTexts["hud.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        let bridge = app.buttons["bridge.nextMove"]
        // Level 1 has two rings.
        bridge.tap()
        _ = waitForLabel(moves, to: "1")
        bridge.tap()
        _ = waitForLabel(moves, to: "2")
    }

    /// Poll a switch's value until it differs from `from` (or timeout).
    private func waitForSwitchValueChange(_ element: XCUIElement, from: String?,
                                          timeout: TimeInterval = 3) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = element.value as? String
            if current != from { return current }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return element.value as? String
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
}
