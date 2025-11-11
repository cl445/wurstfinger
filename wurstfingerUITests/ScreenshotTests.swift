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
        app.launch()

        // Wait for keyboard to appear
        let keyboard = app.otherElements["showcaseKeyboard"]
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))

        // Give UI time to settle
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 1: Lower case layout
        let lowerScreenshot = app.screenshot()
        let lowerAttachment = XCTAttachment(screenshot: lowerScreenshot)
        lowerAttachment.name = "keyboard-lower"
        lowerAttachment.lifetime = .keepAlways
        add(lowerAttachment)

        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 2: Numbers layer
        // Tap the symbols toggle button to switch to numbers
        let symbolsButton = keyboard.buttons.matching(identifier: "symbols").firstMatch
        if symbolsButton.exists {
            symbolsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)

            let numbersScreenshot = app.screenshot()
            let numbersAttachment = XCTAttachment(screenshot: numbersScreenshot)
            numbersAttachment.name = "keyboard-numbers"
            numbersAttachment.lifetime = .keepAlways
            add(numbersAttachment)

            // Toggle back to letters
            symbolsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Screenshot 3: Showcase view (for README)
        let showcaseScreenshot = app.screenshot()
        let showcaseAttachment = XCTAttachment(screenshot: showcaseScreenshot)
        showcaseAttachment.name = "demo-showcase"
        showcaseAttachment.lifetime = .keepAlways
        add(showcaseAttachment)
    }
}
