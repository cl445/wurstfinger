//
//  TypingTests.swift
//  wurstfingerUITests
//
//  End-to-end UI tests that drive real gestures on the in-app keyboard
//  (KeyboardShowcaseView with TYPING_TEST) and assert the produced text,
//  not just that an action occurred.
//
//  Expectations are derived from each key's accessibility label (its printed
//  character), so these stay valid when the concrete letter layout changes.
//

import XCTest

final class TypingTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SCREENSHOT_MODE"]
        app.launchEnvironment["TYPING_TEST"] = "1"
        app.launchEnvironment["FORCE_LANGUAGE"] = "de_DE"
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launch()
        waitForKeyboard()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func key(_ id: String) -> XCUIElement {
        app.buttons[id]
    }

    /// Current captured text, read from the harness' `typedText` element.
    private func typedText() -> String {
        (app.staticTexts["typedText"].value as? String) ?? ""
    }

    private func waitForKeyboard() {
        XCTAssertTrue(key("center").waitForExistence(timeout: 5), "Keyboard not loaded")
        XCTAssertTrue(
            app.staticTexts["typedText"].waitForExistence(timeout: 2),
            "Typing harness not present"
        )
    }

    /// Polls until the captured text equals `expected` (UI updates are async).
    private func assertTypedText(
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate { _, _ in self.typedText() == expected }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(
            result, .completed,
            "Expected typed text '\(expected)', got '\(typedText())'",
            file: file, line: line
        )
    }

    /// Taps a key and returns the accessibility label it carried (its tap char).
    @discardableResult
    private func tapKey(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let element = key(id)
        guard element.waitForExistence(timeout: 2) else {
            XCTFail("Key '\(id)' not found", file: file, line: line)
            return ""
        }
        let label = element.label
        element.tap()
        return label
    }

    // MARK: - Tests

    /// Tapping letter keys appends each key's character in order.
    @MainActor
    func testTappingKeysSpellsTheirLabels() {
        var expected = ""
        for id in ["topLeft", "topCenter", "topRight"] {
            expected += tapKey(id)
            assertTypedText(equals: expected)
        }
    }

    /// The delete key removes the last typed character.
    @MainActor
    func testDeleteRemovesLastCharacter() {
        let first = tapKey("topLeft")
        let second = tapKey("topCenter")
        assertTypedText(equals: first + second)

        tapKey("delete")
        assertTypedText(equals: first)
    }

    /// The space key inserts a space between characters.
    @MainActor
    func testSpaceInsertsSpace() {
        let first = tapKey("topLeft")
        tapKey("space")
        let second = tapKey("topCenter")
        assertTypedText(equals: "\(first) \(second)")
    }

    /// A directional swipe produces a different character than a plain tap.
    @MainActor
    func testSwipeUpProducesDifferentCharacterThanTap() {
        let element = key("topLeft")
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        let tapLabel = element.label

        element.swipeUp()

        // Something was produced, and it differs from the tap (center) output.
        let predicate = NSPredicate { _, _ in
            let t = self.typedText()
            return !t.isEmpty && t != tapLabel
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)],
            timeout: 3.0
        )
        XCTAssertEqual(
            result, .completed,
            "Swipe up should produce a character other than the tap label '\(tapLabel)', got '\(typedText())'"
        )
    }

    /// Switching to the numeric layer via the symbols key lets digits be typed.
    @MainActor
    func testLayerSwitchToNumbersTypesDigit() {
        tapKey("symbols")

        // After switching, the center key carries a numeric-layer character.
        let center = key("center")
        XCTAssertTrue(center.waitForExistence(timeout: 2), "Center key missing after layer switch")
        let label = center.label
        center.tap()

        assertTypedText(equals: label)
    }
}
