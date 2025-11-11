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

        // Screenshot 1-4: Keyboard-only screenshots
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

        // Screenshot 5-6: Screenshots with text
        for appearance in appearances {
            app.launchArguments = ["TEXT_SCREENSHOT_MODE"]
            app.launchEnvironment["FORCE_LANGUAGE"] = "en_US"
            app.launchEnvironment["FORCE_APPEARANCE"] = appearance
            app.launch()

            let keyboard = app.otherElements["showcaseKeyboard"]
            XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 1.0)  // Wait for layout to settle

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "demo-text-\(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}
