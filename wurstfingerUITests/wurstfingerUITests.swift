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
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation Tests

    @MainActor
    func testAllTabsAreAccessible() throws {
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
    func testOnboardingViewShowsSetupSteps() throws {
        app.tabBars.buttons["Setup"].tap()

        // Check that setup steps are visible
        XCTAssertTrue(app.staticTexts["Enable keyboard"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Allow full access"].exists)
        XCTAssertTrue(app.staticTexts["Try the keyboard"].exists)

        // Check that "Open Settings" button exists
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    @MainActor
    func testOnboardingCheckboxesAreToggleable() throws {
        app.tabBars.buttons["Setup"].tap()

        // Find toggles (switches) in the setup view
        let toggles = app.switches
        XCTAssertTrue(toggles.count >= 3, "Should have at least 3 setup step toggles")

        // Toggle the first switch
        if let firstToggle = toggles.allElementsBoundByIndex.first {
            let initialValue = firstToggle.value as? String
            firstToggle.tap()
            let newValue = firstToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue, "Toggle value should change after tap")
        }
    }

    // MARK: - Settings Tests

    @MainActor
    func testSettingsViewShowsMainOptions() throws {
        app.tabBars.buttons["Settings"].tap()

        // Check main settings rows exist
        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Key Aspect Ratio"].exists)
        XCTAssertTrue(app.staticTexts["Haptic Feedback"].exists)
        XCTAssertTrue(app.staticTexts["Version"].exists)
    }

    @MainActor
    func testSettingsLanguageNavigation() throws {
        app.tabBars.buttons["Settings"].tap()

        // Tap on Language row
        app.staticTexts["Language"].tap()

        // Should navigate to language selection (title is "Keyboard Language")
        XCTAssertTrue(app.navigationBars["Keyboard Language"].waitForExistence(timeout: 2))

        // Go back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsHapticFeedbackNavigation() throws {
        app.tabBars.buttons["Settings"].tap()

        // Tap on Haptic Feedback row
        app.staticTexts["Haptic Feedback"].tap()

        // Should navigate to haptic settings (title is "Haptics")
        XCTAssertTrue(app.navigationBars["Haptics"].waitForExistence(timeout: 2))

        // Check that sliders exist
        XCTAssertTrue(app.sliders.count >= 1, "Should have haptic intensity sliders")
    }

    @MainActor
    func testSettingsUtilityKeysToggle() throws {
        app.tabBars.buttons["Settings"].tap()

        // Find the "Utility Keys on Left" toggle
        let utilityToggle = app.switches["Utility Keys on Left"]
        if utilityToggle.exists {
            let initialValue = utilityToggle.value as? String
            utilityToggle.tap()
            let newValue = utilityToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")
        }
    }

    // MARK: - Test Area Tests

    @MainActor
    func testTestAreaHasTextFieldAndKeyboard() throws {
        app.tabBars.buttons["Test"].tap()

        // Wait for test area to load
        XCTAssertTrue(app.navigationBars["Test"].waitForExistence(timeout: 2))

        // Check for text field or text view
        let hasTextField = app.textFields.count > 0 || app.textViews.count > 0
        XCTAssertTrue(hasTextField, "Test area should have a text input field")
    }

    // MARK: - Home View Tests

    @MainActor
    func testHomeViewShowsAppInfo() throws {
        // Home should be the default tab
        XCTAssertTrue(app.navigationBars["Wurstfinger"].waitForExistence(timeout: 2))

        // Check for some expected content
        let hasContent = app.staticTexts.count > 0
        XCTAssertTrue(hasContent, "Home view should display content")
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
