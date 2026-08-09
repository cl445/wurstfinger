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
        app = UITestApp.make(UITestApp.englishLocaleArguments)
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

        // Toggling back must return the original value. Both taps write real
        // persisted checklist state, but the isolation launch argument routes
        // `OnboardingProgress.store` into the throwaway suite along with
        // `SharedDefaults.store`, so a failure between them leaves a ticked step
        // there rather than in the tester's own app defaults.
        firstToggle.tap()
        let restoredValue = firstToggle.value as? String
        XCTAssertEqual(initialValue, restoredValue, "Toggle must return to its original state")
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

    /// The "Utility Keys on Left" row. It has no stable accessibility
    /// identifier (adding one would be a production change, out of scope here),
    /// so match on the pinned-English label. The SwiftUI Toggle label combines
    /// title + subtitle, hence CONTAINS rather than an exact subscript match.
    @MainActor
    private func utilityKeysToggle() -> XCUIElement {
        app.switches
            .matching(NSPredicate(format: "label CONTAINS %@", "Utility Keys on Left"))
            .firstMatch
    }

    /// SwiftUI exposes the whole row as the switch element; tapping its center
    /// hits the label, not the UISwitch. Tap the nested switch when present,
    /// otherwise the trailing edge where the UISwitch sits.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        let inner = toggle.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            toggle
                .coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
                .tap()
        }
    }

    @MainActor
    func testSettingsUtilityKeysToggle() {
        app.tabBars.buttons["Settings"].tap()

        let utilityToggle = utilityKeysToggle()
        XCTAssertTrue(
            utilityToggle.waitForExistence(timeout: 2),
            "Utility Keys on Left toggle must exist in Settings"
        )

        let initialValue = utilityToggle.value as? String
        flip(utilityToggle)
        let newValue = utilityToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")

        // Toggling back must return the original value; both writes land in the
        // isolated defaults suite, not the real app-group store.
        flip(utilityToggle)
        let restoredValue = utilityToggle.value as? String
        XCTAssertEqual(initialValue, restoredValue, "Toggle must return to its original state")
    }

    // MARK: - Defaults Isolation

    /// Runtime proof that the isolation launch argument still reaches the app.
    ///
    /// `UITestApp.isolatedDefaultsArgument` is a copy of
    /// `SharedDefaults.isolatedStoreArgument` across a boundary no compiler
    /// checks — this target cannot import the app module. `SharedDefaultsIsolationTests`
    /// pins the app-side spelling, but a rename on *this* side keeps compiling
    /// and every UI test would quietly go back to writing the user's real
    /// app-group settings. Only the running app can testify, so ask it: flip a
    /// setting, relaunch, and see whether the value survived.
    ///
    /// It survives exactly when isolation is broken — the real store is never
    /// wiped — or when the app stopped wiping the throwaway suite on launch
    /// (`SharedDefaults.store`), which would let UI tests inherit each other's
    /// leftovers. Both are worth failing over.
    @MainActor
    func testLaunchArgumentIsolatesDefaultsFromTheRealStore() {
        app.tabBars.buttons["Settings"].tap()
        let toggle = utilityKeysToggle()
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "Utility Keys on Left toggle must exist in Settings")

        let valueAtLaunch = toggle.value as? String
        flip(toggle)
        XCTAssertNotEqual(valueAtLaunch, toggle.value as? String, "Toggle should change state")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        let toggleAfterRelaunch = utilityKeysToggle()
        XCTAssertTrue(
            toggleAfterRelaunch.waitForExistence(timeout: 5),
            "Settings must be reachable again after the relaunch"
        )
        let valueAfterRelaunch = toggleAfterRelaunch.value as? String

        // Undo first, assert second: `continueAfterFailure = false` stops the
        // test at the assertion, and in the failing case the flip landed in the
        // user's real app-group store, which nothing else will clean up.
        if valueAfterRelaunch != valueAtLaunch {
            flip(toggleAfterRelaunch)
        }

        XCTAssertEqual(
            valueAfterRelaunch, valueAtLaunch,
            """
            A flipped setting survived a relaunch. Either \
            UITestApp.isolatedDefaultsArgument no longer matches \
            SharedDefaults.isolatedStoreArgument — every UI test is then writing the \
            real app-group store — or SharedDefaults.store stopped wiping the \
            isolated suite on launch.
            """
        )
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
            app.launch()
        }
    }
}
