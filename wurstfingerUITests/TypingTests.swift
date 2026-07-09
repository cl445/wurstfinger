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

    /// Relaunches the app forcing a specific keyboard language.
    private func relaunch(language: String) {
        app.terminate()
        app.launchEnvironment["FORCE_LANGUAGE"] = language
        app.launch()
        waitForKeyboard()
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

    /// Drags from a key's center by (dx, dy) points — long enough to register
    /// as a directional swipe. Negative dy is up; positive dx is right.
    private func swipe(on id: String, dx: CGFloat, dy: CGFloat) {
        let element = key(id)
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: dx, dy: dy))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Horizontal drag across the space bar (moves the cursor). Negative dx
    /// is left. The press duration lets the slide gesture engage before the
    /// drag, so XCUITest emits interpolated move events.
    private func dragSpace(dx: CGFloat) {
        let space = key("space")
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: dx, dy: 0))
        start.press(forDuration: 0.2, thenDragTo: end)
    }

    // MARK: - Tests

    /// Hindi sequential combine: swiping the short vowel इ (top-center,
    /// down-right) twice collapses to the long vowel ई via CombineMiddleware.
    @MainActor
    func testHindiVowelLengtheningCombines() {
        relaunch(language: "hi_IN")
        swipe(on: "topCenter", dx: 40, dy: 40) // down-right → इ
        swipe(on: "topCenter", dx: 40, dy: 40) // down-right → इ, combines with previous → ई
        assertTypedText(equals: "ई")
    }

    /// Japanese kana voicing: type か (center, up-left) then the dakuten mark ゛
    /// (bottom-center, up-left) → the two combine into が via CombineMiddleware.
    @MainActor
    func testHiraganaDakutenCombines() {
        relaunch(language: "ja_JP")
        swipe(on: "center", dx: -40, dy: -40) // up-left → か
        swipe(on: "bottomCenter", dx: -40, dy: -40) // up-left → ゛, combines → が
        assertTypedText(equals: "が")
    }

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

    /// Compose: typing a base letter, then swiping the acute-accent trigger
    /// (topCenter ↗, `.compose(trigger: "´")`), composes the accented letter
    /// (´ + a → á).
    @MainActor
    func testComposeAcuteAccentProducesAccentedLetter() {
        let base = tapKey("topLeft") // "a" in de_DE
        XCTAssertEqual(base, "a", "Test assumes topLeft is 'a' on the de_DE lower layer")
        assertTypedText(equals: "a")

        // Swipe up-right on topCenter → emits .compose(trigger: "´").
        swipe(on: "topCenter", dx: 40, dy: -40)

        assertTypedText(equals: "á")
    }

    /// The return key inserts a line break between characters.
    @MainActor
    func testReturnKeyInsertsSeparator() {
        let first = tapKey("topLeft") // "a"
        tapKey("return")
        let second = tapKey("topCenter") // "b"

        // Accessibility may render the newline as "\n" or normalize it to a
        // space; either way there must be a separator between the two letters.
        // The exact "\n" is asserted in ReturnSwipePipelineTests.
        let value = typedText()
        XCTAssertEqual(value.count, 3, "Expected 3 characters with a separator, got '\(value)'")
        XCTAssertEqual(value.first.map(String.init), first)
        XCTAssertEqual(value.last.map(String.init), second)
        XCTAssertNotEqual(value, first + second, "Return should insert a separator")
    }

    /// Typing works across different scripts/layouts, not just German.
    @MainActor
    func testTypingWorksAcrossLanguages() {
        for language in ["fr_FR", "ru_RU"] {
            relaunch(language: language)

            let center = key("center")
            XCTAssertTrue(center.waitForExistence(timeout: 3), "center key missing for \(language)")
            let label = center.label
            center.tap()

            assertTypedText(equals: label)
        }
    }

    /// Swiping up on the shift key (midRight) switches to the shifted layer,
    /// so the next letter is uppercase.
    @MainActor
    func testShiftSwipeProducesUppercaseLetter() {
        swipe(on: "midRight", dx: 0, dy: -45) // ⇧ → shifted

        let typed = tapKey("topLeft")
        assertTypedText(equals: typed)
        XCTAssertFalse(typed.isEmpty)
        XCTAssertEqual(typed, typed.uppercased(), "Shifted layer should produce an uppercase letter")
    }

    /// A double swipe-up on the shift key engages caps-lock, so several
    /// letters in a row are uppercase (no auto-transition back to lower).
    @MainActor
    func testCapsLockProducesUppercaseSequence() {
        swipe(on: "midRight", dx: 0, dy: -45) // ⇧ → shifted
        swipe(on: "midRight", dx: 0, dy: -45) // ⇧⇧ → caps-lock

        let first = tapKey("topLeft")
        let second = tapKey("topCenter")
        assertTypedText(equals: first + second)
        XCTAssertEqual(first, first.uppercased())
        XCTAssertEqual(second, second.uppercased(), "Caps-lock should keep producing uppercase letters")
    }

    /// Dragging left on the space bar moves the cursor, so the next character
    /// is inserted before the end rather than appended.
    @MainActor
    func testSpaceDragMovesCursorForMidTextInsertion() {
        let c1 = tapKey("topLeft")
        let c2 = tapKey("topCenter")
        let c3 = tapKey("topRight")
        assertTypedText(equals: c1 + c2 + c3)

        dragSpace(dx: -120) // move cursor left (several steps)

        let inserted = tapKey("midLeft")

        let result = typedText()
        XCTAssertEqual(result.count, 4, "Expected four characters, got '\(result)'")
        XCTAssertTrue(result.contains(inserted), "Inserted character missing from '\(result)'")
        XCTAssertNotEqual(
            result, c1 + c2 + c3 + inserted,
            "Cursor should have moved left, so '\(inserted)' is not appended at the end"
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
        // Verify the switch actually landed on the numeric layer (a digit),
        // not just any echoable key (e.g. a punctuation/symbols layer).
        XCTAssertTrue(
            !label.isEmpty && label.allSatisfy(\.isNumber),
            "Expected a digit on the numeric layer after the symbols key, got '\(label)'"
        )
        center.tap()

        assertTypedText(equals: label)
    }
}
