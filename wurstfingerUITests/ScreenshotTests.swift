//
//  ScreenshotTests.swift
//  wurstfingerUITests
//
//  Automated screenshot generation for documentation and App Store
//

import XCTest

private struct ScreenshotConfiguration {
    let mode: String
    let appearance: String
    let number: String
    var sent: String = ""
    var received: String = ""
}

/// Screenshot generators. They relaunch the app 15 times with hard sleeps and
/// produce attachments rather than assertions, so they opt out of a plain
/// `xcodebuild test` and only run when `GENERATE_SCREENSHOTS=1` reaches the
/// test runner — see `scripts/lib/simulator-capture.sh`.
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try UITestApp.skipUnlessGeneratingScreenshots()
        continueAfterFailure = false
    }

    // MARK: - README Screenshots (keyboard-only, cropped)

    /// Generate keyboard-only screenshots for README documentation
    /// Uses SCREENSHOT_MODE to show KeyboardShowcaseView
    @MainActor
    func testGenerateScreenshots() {
        app = UITestApp.make(["SCREENSHOT_MODE"])

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
    /// Not part of the shipping set: `scripts/generate-appstore-screenshots.sh`
    /// uploads `testGenerateAppStoreKeyboardScreenshots`, rendered natively on
    /// iPhone 17 Pro Max (1320x2868, 6.9") and iPhone 16e (1170x2532, 6.1").
    @MainActor
    func testGenerateAppStoreScreenshots() {
        // Don't use SCREENSHOT_MODE - we want the full app with tabs
        app = UITestApp.make()

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

    // MARK: - Keyboard Showcase Screenshots (for App Store, showing keyboard modes)

    /// Generate keyboard showcase screenshots for App Store
    /// Uses SCREENSHOT_MODE to show KeyboardShowcaseView with different modes
    @MainActor
    func testGenerateKeyboardShowcaseScreenshots() {
        app = UITestApp.make(["SCREENSHOT_MODE"])

        // Detect the rendered keyboard via a stable key identifier (the
        // center grid slot) rather than the container element, which SwiftUI
        // does not reliably expose as a queryable `otherElement`.
        let keyboard = app.buttons["center"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Keyboard layouts to capture
        let configurations: [ScreenshotConfiguration] = [
            .init(mode: "lower", appearance: "light", number: "06"),
            .init(mode: "lower", appearance: "dark", number: "07"),
            .init(mode: "numbers", appearance: "light", number: "08"),
            .init(mode: "symbols", appearance: "light", number: "09")
        ]

        for config in configurations {
            app.launchEnvironment["FORCE_LAYER"] = config.mode
            app.launchEnvironment["FORCE_APPEARANCE"] = config.appearance
            app.launch()

            XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard not found for \(config.mode)-\(config.appearance)")
            Thread.sleep(forTimeInterval: 1.0)

            takeAppStoreScreenshot(name: "appstore-\(deviceName)-\(config.number)-keyboard-\(config.mode)-\(config.appearance)")

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
        app = UITestApp.make(["APPSTORE_SCREENSHOT_MODE"])

        let keyboard = app.buttons["center"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let configurations: [ScreenshotConfiguration] = [
            .init(
                mode: "lower",
                appearance: "light",
                number: "01",
                sent: "So fast and precise! 🎯",
                received: "How do you like the new keyboard?"
            ),
            .init(
                mode: "lower",
                appearance: "dark",
                number: "02",
                sent: "Works great in dark mode too!",
                received: "Can you try it at night?"
            ),
            .init(
                mode: "numbers",
                appearance: "light",
                number: "03",
                sent: "Here: 555-0123",
                received: "What's your number?"
            ),
            .init(
                mode: "numbers",
                appearance: "dark",
                number: "04",
                sent: "Meeting at 7:30pm",
                received: "What time works for you?"
            )
        ]

        for config in configurations {
            app.launchEnvironment["FORCE_LAYER"] = config.mode
            app.launchEnvironment["FORCE_APPEARANCE"] = config.appearance
            app.launchEnvironment["FORCE_TEXT"] = config.sent
            app.launchEnvironment["FORCE_RECEIVED_TEXT"] = config.received
            app.launch()

            XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard not found for \(config.mode)-\(config.appearance)")
            Thread.sleep(forTimeInterval: 1.0)

            takeAppStoreScreenshot(name: "appstore-\(deviceName)-keyboard-\(config.number)-\(config.mode)-\(config.appearance)")

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
