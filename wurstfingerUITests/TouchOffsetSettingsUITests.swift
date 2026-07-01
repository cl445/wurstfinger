//
//  TouchOffsetSettingsUITests.swift
//  wurstfingerUITests
//
//  Verifies the Touch Correction settings page (spec §6) is reachable and
//  shows its core controls: the toggle, the explicit hand-posture choice
//  (§6.3), the learned-offset visualization and the reset controls.
//

import XCTest

final class TouchOffsetSettingsUITests: XCTestCase {
    @MainActor
    func testTouchCorrectionPageShowsControls() {
        let app = XCUIApplication()
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        // Force English so the assertions are locale-independent (the simulator
        // may be German, where the tabs read "Einstellungen" etc.).
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab missing")
        settingsTab.tap()

        let row = app.staticTexts["Touch Correction"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Touch Correction row missing")
        row.tap()

        XCTAssertTrue(
            app.switches["Correct my typing"].waitForExistence(timeout: 5),
            "Master toggle missing"
        )
        XCTAssertTrue(
            app.staticTexts["Learned adjustments"].waitForExistence(timeout: 3),
            "Visualization section missing"
        )
        XCTAssertTrue(
            app.buttons["Reset everything"].waitForExistence(timeout: 3),
            "Reset control missing"
        )

        // The posture is an explicit choice presented as a compact picker.
        XCTAssertTrue(
            app.staticTexts["How do you type?"].waitForExistence(timeout: 3),
            "Posture picker missing"
        )

        // Statistics live on their own subpage now.
        let statsLink = app.buttons["Statistics"]
        XCTAssertTrue(statsLink.waitForExistence(timeout: 3), "Statistics link missing")
        statsLink.tap()
        XCTAssertTrue(
            app.staticTexts["Does it help?"].waitForExistence(timeout: 3),
            "A/B statistics missing on the subpage"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // The toggle is interactive.
        XCTAssertTrue(app.switches["Correct my typing"].waitForExistence(timeout: 3), "Toggle missing after back")
        app.switches["Correct my typing"].tap()
    }
}
