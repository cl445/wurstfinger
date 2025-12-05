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
        app.launchArguments = ["SCREENSHOT_MODE"]

        // Set English as language
        let languageId = "en_US"
        app.launchEnvironment["FORCE_LANGUAGE"] = languageId
    }

    // MARK: - README Screenshots (keyboard-only, cropped)

    @MainActor
    func testGenerateScreenshots() throws {
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
    /// Run this test on different simulators to get all required sizes:
    /// - iPhone 15 Plus (6.7" - 1290x2796)
    /// - iPhone 11 Pro Max (6.5" - 1242x2688)
    /// - iPhone 8 Plus (5.5" - 1242x2208)
    /// - iPad Pro 12.9" (2048x2732)
    @MainActor
    func testGenerateAppStoreScreenshots() throws {
        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Screenshot 1: Home screen - first impression
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        // Wait for app to load and navigate to Home tab
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
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

        XCTAssertTrue(testTab.waitForExistence(timeout: 5))
        testTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        takeAppStoreScreenshot(name: "appstore-\(deviceName)-03-test-dark")

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 4: Settings view
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
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

    @MainActor
    func testGenerateKeyboardShowcaseScreenshots() throws {
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

            XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 1.0)

            takeAppStoreScreenshot(name: "appstore-\(deviceName)-\(config.number)-keyboard-\(config.layer)-\(config.appearance)")

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
