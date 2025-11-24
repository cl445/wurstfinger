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

    /// Generate App Store screenshots for the current device
    /// Run this test on different simulators to get all required sizes:
    /// - iPhone 15 Plus (6.7" - 1290x2796)
    /// - iPhone 11 Pro Max (6.5" - 1242x2688)
    /// - iPhone 8 Plus (5.5" - 1242x2208)
    /// - iPad Pro 12.9" (2048x2732)
    @MainActor
    func testGenerateAppStoreScreenshots() throws {
        let keyboard = app.otherElements["showcaseKeyboard"]

        // Get device identifier for naming
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        // Screenshot 1: Keyboard showcase (light mode, letters)
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        var screenshot = app.screenshot()
        var attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "appstore-\(deviceName)-01-keyboard-light"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 2: Keyboard showcase (dark mode, letters)
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launchEnvironment["FORCE_APPEARANCE"] = "dark"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "appstore-\(deviceName)-02-keyboard-dark"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 3: Numbers layer (light mode)
        app.launchEnvironment["FORCE_LAYER"] = "numbers"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "appstore-\(deviceName)-03-numbers-light"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 4: Symbols layer (light mode)
        app.launchEnvironment["FORCE_LAYER"] = "symbols"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "appstore-\(deviceName)-04-symbols-light"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }
}
