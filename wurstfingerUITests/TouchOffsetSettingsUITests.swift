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

        // The posture is an explicit choice, not a view filter: the three
        // options are present and selectable (order: right, left, both).
        let rightThumb = app.staticTexts["One hand — right thumb"]
        XCTAssertTrue(rightThumb.waitForExistence(timeout: 3), "Posture choice missing")
        XCTAssertTrue(app.staticTexts["One hand — left thumb"].exists, "Left-thumb option missing")
        let twoThumbs = app.staticTexts["Two thumbs"]
        XCTAssertTrue(twoThumbs.exists, "Two-thumbs option missing")
        // Selecting a different posture must be possible.
        twoThumbs.tap()

        // The toggle is interactive.
        app.switches["Correct my typing"].tap()
    }
}
