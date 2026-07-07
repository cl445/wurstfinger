//
//  wurstfingerUITests.swift
//  wurstfingerUITests
//
//  Created by Claas Flint on 24.10.25.
//

import XCTest

final class wurstfingerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The suite queries localized display text ("Settings", "Language", …),
        // so pin the app to English regardless of the simulator's locale.
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation Tests

    @MainActor
    func testAllTabsAreAccessible() {
        // Home tab should be visible by default
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Setup"].exists)
        XCTAssertTrue(app.tabBars.buttons["Test"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        // Navigate to each tab
        app.tabBars.buttons["Setup"].tap()
        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Test"].tap()
        XCTAssertTrue(app.navigationBars["Test"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Wurstfinger"].waitForExistence(timeout: 2))
    }

    // MARK: - Onboarding Tests

    @MainActor
    func testOnboardingViewShowsSetupSteps() {
        app.tabBars.buttons["Setup"].tap()

        // Check that setup steps are visible
        XCTAssertTrue(app.staticTexts["Enable keyboard"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Allow full access"].exists)
        XCTAssertTrue(app.staticTexts["Try the keyboard"].exists)

        // Check that "Open Settings" button exists
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    @MainActor
    func testOnboardingCheckboxesAreToggleable() {
        app.tabBars.buttons["Setup"].tap()

        // Find toggles (switches) in the setup view
        let toggles = app.switches
        XCTAssertTrue(toggles.count >= 3, "Should have at least 3 setup step toggles")

        // Toggle the first switch — unconditionally, so this fails loudly if
        // the control vanishes instead of silently passing.
        let firstToggle = toggles.element(boundBy: 0)
        XCTAssertTrue(firstToggle.exists, "First setup step toggle must exist")

        let initialValue = firstToggle.value as? String
        firstToggle.tap()
        let newValue = firstToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Toggle value should change after tap")

        // The setup steps persist to the shared app-group store — restore the
        // original state so the test leaves no trace on the device/simulator.
        firstToggle.tap()
        let restoredValue = firstToggle.value as? String
        XCTAssertEqual(initialValue, restoredValue, "Toggle must be restored to its original state")
    }

    // MARK: - Settings Tests

    /// Scrolls the current screen until `element` exists. SwiftUI `List` rows
    /// are created lazily, so rows below the fold don't exist in the
    /// accessibility hierarchy until scrolled into view.
    @MainActor
    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 6) {
        for _ in 0 ..< maxSwipes {
            if element.exists { return }
            app.swipeUp()
        }
    }

    @MainActor
    func testSettingsViewShowsMainOptions() {
        app.tabBars.buttons["Settings"].tap()

        // Check main settings rows exist (scrolling for lazily-created rows).
        XCTAssertTrue(app.staticTexts["Languages"].waitForExistence(timeout: 2), "Languages row missing")

        scrollToElement(app.staticTexts["Key Aspect Ratio"])
        XCTAssertTrue(app.staticTexts["Key Aspect Ratio"].exists, "Key Aspect Ratio row missing")

        scrollToElement(app.staticTexts["Haptic Feedback"])
        XCTAssertTrue(app.staticTexts["Haptic Feedback"].exists, "Haptic Feedback row missing")

        // Version is in the About section at the bottom — scroll until visible
        scrollToElement(app.staticTexts["Version"])
        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 2), "Version row missing")
    }

    @MainActor
    func testSettingsLanguageNavigation() {
        app.tabBars.buttons["Settings"].tap()

        // Tap on Languages row
        let languagesRow = app.staticTexts["Languages"]
        XCTAssertTrue(languagesRow.waitForExistence(timeout: 2), "Languages row missing")
        languagesRow.tap()

        // Should navigate to language selection
        XCTAssertTrue(app.navigationBars["Languages"].waitForExistence(timeout: 2))

        // Go back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsHapticFeedbackNavigation() {
        app.tabBars.buttons["Settings"].tap()

        // The Feedback section sits below the fold — scroll it into view first.
        let hapticRow = app.staticTexts["Haptic Feedback"]
        scrollToElement(hapticRow)
        XCTAssertTrue(hapticRow.exists, "Haptic Feedback row missing")
        hapticRow.tap()

        // Should navigate to haptic settings (title is "Haptics")
        XCTAssertTrue(app.navigationBars["Haptics"].waitForExistence(timeout: 2))

        // The master toggle was removed with the per-event intensity rework;
        // the screen now shows one control per haptic event instead.
        XCTAssertTrue(app.staticTexts["Tap Feedback"].exists, "Tap Feedback control missing")
        XCTAssertTrue(app.staticTexts["Drag Feedback"].exists, "Drag Feedback control missing")
    }

    @MainActor
    func testSettingsUtilityKeysToggle() {
        app.tabBars.buttons["Settings"].tap()

        // Find the "Utility Keys on Left" toggle. The row has no stable
        // accessibility identifier (adding one would be a production change,
        // out of scope here), so match on the pinned-English label. The
        // SwiftUI Toggle label combines title + subtitle, hence CONTAINS
        // rather than an exact subscript match.
        let utilityToggle = app.switches
            .matching(NSPredicate(format: "label CONTAINS %@", "Utility Keys on Left"))
            .firstMatch
        XCTAssertTrue(
            utilityToggle.waitForExistence(timeout: 2),
            "Utility Keys on Left toggle must exist in Settings"
        )

        // SwiftUI exposes the whole row as the switch element; tapping its
        // center hits the label, not the UISwitch. Tap the nested switch when
        // present, otherwise the trailing edge where the UISwitch sits.
        func flip() {
            let inner = utilityToggle.switches.firstMatch
            if inner.exists {
                inner.tap()
            } else {
                utilityToggle
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
                    .tap()
            }
        }

        let initialValue = utilityToggle.value as? String
        flip()
        let newValue = utilityToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")

        // The toggle writes to the real shared app-group store — restore it.
        flip()
        let restoredValue = utilityToggle.value as? String
        XCTAssertEqual(initialValue, restoredValue, "Toggle must be restored to its original state")
    }

    // MARK: - Test Area Tests

    @MainActor
    func testTestAreaHasTextFieldAndKeyboard() {
        app.tabBars.buttons["Test"].tap()

        // Wait for test area to load
        XCTAssertTrue(app.navigationBars["Test"].waitForExistence(timeout: 2))

        // Check for text field or text view
        let hasTextField = app.textFields.count > 0 || app.textViews.count > 0
        XCTAssertTrue(hasTextField, "Test area should have a text input field")
    }

    // MARK: - Home View Tests

    @MainActor
    func testHomeViewShowsAppInfo() {
        // Home should be the default tab
        XCTAssertTrue(app.navigationBars["Wurstfinger"].waitForExistence(timeout: 2))

        // Assert the actual Home content: app title, tagline, and quick links.
        XCTAssertTrue(app.staticTexts["Wurstfinger"].exists, "App title missing on Home")
        XCTAssertTrue(
            app.staticTexts["The Keyboard for Fat Fingers"].exists,
            "Tagline missing on Home"
        )
        XCTAssertTrue(app.buttons["Setup Instructions"].exists, "Setup Instructions link missing")
        XCTAssertTrue(app.buttons["GitHub"].exists, "GitHub link missing")
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
