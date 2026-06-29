//
//  ReturnSwipePipelineTests.swift
//  WurstfingerTests
//
//  Integration tests for the return-swipe path through KeyboardViewModel.
//
//  A return swipe (out and back to the start) is an out-and-back continuous
//  drag that XCUITest cannot synthesize, so it is verified here at the
//  pipeline level instead: handleGesture(..., isReturn: true) must resolve
//  the binding's returnAction rather than its primary action.
//
//  ReturnSwipeLanguageTests already covers center-key letter overrides; this
//  complements it with the shared symbol-slot return actions.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct ReturnSwipePipelineTests {
    private func inserts(_ target: MockTextTarget) -> [String] {
        target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
    }

    /// A return swipe on a symbol slot produces its `returnAction`, not its
    /// primary action.
    @Test func returnSwipeOnSymbolSlotProducesReturnAction() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // topCenter ↗ has a compose primary action and a distinct return action.
        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topCenter),
              let binding = key.bindings[.swipeUpRight],
              case let .commitText(expected) = binding.returnAction
        else {
            Issue.record("Expected topCenter ↗ to carry a commitText return action")
            return
        }

        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: true)

        #expect(inserts(target).last == expected)
    }

    /// The same gesture without the return flag does NOT emit the return
    /// action — guarding against the two paths collapsing.
    @Test func plainSwipeDoesNotProduceReturnAction() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topCenter),
              let binding = key.bindings[.swipeUpRight],
              case let .commitText(returnText) = binding.returnAction
        else {
            Issue.record("Expected topCenter ↗ to carry a commitText return action")
            return
        }

        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: false)

        #expect(!inserts(target).contains(returnText))
    }

    /// A return swipe on a plain punctuation slot commits its return character.
    @Test func returnSwipeOnPunctuationSlotCommitsReturnCharacter() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // topLeft → (swipeRight) maps "-" with a "÷" return action.
        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topLeft),
              let binding = key.bindings[.swipeRight],
              case let .commitText(expected) = binding.returnAction
        else {
            Issue.record("Expected topLeft → to carry a commitText return action")
            return
        }

        vm.handleGesture(.swipeRight, keyId: GridSlot.topLeft, isReturn: true)

        #expect(inserts(target).last == expected)
    }

    // MARK: - Newline

    /// The newline swipe (topRight ↗) inserts a line break.
    @Test func newlineSwipeInsertsLineBreak() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topRight),
              case .commitText("\n") = key.bindings[.swipeUpRight]?.action
        else {
            Issue.record("Expected topRight ↗ to commit a newline")
            return
        }

        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topRight, isReturn: false)

        #expect(inserts(target).last == "\n")
    }

    /// Tapping the return utility key inserts a line break.
    @Test func returnKeyInsertsLineBreak() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: UtilitySlot.return, isReturn: false)

        #expect(inserts(target).last == "\n")
    }
}
