//
//  TouchOffsetSettingsUITests.swift
//  wurstfingerUITests
//
//  Verifies the Touch Correction settings page (spec §6) is reachable and
//  shows its core controls: the toggle, the learned-offset visualization and
//  the reset controls.
//

import XCTest

final class TouchOffsetSettingsUITests: XCTestCase {
    @MainActor
    func testTouchCorrectionPageShowsControls() {
        // Force English so the assertions are locale-independent (the simulator
        // may be German, where the tabs read "Einstellungen" etc.). The factory
        // also redirects the shared store, so toggling the setting below cannot
        // reach the app group the user's own keyboard reads.
        let app = UITestApp.make(UITestApp.englishLocaleArguments)
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
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

        // The toggle is interactive.
        app.switches["Correct my typing"].tap()
    }
}
