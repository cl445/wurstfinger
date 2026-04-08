//
//  DeadZoneTests.swift
//  wurstfingerUITests
//
//  UI tests that verify there are no dead zones on the keyboard surface.
//  Taps in the gaps between keys and at keyboard edges, then checks that
//  each tap produces an action.
//

import XCTest

final class DeadZoneTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = [
            "SCREENSHOT_MODE",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launchEnvironment["FORCE_LAYER"] = "lower"
        app.launchEnvironment["FORCE_APPEARANCE"] = "light"
        app.launchEnvironment["DEAD_ZONE_TEST"] = "1"
        app.launch()
    }

    // MARK: - Helpers

    private func actionCount() -> Int {
        let el = app.staticTexts.matching(identifier: "actionCount").firstMatch
        guard let count = Int(el.label) else {
            XCTFail("Failed to parse actionCount label: '\(el.label)'")
            return 0
        }
        return count
    }

    /// Taps at the given screen coordinate and asserts the action counter incremented.
    private func tapAndAssert(
        x: CGFloat,
        y: CGFloat,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let before = actionCount()
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: y))
            .tap()
        let predicate = NSPredicate { _, _ in self.actionCount() > before }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
        let after = actionCount()
        XCTAssertGreaterThan(
            after, before,
            "Dead zone: \(label) at (\(Int(x)), \(Int(y)))\(result == .timedOut ? " (timed out)" : "")",
            file: file, line: line
        )
    }

    /// Finds a button by accessibility label in the app.
    private func findKey(
        _ keyLabel: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement? {
        let key = app.buttons[keyLabel]
        if !key.waitForExistence(timeout: 2) {
            XCTFail("Key '\(keyLabel)' not found", file: file, line: line)
            return nil
        }
        return key
    }

    private func waitForKeyboard() {
        let keyA = app.buttons["a"]
        XCTAssertTrue(keyA.waitForExistence(timeout: 5), "Keyboard not loaded")
        let counter = app.staticTexts.matching(identifier: "actionCount").firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 2), "Action counter not found")
    }

    // MARK: - Grid key labels (German lower layout)

    //
    //   Col 0   Col 1   Col 2   |  Col 3 (utility, right side)
    //     a       n       i     |    🌐  (row 0)
    //     h       d       r     |   123  (row 1)
    //     t       e       s     |    ⌫   (row 2)
    //         [ Space ]         |    ⏎   (row 3)

    private let gridKeys: [[String]] = [
        ["a", "n", "i"],
        ["h", "d", "r"],
        ["t", "e", "s"],
    ]

    // MARK: - Tests

    /// Tap in every horizontal gap between adjacent grid keys (rows 0–2).
    @MainActor
    func testHorizontalGapsBetweenGridKeys() {
        waitForKeyboard()

        for (rowIdx, row) in gridKeys.enumerated() {
            for colIdx in 0 ..< (row.count - 1) {
                guard let left = findKey(row[colIdx]),
                      let right = findKey(row[colIdx + 1])
                else { continue }

                let x = (left.frame.maxX + right.frame.minX) / 2
                let y = (left.frame.midY + right.frame.midY) / 2
                tapAndAssert(
                    x: x, y: y,
                    label: "h-gap row \(rowIdx): \(row[colIdx])-\(row[colIdx + 1])"
                )
            }
        }
    }

    /// Tap in every vertical gap between adjacent rows of grid keys,
    /// including the gap between row 2 and the space bar row.
    @MainActor
    func testVerticalGapsBetweenRows() {
        waitForKeyboard()

        // Between grid rows 0–1 and 1–2
        for rowIdx in 0 ..< (gridKeys.count - 1) {
            for colIdx in 0 ..< gridKeys[rowIdx].count {
                guard let top = findKey(gridKeys[rowIdx][colIdx]),
                      let bottom = findKey(gridKeys[rowIdx + 1][colIdx])
                else { continue }

                let x = (top.frame.midX + bottom.frame.midX) / 2
                let y = (top.frame.maxY + bottom.frame.minY) / 2
                tapAndAssert(
                    x: x, y: y,
                    label: "v-gap: \(gridKeys[rowIdx][colIdx])-\(gridKeys[rowIdx + 1][colIdx])"
                )
            }
        }

        // Between row 2 and space bar row: use Return key as row 3 anchor
        guard let ret = findKey("Return") else { return }
        for letter in gridKeys[2] {
            guard let top = findKey(letter) else { continue }
            let x = top.frame.midX
            let y = (top.frame.maxY + ret.frame.minY) / 2
            tapAndAssert(x: x, y: y, label: "v-gap: \(letter)-SpaceRow")
        }
    }

    /// Tap at the intersection of horizontal and vertical gaps where four keys meet.
    @MainActor
    func testDiagonalGapIntersections() {
        waitForKeyboard()

        for rowIdx in 0 ..< (gridKeys.count - 1) {
            for colIdx in 0 ..< (gridKeys[rowIdx].count - 1) {
                guard let topLeft = findKey(gridKeys[rowIdx][colIdx]),
                      let topRight = findKey(gridKeys[rowIdx][colIdx + 1]),
                      let botLeft = findKey(gridKeys[rowIdx + 1][colIdx])
                else { continue }

                let x = (topLeft.frame.maxX + topRight.frame.minX) / 2
                let y = (topLeft.frame.maxY + botLeft.frame.minY) / 2
                tapAndAssert(
                    x: x, y: y,
                    label: "intersection: \(gridKeys[rowIdx][colIdx])/" +
                        "\(gridKeys[rowIdx][colIdx + 1])/" +
                        "\(gridKeys[rowIdx + 1][colIdx])/" +
                        "\(gridKeys[rowIdx + 1][colIdx + 1])"
                )
            }
        }
    }

    /// Tap in gaps between the space bar row and the grid/utility keys.
    @MainActor
    func testSpaceBarAndUtilityGaps() {
        waitForKeyboard()

        guard let ret = findKey("Return") else { return }

        // Gap between Space bar and Return key (horizontal)
        // Tap between space bar's right side and Return
        let gapInset = ret.frame.width * 0.05
        tapAndAssert(
            x: ret.frame.minX - gapInset,
            y: ret.frame.midY,
            label: "gap Space-Return"
        )

        // Gap between grid key 's' and Delete (row 2, grid to utility)
        if let keyS = findKey("s") {
            let hOffset = keyS.frame.width * 0.3
            tapAndAssert(
                x: keyS.frame.maxX + hOffset,
                y: keyS.frame.midY,
                label: "h-gap: s-Delete"
            )
        }

        // Gap between Delete and Return (vertical, utility column)
        if let keyS = findKey("s") {
            let hOffset = keyS.frame.width * 0.5
            tapAndAssert(
                x: keyS.frame.maxX + hOffset,
                y: (keyS.frame.maxY + ret.frame.minY) / 2,
                label: "v-gap: Delete-Return"
            )
        }
    }

    /// Tap at the very edges of the keyboard surface.
    @MainActor
    func testEdgePaddingAreas() {
        waitForKeyboard()

        // Left edge — well to the left of the leftmost grid key
        if let keyA = findKey("a") {
            let edgeInset = keyA.frame.width * 0.15
            tapAndAssert(
                x: keyA.frame.minX - edgeInset,
                y: keyA.frame.midY,
                label: "left edge near 'a'"
            )
        }
        if let keyT = findKey("t") {
            let edgeInset = keyT.frame.width * 0.15
            tapAndAssert(
                x: keyT.frame.minX - edgeInset,
                y: keyT.frame.midY,
                label: "left edge near 't'"
            )
        }

        // Right edge — outside the utility column (true keyboard boundary)
        if let ret = findKey("Return") {
            let edgeInset = ret.frame.width * 0.15
            tapAndAssert(
                x: ret.frame.maxX + edgeInset,
                y: ret.frame.midY,
                label: "right edge outside utility column"
            )
        }

        // Top edge — above the top row
        if let keyA = findKey("a") {
            let edgeInset = keyA.frame.height * 0.15
            tapAndAssert(
                x: keyA.frame.midX,
                y: keyA.frame.minY - edgeInset,
                label: "top edge above 'a'"
            )
        }
        if let keyN = findKey("n") {
            let edgeInset = keyN.frame.height * 0.15
            tapAndAssert(
                x: keyN.frame.midX,
                y: keyN.frame.minY - edgeInset,
                label: "top edge above 'n'"
            )
        }
        if let keyI = findKey("i") {
            let edgeInset = keyI.frame.height * 0.15
            tapAndAssert(
                x: keyI.frame.midX,
                y: keyI.frame.minY - edgeInset,
                label: "top edge above 'i'"
            )
        }

        // Bottom edge — below the space bar / return row
        if let ret = findKey("Return") {
            let edgeInset = ret.frame.height * 0.1
            tapAndAssert(
                x: ret.frame.midX,
                y: ret.frame.maxY + edgeInset,
                label: "bottom edge below Return"
            )
            if let keyE = findKey("e") {
                tapAndAssert(
                    x: keyE.frame.midX,
                    y: ret.frame.maxY + edgeInset,
                    label: "bottom edge below Space"
                )
            }
        }
    }
}
