//
//  ScreenshotTests.swift
//  wurstfingerUITests
//
//  Automated screenshot generation for documentation and App Store
//

import XCTest

private struct ScreenshotConfig {
    let layer: String
    let appearance: String
    let number: String
    var sent: String = ""
    var received: String = ""
}

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
    func testGenerateScreenshots() {
        app.launchArguments = ["SCREENSHOT_MODE"]

        // Detect the rendered keyboard via a stable key identifier (the
        // center grid slot) rather than the container element, which SwiftUI
        // does not reliably expose as a queryable `otherElement`.
        let keyboard = app.buttons["center"]

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
    func testGenerateAppStoreScreenshots() {
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
    func testGenerateKeyboardShowcaseScreenshots() {
        app.launchArguments = ["SCREENSHOT_MODE"]

        // Detect the rendered keyboard via a stable key identifier (the
        // center grid slot) rather than the container element, which SwiftUI
        // does not reliably expose as a queryable `otherElement`.
        let keyboard = app.buttons["center"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Keyboard layouts to capture
        let configurations: [ScreenshotConfig] = [
            .init(layer: "lower", appearance: "light", number: "06"),
            .init(layer: "lower", appearance: "dark", number: "07"),
            .init(layer: "numbers", appearance: "light", number: "08"),
            .init(layer: "symbols", appearance: "light", number: "09")
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
    func testGenerateAppStoreKeyboardScreenshots() {
        app.launchArguments = ["APPSTORE_SCREENSHOT_MODE"]

        let keyboard = app.buttons["center"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let configurations: [ScreenshotConfig] = [
            .init(
                layer: "lower",
                appearance: "light",
                number: "01",
                sent: "So fast and precise! 🎯",
                received: "How do you like the new keyboard?"
            ),
            .init(
                layer: "lower",
                appearance: "dark",
                number: "02",
                sent: "Works great in dark mode too!",
                received: "Can you try it at night?"
            ),
            .init(
                layer: "numbers",
                appearance: "light",
                number: "03",
                sent: "Here: 555-0123",
                received: "What's your number?"
            ),
            .init(
                layer: "numbers",
                appearance: "dark",
                number: "04",
                sent: "Meeting at 7:30pm",
                received: "What time works for you?"
            )
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
