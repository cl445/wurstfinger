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
        // Screenshot 1: Lower case layout
        app.launch()

        let keyboard = app.otherElements["showcaseKeyboard"]
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        let lowerScreenshot = app.screenshot()
        let lowerAttachment = XCTAttachment(screenshot: lowerScreenshot)
        lowerAttachment.name = "keyboard-lower"
        lowerAttachment.lifetime = .keepAlways
        add(lowerAttachment)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 2: Numbers layer
        app.launchEnvironment["FORCE_LAYER"] = "numbers"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        let numbersScreenshot = app.screenshot()
        let numbersAttachment = XCTAttachment(screenshot: numbersScreenshot)
        numbersAttachment.name = "keyboard-numbers"
        numbersAttachment.lifetime = .keepAlways
        add(numbersAttachment)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 3: Showcase view (for README) - lower case
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launch()

        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)

        let showcaseScreenshot = app.screenshot()
        let showcaseAttachment = XCTAttachment(screenshot: showcaseScreenshot)
        showcaseAttachment.name = "demo-showcase"
        showcaseAttachment.lifetime = .keepAlways
        add(showcaseAttachment)
    }
}
