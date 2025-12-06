//
//  ScreenshotTests.swift
//  wurstfingerUITests
//
//  Automated screenshot generation for documentation and App Store
//

import XCTest

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - README Screenshots (keyboard-only, cropped)

    /// Generate keyboard-only screenshots for README documentation
    /// Uses SCREENSHOT_MODE to show KeyboardShowcaseView
    @MainActor
    func testGenerateScreenshots() throws {
        app.launchArguments = ["SCREENSHOT_MODE"]

        let keyboard = app.otherElements["showcaseKeyboard"]

        let layouts = ["lower", "numbers"]
        let appearances = ["light", "dark"]

        // Generate 4 keyboard-only screenshots for README
        for appearance in appearances {
            for layout in layouts {
                app.launchEnvironment["FORCE_LAYER"] = layout
                app.launchEnvironment["FORCE_APPEARANCE"] = appearance
                app.launch()

                XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
                Thread.sleep(forTimeInterval: 1.0)

                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "keyboard-\(layout)-\(appearance)"
                attachment.lifetime = .keepAlways
                add(attachment)

                app.terminate()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    // MARK: - App Store Screenshots

    /// Generate App Store screenshots showing the full app experience
    /// Does NOT use SCREENSHOT_MODE - shows normal app with TabView
    /// Run this test on different simulators to get all required sizes:
    /// - iPhone 15 Plus (6.7" - 1290x2796)
    /// - iPhone 11 Pro Max (6.5" - 1242x2688)
    /// - iPhone 8 Plus (5.5" - 1242x2208)
    /// - iPad Pro 12.9" (2048x2732)
    @MainActor
    func testGenerateAppStoreScreenshots() throws {
        // Don't use SCREENSHOT_MODE - we want the full app with tabs
        app.launchArguments = []

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Screenshot 1: Home screen - first impression
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        // Wait for app to load and navigate to Home tab
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home tab not found")
        homeTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-01-home")

        // Screenshot 2: Test area with keyboard preview (light mode)
        let testTab = app.tabBars.buttons["Test"]
        testTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-02-test-light")

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 3: Test area (dark mode)
        app.launchEnvironment["FORCE_APPEARANCE"] = "dark"
        app.launch()

        XCTAssertTrue(testTab.waitForExistence(timeout: 5), "Test tab not found after relaunch")
        testTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-03-test-dark")

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 4: Settings view
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab not found")
        settingsTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-04-settings")

        // Screenshot 5: Onboarding/Setup view
        let setupTab = app.tabBars.buttons["Setup"]
        setupTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-05-setup")

        app.terminate()
    }

    // MARK: - Keyboard Showcase Screenshots (for App Store, showing keyboard layers)

    /// Generate keyboard showcase screenshots for App Store
    /// Uses SCREENSHOT_MODE to show KeyboardShowcaseView with different layers
    @MainActor
    func testGenerateKeyboardShowcaseScreenshots() throws {
        app.launchArguments = ["SCREENSHOT_MODE"]

        let keyboard = app.otherElements["showcaseKeyboard"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Keyboard layouts to capture
        let configurations: [(layer: String, appearance: String, number: String)] = [
            ("lower", "light", "06"),
            ("lower", "dark", "07"),
            ("numbers", "light", "08"),
            ("symbols", "light", "09")
        ]

        for config in configurations {
            app.launchEnvironment["FORCE_LAYER"] = config.layer
            app.launchEnvironment["FORCE_APPEARANCE"] = config.appearance
            app.launch()

            XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard not found for \(config.layer)-\(config.appearance)")
            Thread.sleep(forTimeInterval: 1.0)

            takeAppStoreScreenshot(name: "appstore-\(deviceName)-\(config.number)-keyboard-\(config.layer)-\(config.appearance)")

            app.terminate()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - App Store Keyboard with Chat UI Screenshots

    /// Generate App Store screenshots showing keyboard with chat interface and sample text
    /// Uses APPSTORE_SCREENSHOT_MODE to show AppStoreScreenshotView
    /// These are the primary screenshots showing the keyboard in action
    @MainActor
    func testGenerateAppStoreKeyboardScreenshots() throws {
        app.launchArguments = ["APPSTORE_SCREENSHOT_MODE"]

        let keyboard = app.otherElements["screenshotKeyboard"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Configurations: layer, appearance, screenshot number, sent text, received text
        let configurations: [(layer: String, appearance: String, number: String, sent: String, received: String)] = [
            ("lower", "light", "01", "So fast and precise! 🎯", "How do you like the new keyboard?"),
            ("lower", "dark", "02", "Works great in dark mode too!", "Can you try it at night?"),
            ("numbers", "light", "03", "Here: 555-0123", "What's your number?"),
            ("numbers", "dark", "04", "Meeting at 7:30pm", "What time works for you?")
        ]

        for config in configurations {
            app.launchEnvironment["FORCE_LAYER"] = config.layer
            app.launchEnvironment["FORCE_APPEARANCE"] = config.appearance
            app.launchEnvironment["FORCE_TEXT"] = config.sent
            app.launchEnvironment["FORCE_RECEIVED_TEXT"] = config.received
            app.launch()

            XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard not found for \(config.layer)-\(config.appearance)")
            Thread.sleep(forTimeInterval: 1.0)

            takeAppStoreScreenshot(name: "appstore-\(deviceName)-keyboard-\(config.number)-\(config.layer)-\(config.appearance)")

            app.terminate()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - Helper Methods

    private func takeAppStoreScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
