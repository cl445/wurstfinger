//
//  KeyboardResizingTests.swift
//  wurstfingerUITests
//
//  End-to-end validation of Key-Target-Resizing (spec §5.5/§11.6): with a
//  hardcoded offset on the center column, a FIXED screen point just inside the
//  right column is reassigned to the center key. Proven by coordinate taps —
//  the touch frame, not the drawn key, decides assignment. This is the
//  automated form of the P3.5 device spike.
//

import XCTest

final class KeyboardResizingTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(spike: Bool) {
        app = XCUIApplication()
        app.launchArguments = ["SCREENSHOT_MODE"]
        app.launchEnvironment["TYPING_TEST"] = "1"
        app.launchEnvironment["FORCE_LANGUAGE"] = "de_DE"
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        if spike { app.launchEnvironment["TOUCH_OFFSET_SPIKE"] = "1" }
        app.launch()
        XCTAssertTrue(app.buttons["center"].waitForExistence(timeout: 5), "Keyboard not loaded")
        XCTAssertTrue(app.staticTexts["typedText"].waitForExistence(timeout: 2), "Typing harness missing")
    }

    private func typedText() -> String {
        (app.staticTexts["typedText"].value as? String) ?? ""
    }

    private func tapAbsolute(_ point: CGPoint) {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y))
            .tap()
    }

    private func waitText(_ expected: String) -> Bool {
        let predicate = NSPredicate { _, _ in self.typedText() == expected }
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 3
        ) == .completed
    }

    /// With the center column's hit cells shifted right, a fixed point that lies
    /// in the right key's territory when off lands in the center key when on.
    @MainActor
    func testResizingReassignsBoundaryTap() {
        // OFF: measure the nominal center|right boundary and the two characters.
        launch(spike: false)
        let centerFrameOff = app.buttons["center"].frame
        let centerChar = app.buttons["center"].label
        let rightChar = app.buttons["midRight"].label
        let boundaryOff = app.buttons["midRight"].frame.minX
        let rowY = centerFrameOff.midY
        XCTAssertNotEqual(centerChar, rightChar, "Center and right keys must differ for a meaningful test")
        app.terminate()

        // ON: the center column extended right → the boundary moved right.
        launch(spike: true)
        let centerFrameOn = app.buttons["center"].frame
        let boundaryOn = app.buttons["midRight"].frame.minX
        XCTAssertGreaterThan(
            boundaryOn, boundaryOff + 1,
            "Resizing should move the center|right hit boundary right (off \(boundaryOff), on \(boundaryOn))"
        )
        XCTAssertGreaterThan(
            centerFrameOn.maxX, centerFrameOff.maxX + 1,
            "The center key's touch frame should extend right"
        )

        // A point between the old and new boundary: right of the OFF boundary
        // (so OFF → right key), left of the ON boundary (so ON → center key).
        let probe = CGPoint(x: (boundaryOff + boundaryOn) / 2, y: rowY)
        tapAbsolute(probe)
        XCTAssertTrue(
            waitText(centerChar),
            "ON: the reassigned point should produce the center char '\(centerChar)', got '\(typedText())'"
        )
        app.terminate()

        // OFF control: the very same point produces the right key's char.
        launch(spike: false)
        tapAbsolute(probe)
        XCTAssertTrue(
            waitText(rightChar),
            "OFF: the same point should produce the right char '\(rightChar)', got '\(typedText())'"
        )
    }
}
