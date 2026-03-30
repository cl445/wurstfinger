//
//  wurstfingerTests.swift
//  wurstfingerTests
//
//  Created by Claas Flint on 24.10.25.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct wurstfingerTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func circularGestureInsertsUppercaseForBothDirections() async throws {
        let viewModel = KeyboardViewModel()
        var inserted: [String] = []

        viewModel.bindActionHandler { action in
            if case let .insert(value) = action {
                inserted.append(value)
            }
        }

        let key = try #require(viewModel.rows.first?.first)

        viewModel.handleCircularGesture(for: key, direction: .clockwise)
        viewModel.handleCircularGesture(for: key, direction: .counterclockwise)

        #expect(inserted == ["A", "A"])
    }

    @Test func toggleSymbolsShowsNumericLayout() async throws {
        let viewModel = KeyboardViewModel()
        viewModel.toggleSymbols()

        #expect(viewModel.activeLayer == .numbers)
        let rows = viewModel.rows
        #expect(rows.count == 4)

        let firstKey = try #require(rows.first?.first)
        #expect(firstKey.center == "1")

        let zeroKey = try #require(rows[3].first)
        #expect(zeroKey.center == "0")
    }

    @Test func symbolsLayerFollowsNumericLayer() async throws {
        let viewModel = KeyboardViewModel()

        // First toggle: lower → numbers
        viewModel.toggleSymbols()
        #expect(viewModel.activeLayer == .numbers)

        // Second toggle: numbers → lower
        viewModel.toggleSymbols()
        #expect(viewModel.activeLayer == .lower)

        let rows = viewModel.rows
        let aKey = try #require(rows.first?.first)
        #expect(aKey.primaryLabel(for: .downLeft) == "$")
    }

    @Test func circularGestureOnGlobeTogglesUtilityColumn() async throws {
        let viewModel = KeyboardViewModel()

        #expect(!viewModel.utilityColumnLeading)

        viewModel.handleUtilityCircularGesture(.globe, direction: .counterclockwise)
        #expect(viewModel.utilityColumnLeading)

        viewModel.handleUtilityCircularGesture(.globe, direction: .clockwise)
        #expect(!viewModel.utilityColumnLeading)
    }

    @Test func numericLayerInsertsDigits() async throws {
        let viewModel = KeyboardViewModel()
        var inserted: [String] = []

        viewModel.bindActionHandler { action in
            if case let .insert(value) = action {
                inserted.append(value)
            }
        }

        viewModel.toggleSymbols()

        let oneKey = try #require(viewModel.rows.first?.first)
        viewModel.handleKeyTap(oneKey)

        #expect(viewModel.rows.count == 4)

        let zeroKey = try #require(viewModel.rows[3].first)
        viewModel.handleKeyTap(zeroKey)

        #expect(inserted == ["1", "0"])
    }

    @Test func letterLayerProvidesAdditionalSymbols() async throws {
        let viewModel = KeyboardViewModel()
        let firstRow = try #require(viewModel.rows.first)
        let aKey = try #require(firstRow.first)
        let nKey = try #require(firstRow.dropFirst().first)
        let sKey = try #require(viewModel.rows[2].last)

        // A-key (row 0, col 0) swipe outputs
        #expect(aKey.primaryLabel(for: .downLeft) == "$")
        #expect(aKey.primaryLabel(for: .right) == "-")

        // N-key (row 0, col 1) swipe outputs including compose triggers
        #expect(nKey.primaryLabel(for: .up) == "^")
        #expect(nKey.primaryLabel(for: .downRight) == "\\")
        #expect(nKey.primaryLabel(for: .right) == "!")

        // S-key (row 2, col 2) swipe outputs
        #expect(sKey.primaryLabel(for: .left) == "#")
        #expect(sKey.primaryLabel(for: .right) == ">")
    }

    @Test func spaceDragEmitsCursorMovements() async throws {
        let viewModel = KeyboardViewModel()
        var moves: [Int] = []

        viewModel.bindActionHandler { action in
            if case let .moveCursor(offset) = action {
                moves.append(offset)
            }
        }

        viewModel.beginSpaceDrag()
        viewModel.updateSpaceDrag(deltaX: 20)
        viewModel.updateSpaceDrag(deltaX: 20)
        viewModel.updateSpaceDrag(deltaX: -50)
        viewModel.endSpaceDrag()

        #expect(moves == [1, 1, -1, -1])
    }

    @Test func deleteDragEmitsRepeatedDeletes() async throws {
        let viewModel = KeyboardViewModel()
        var deletes = 0

        viewModel.bindActionHandler { action in
            if case .deleteBackward = action {
                deletes += 1
            }
        }

        viewModel.beginDeleteDrag()
        viewModel.updateDeleteDrag(deltaX: -20)
        viewModel.updateDeleteDrag(deltaX: -20)
        viewModel.endDeleteDrag()

        #expect(deletes == 2)
    }

    @Test @MainActor func hapticIntensitiesPersistToDefaults() throws {
        let suite = "group.de.akator.wurstfinger.tests.hapticsPersist"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = KeyboardViewModel(userDefaults: defaults)
        viewModel.hapticIntensityTap = 0.8
        viewModel.hapticIntensityModifier = 0.2
        viewModel.hapticIntensityDrag = 1.1

        // Ensure UserDefaults are flushed (can be delayed in CI environments)
        defaults.synchronize()

        #expect(defaults.double(forKey: KeyboardViewModel.hapticTapIntensityKey) == 0.8)
        #expect(defaults.double(forKey: KeyboardViewModel.hapticModifierIntensityKey) == 0.2)
        let dragDefault = defaults.double(forKey: KeyboardViewModel.hapticDragIntensityKey)
        #expect(abs(dragDefault - 1.0) < 0.0001)
    }

    @Test @MainActor func previewViewModelDoesNotPersist() throws {
        let suite = "group.de.akator.wurstfinger.tests.preview"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(0.3, forKey: KeyboardViewModel.hapticTapIntensityKey)

        let viewModel = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        #expect(abs(viewModel.hapticIntensityTap - 0.3) < 0.0001)

        viewModel.hapticIntensityTap = 0.9
        let persistedTap = defaults.double(forKey: KeyboardViewModel.hapticTapIntensityKey)
        #expect(abs(persistedTap - 0.3) < 0.0001)
    }

    @Test @MainActor func hapticIntensityClampsWithinBounds() throws {
        let suite = "group.de.akator.wurstfinger.tests.clamp"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = KeyboardViewModel(userDefaults: defaults)

        viewModel.hapticIntensityTap = -0.5
        viewModel.hapticIntensityDrag = 2.0

        #expect(abs(viewModel.hapticIntensityTap - 0.0) < 0.0001)
        #expect(abs(viewModel.hapticIntensityDrag - 1.0) < 0.0001)
        let storedDrag = defaults.double(forKey: KeyboardViewModel.hapticDragIntensityKey)
        #expect(abs(storedDrag - 1.0) < 0.0001)
    }

    @Test func composeSwipeEmitsComposeAction() async throws {
        let viewModel = KeyboardViewModel()
        var captured: String?

        viewModel.bindActionHandler { action in
            if case let .compose(trigger) = action {
                captured = trigger
            }
        }

        // N-key (row 0, col 1) has compose triggers: upLeft=`, up=^, upRight=´
        let firstRow = try #require(viewModel.rows.first)
        let nKey = try #require(firstRow.count > 1 ? firstRow[1] : nil)
        viewModel.handleKeySwipe(nKey, direction: .upRight)

        #expect(captured == "´")
    }

    @Test func composeEngineProducesReplacement() async throws {
        #expect(ComposeEngine.compose(previous: "a", trigger: "¨") == "ä")
        #expect(ComposeEngine.compose(previous: "l", trigger: "!") == "ł")
        #expect(ComposeEngine.compose(previous: "x", trigger: "~") == nil)
    }

    @Test func returnSwipeOnPlusProducesTimes() async throws {
        let viewModel = KeyboardViewModel()
        var inserted: [String] = []

        viewModel.bindActionHandler { action in
            if case let .insert(value) = action {
                inserted.append(value)
            }
        }

        let firstRow = try #require(viewModel.rows.first)
        let nKey = try #require(firstRow.count > 1 ? firstRow[1] : nil)

        viewModel.handleKeySwipeReturn(nKey, direction: .left)

        #expect(inserted.last == "×")
    }

    @Test func returnSwipesProduceTypographicVariants() async throws {
        let viewModel = KeyboardViewModel()
        var inserted: [String] = []

        viewModel.bindActionHandler { action in
            if case let .insert(value) = action {
                inserted.append(value)
            }
        }

        func trigger(row: Int, column: Int, direction: KeyboardDirection, expected: String) throws {
            inserted.removeAll()
            let rows = viewModel.rows
            let targetRow = try #require(row < rows.count ? rows[row] : nil)
            let key = try #require(column < targetRow.count ? targetRow[column] : nil)
            viewModel.handleKeySwipeReturn(key, direction: direction)
            #expect(inserted.last == expected)
        }

        try trigger(row: 0, column: 1, direction: .right, expected: "¡") // ! → ¡
        try trigger(row: 0, column: 1, direction: .downLeft, expected: "–") // / → –
        try trigger(row: 0, column: 2, direction: .left, expected: "¿") // ? → ¿
        try trigger(row: 0, column: 0, direction: .right, expected: "÷") // - → ÷
        try trigger(row: 2, column: 1, direction: .down, expected: "…") // . → …
        try trigger(row: 2, column: 1, direction: .downLeft, expected: ",") // , → ,
        try trigger(row: 2, column: 1, direction: .upLeft, expected: "\u{201C}") // " → "
        try trigger(row: 2, column: 1, direction: .upRight, expected: "\u{201D}") // upRight → "
        try trigger(row: 2, column: 0, direction: .left, expected: "‹") // < → ‹
        try trigger(row: 2, column: 0, direction: .right, expected: "†") // * → †
        try trigger(row: 2, column: 2, direction: .right, expected: "›") // > → ›
        try trigger(row: 1, column: 0, direction: .upRight, expected: "‰") // % → ‰
    }

    @Test func directPunctuationSwipeDoesNotCompose() async throws {
        let viewModel = KeyboardViewModel()
        var inserts: [String] = []
        var composed: [String] = []

        viewModel.bindActionHandler { action in
            switch action {
            case .insert(let value):
                inserts.append(value)
            case .compose(let trigger):
                composed.append(trigger)
            default:
                break
            }
        }

        let firstRow = try #require(viewModel.rows.first)
        let nKey = try #require(firstRow.count > 1 ? firstRow[1] : nil)
        viewModel.handleKeySwipe(nKey, direction: .right)

        let iKey = try #require(firstRow.count > 2 ? firstRow[2] : nil)
        viewModel.handleKeySwipe(iKey, direction: .left)

        #expect(composed.isEmpty)
        #expect(inserts.suffix(2) == ["!", "?"])
    }

    // MARK: - ComposeEngine Determinism Tests

    @Test func accentCycleOrderIsDeterministic() {
        // Running cycleAccent multiple times should always produce the same sequence
        let runs = (0 ..< 5).map { _ in
            ComposeEngine.cycleAccent(for: "a")
        }
        // All runs should return the same result
        for run in runs {
            #expect(run == runs[0], "Accent cycle should be deterministic across calls")
        }
    }

    @Test func numberCycleOrderIsDeterministic() {
        // Number cycles should always return the same next character
        let runs = (0 ..< 5).map { _ in
            ComposeEngine.cycleAccent(for: "1")
        }
        #expect(runs[0] != nil, "cycleAccent should return a value for '1'")
        for run in runs {
            #expect(run == runs[0], "Number cycle should be deterministic across calls")
        }
    }

    @Test func accentCycleRoundTripsBackToBase() {
        // Starting from "a", cycling through all variants should return to "a"
        var current = "a"
        var visited: [String] = [current]

        for _ in 0 ..< 50 { // Safety limit (generous for large compose tables)
            guard let next = ComposeEngine.cycleAccent(for: current) else { break }
            if next == "a" {
                // Successfully round-tripped
                break
            }
            #expect(!visited.contains(next), "Cycle should not revisit '\(next)' — would loop forever. Visited: \(visited)")
            current = next
            visited.append(current)
        }

        #expect(visited.count > 1, "Should have at least one accent variant for 'a'")
        // Verify the cycle actually returns to the base character
        let lastStep = ComposeEngine.cycleAccent(for: current)
        #expect(lastStep == "a", "Last variant '\(current)' should cycle back to 'a', got '\(lastStep ?? "nil")'. Full cycle: \(visited)")
    }

    // MARK: - GestureFeatures.empty Tests

    @Test func gestureFeatureEmptyHasSensibleDefaults() {
        let empty = GestureFeatures.empty()

        #expect(empty.pathLength == 0)
        #expect(empty.chordLength == 0)
        #expect(empty.maxDisplacement == 0)
        #expect(empty.returnRatio == 1) // No movement = "returned"
        #expect(empty.isTap == true) // Zero displacement = tap
        #expect(empty.isReturn == false)
        #expect(empty.isCircular == false)
    }

    @Test func gestureFeatureExtractHandlesEmptyPoints() {
        let empty = GestureFeatures.extract(from: [])
        #expect(empty.pathLength == 0)
        #expect(empty.isTap == true)

        let single = GestureFeatures.extract(from: [.zero])
        #expect(single.pathLength == 0)
        #expect(single.isTap == true)
    }

    // MARK: - Apostrophe compose regression (#89)

    @Test func apostropheIsNeverAComposeTrigger() async throws {
        // Verify no key in the layout uses apostrophe (') as a compose trigger.
        // Composition uses ´ (U+00B4 acute accent), not ' (U+0027 apostrophe).
        let viewModel = KeyboardViewModel()

        for (rowIndex, row) in viewModel.rows.enumerated() {
            for (colIndex, key) in row.enumerated() {
                for direction in KeyboardDirection.allCases {
                    guard let output = key.output(for: direction) else { continue }
                    if case let .compose(trigger, _) = output {
                        #expect(
                            trigger != "'",
                            "Apostrophe must not be a compose trigger (found at row \(rowIndex), col \(colIndex), direction \(direction))"
                        )
                    }
                }
            }
        }
    }

    @Test func apostropheReturnSwipeInsertsPlainText() async throws {
        // Return swipe on N-key upRight should insert plain apostrophe,
        // not trigger compose mode (returnOverride with .text("'"))
        let viewModel = KeyboardViewModel()
        var inserts: [String] = []
        var composed: [String] = []

        viewModel.bindActionHandler { action in
            switch action {
            case .insert(let value):
                inserts.append(value)
            case .compose(let trigger):
                composed.append(trigger)
            default:
                break
            }
        }

        let firstRow = try #require(viewModel.rows.first)
        let nKey = try #require(firstRow.count > 1 ? firstRow[1] : nil)

        viewModel.handleKeySwipeReturn(nKey, direction: .upRight)

        #expect(composed.isEmpty, "Return swipe should not trigger compose")
        #expect(inserts.last == "'", "Return swipe should insert plain apostrophe")
    }

    @Test func acuteComposeKeyProducesAccentedCharacters() async throws {
        // The ´ compose key uses ´ (U+00B4) as trigger, not ' (U+0027)
        #expect(ComposeEngine.compose(previous: "a", trigger: "´") == "á")
        #expect(ComposeEngine.compose(previous: "e", trigger: "´") == "é")
        #expect(ComposeEngine.compose(previous: "i", trigger: "´") == "í")
        #expect(ComposeEngine.compose(previous: "o", trigger: "´") == "ó")
        #expect(ComposeEngine.compose(previous: "u", trigger: "´") == "ú")
        #expect(ComposeEngine.compose(previous: "n", trigger: "´") == "ń")
    }

    @Test func apostropheDoesNotComposeAccentedCharacters() async throws {
        // Apostrophe (') must NOT produce accented characters via ComposeEngine
        #expect(ComposeEngine.compose(previous: "a", trigger: "'") == nil)
        #expect(ComposeEngine.compose(previous: "e", trigger: "'") == nil)
        #expect(ComposeEngine.compose(previous: "o", trigger: "'") == nil)
    }

    @Test func dollarSignRemainsAutoComposeTrigger() async throws {
        // $ is in composeTriggers and appears in textMap for key (0,0) downLeft.
        // Swiping there should emit .compose, confirming auto-detection still works.
        let viewModel = KeyboardViewModel()
        var composed: [String] = []

        viewModel.bindActionHandler { action in
            if case let .compose(trigger) = action {
                composed.append(trigger)
            }
        }

        let firstRow = try #require(viewModel.rows.first)
        let firstKey = try #require(firstRow.first)

        viewModel.handleKeySwipe(firstKey, direction: .downLeft)

        #expect(composed.last == "$", "$ should still be auto-detected as compose trigger")
    }

}
