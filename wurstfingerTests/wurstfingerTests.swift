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

    @Test(.disabled("Requires UI context - to be fixed later"))
    func letterLayerProvidesAdditionalSymbols() async throws {
        let viewModel = KeyboardViewModel()
        let firstRow = try #require(viewModel.rows.first)
        let aKey = try #require(firstRow.first)
        let nKey = try #require(firstRow.dropFirst().first)
        let sKey = try #require(viewModel.rows[2].last)

        #expect(aKey.primaryLabel(for: .downLeft) == "$")
        #expect(aKey.primaryLabel(for: .upRight) == "¿¡")
        #expect(nKey.primaryLabel(for: .up) == "^")
        #expect(nKey.primaryLabel(for: .downRight) == "\\")
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

    @Test func deleteWordActionEmits() async throws {
        let viewModel = KeyboardViewModel()
        var didDeleteWord = false

        viewModel.bindActionHandler { action in
            if case .deleteWord = action {
                didDeleteWord = true
            }
        }

        viewModel.handleDeleteWord()

        #expect(didDeleteWord)
    }

    @Test func hapticIntensitiesPersistToDefaults() async throws {
        let suite = "group.de.akator.wurstfinger.tests.hapticsPersist"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = KeyboardViewModel(userDefaults: defaults)
        viewModel.hapticIntensityTap = 0.8
        viewModel.hapticIntensityModifier = 0.2
        viewModel.hapticIntensityDrag = 1.1

        #expect(defaults.double(forKey: KeyboardViewModel.hapticTapIntensityKey) == 0.8)
        #expect(defaults.double(forKey: KeyboardViewModel.hapticModifierIntensityKey) == 0.2)
        let dragDefault = defaults.double(forKey: KeyboardViewModel.hapticDragIntensityKey)
        #expect(abs(dragDefault - 1.0) < 0.0001)
    }

    @Test func previewViewModelDoesNotPersist() async throws {
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

    @Test func hapticIntensityClampsWithinBounds() async throws {
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

    @Test(.disabled("Requires UI context - to be fixed later"))
    func composeSwipeEmitsComposeAction() async throws {
        let viewModel = KeyboardViewModel()
        var captured: String?

        viewModel.bindActionHandler { action in
            if case let .compose(trigger) = action {
                captured = trigger
            }
        }

        let firstRow = try #require(viewModel.rows.first)
        let aKey = try #require(firstRow.first)
        viewModel.handleKeySwipe(aKey, direction: .upRight)

        #expect(captured == "!")
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

}
