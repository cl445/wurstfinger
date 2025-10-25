//
//  wurstfingerTests.swift
//  wurstfingerTests
//
//  Created by Claas Flint on 24.10.25.
//

import Testing
@testable import wurstfinger
@testable import Wurstfinger

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
        #expect(firstKey.center == "7")

        let zeroKey = try #require(rows[3].first)
        #expect(zeroKey.center == "0")
    }

    @Test func symbolsLayerFollowsNumericLayer() async throws {
        let viewModel = KeyboardViewModel()

        viewModel.toggleSymbols()
        viewModel.toggleSymbols()

        #expect(viewModel.activeLayer == .symbols)

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

        let sevenKey = try #require(viewModel.rows.first?.first)
        viewModel.handleKeyTap(sevenKey)

        #expect(viewModel.rows.count == 4)

        let zeroKey = try #require(viewModel.rows[3].first)
        viewModel.handleKeyTap(zeroKey)

        #expect(inserted == ["7", "0"])
    }

    @Test func letterLayerProvidesAdditionalSymbols() async throws {
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

    @Test func spaceSelectionEmitsSelectionActions() async throws {
        let viewModel = KeyboardViewModel()
        var sequence: [String] = []

        viewModel.bindActionHandler { action in
            switch action {
            case .startSelection:
                sequence.append("start")
            case .updateSelection(let offset):
                sequence.append("update:\(offset)")
            case .endSelection:
                sequence.append("end")
            default:
                break
            }
        }

        viewModel.beginSpaceDrag()
        viewModel.beginSpaceSelection()
        viewModel.updateSpaceDrag(deltaX: 20)
        viewModel.updateSpaceDrag(deltaX: 20)
        viewModel.updateSpaceDrag(deltaX: -40)
        viewModel.endSpaceDrag()

        #expect(sequence == ["start", "update:1", "update:1", "update:-1", "update:-1", "end"])
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

    @Test func composeSwipeEmitsComposeAction() async throws {
        let viewModel = KeyboardViewModel()
        var captured: String?

        viewModel.bindActionHandler { action in
            if case let .compose(trigger) = action {
                captured = trigger
            }
        }

        let thirdRow = try #require(viewModel.rows.count > 2 ? viewModel.rows[2] : nil)
        let eKey = try #require(thirdRow.count > 1 ? thirdRow[1] : nil)
        viewModel.handleKeySwipe(eKey, direction: .upRight)

        #expect(captured == "'")
    }

    @Test func composeEngineProducesReplacement() async throws {
        #expect(ComposeEngine.compose(previous: "a", trigger: "\"") == "ä")
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

}
