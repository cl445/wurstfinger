//
//  ScreenshotTests.swift
//  wurstfingerUITests
//
//  Automated screenshot generation for documentation
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
}
