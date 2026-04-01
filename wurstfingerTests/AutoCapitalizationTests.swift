//
//  AutoCapitalizationTests.swift
//  wurstfingerTests
//
//  Tests for auto-capitalization logic.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct AutoCapitalizationTests {
    // MARK: - shouldCapitalize tests

    @Test func capitalizeAtStartOfTextField() {
        #expect(AutoCapitalization.shouldCapitalize(context: nil))
        #expect(AutoCapitalization.shouldCapitalize(context: ""))
    }

    @Test func capitalizeAfterPeriod() {
        #expect(AutoCapitalization.shouldCapitalize(context: "Hello. "))
        #expect(AutoCapitalization.shouldCapitalize(context: "Hello.  "))
        #expect(AutoCapitalization.shouldCapitalize(context: "Hello.\n"))
    }

    @Test func capitalizeAfterExclamationMark() {
        #expect(AutoCapitalization.shouldCapitalize(context: "Hello! "))
        #expect(AutoCapitalization.shouldCapitalize(context: "Wow!\n"))
    }

    @Test func capitalizeAfterQuestionMark() {
        #expect(AutoCapitalization.shouldCapitalize(context: "How are you? "))
        #expect(AutoCapitalization.shouldCapitalize(context: "What?\n"))
    }

    @Test func capitalizeAfterEllipsis() {
        #expect(AutoCapitalization.shouldCapitalize(context: "Well… "))
        #expect(AutoCapitalization.shouldCapitalize(context: "Hmm…\n"))
    }

    @Test func capitalizeAfterCJKPunctuation() {
        #expect(AutoCapitalization.shouldCapitalize(context: "你好。"))
        #expect(AutoCapitalization.shouldCapitalize(context: "什么！"))
        #expect(AutoCapitalization.shouldCapitalize(context: "吗？"))
    }

    @Test func capitalizeWithOnlyWhitespace() {
        #expect(AutoCapitalization.shouldCapitalize(context: "   "))
        #expect(AutoCapitalization.shouldCapitalize(context: "\n\n"))
        #expect(AutoCapitalization.shouldCapitalize(context: " \n "))
    }

    @Test func noCapitalizeAfterComma() {
        #expect(!AutoCapitalization.shouldCapitalize(context: "Hello, "))
    }

    @Test func noCapitalizeAfterColon() {
        #expect(!AutoCapitalization.shouldCapitalize(context: "Note: "))
    }

    @Test func noCapitalizeAfterSemicolon() {
        #expect(!AutoCapitalization.shouldCapitalize(context: "First; "))
    }

    @Test func noCapitalizeMidWord() {
        #expect(!AutoCapitalization.shouldCapitalize(context: "Hello"))
        #expect(!AutoCapitalization.shouldCapitalize(context: "Hello "))
    }

    @Test func noCapitalizeAfterNumber() {
        #expect(!AutoCapitalization.shouldCapitalize(context: "123 "))
    }

    // MARK: - shouldCapitalizeImmediately tests

    @Test func immediateCapitalizeAfterSpanishOpeningQuestion() {
        #expect(AutoCapitalization.shouldCapitalizeImmediately(after: "¿"))
    }

    @Test func immediateCapitalizeAfterSpanishOpeningExclamation() {
        #expect(AutoCapitalization.shouldCapitalizeImmediately(after: "¡"))
    }

    @Test func noImmediateCapitalizeAfterRegularPunctuation() {
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "."))
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "!"))
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "?"))
    }

    @Test func noImmediateCapitalizeAfterLetter() {
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "a"))
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "Z"))
    }

    @Test func noImmediateCapitalizeAfterMultipleCharacters() {
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "¿¿"))
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: "ab"))
    }

    @Test func noImmediateCapitalizeAfterEmptyString() {
        #expect(!AutoCapitalization.shouldCapitalizeImmediately(after: ""))
    }

    // MARK: - sentenceEnders and sentenceOpeners

    @Test func sentenceEndersContainsExpectedCharacters() {
        let expected: Set<Character> = [".", "!", "?", "…", "。", "！", "？"]
        #expect(AutoCapitalization.sentenceEnders == expected)
    }

    @Test func sentenceOpenersContainsExpectedCharacters() {
        let expected: Set<Character> = ["¿", "¡"]
        #expect(AutoCapitalization.sentenceOpeners == expected)
    }

    // MARK: - Integration tests for KeyboardViewModel

    @Test func viewModelStaysUpperAfterSpanishOpeningQuestion() {
        let viewModel = KeyboardViewModel()

        // Simulate what KeyboardViewController does: set layer to upper after ¿
        viewModel.bindActionHandler { action in
            if case let .insert(text) = action {
                if AutoCapitalization.shouldCapitalizeImmediately(after: text) {
                    viewModel.setLayer(.upper)
                }
            }
        }

        // Start in lower case
        viewModel.setLayer(.lower)
        #expect(viewModel.activeLayer == .lower)

        // Simulate inserting ¿ via the keyboard
        // We need to trigger the text insertion flow
        viewModel.simulateTextInsertion("¿")

        // After inserting ¿, the layer should be upper (not reset to lower)
        #expect(viewModel.activeLayer == .upper, "Layer should stay upper after inserting ¿")
    }

    @Test func viewModelStaysUpperAfterSpanishOpeningExclamation() {
        let viewModel = KeyboardViewModel()

        viewModel.bindActionHandler { action in
            if case let .insert(text) = action {
                if AutoCapitalization.shouldCapitalizeImmediately(after: text) {
                    viewModel.setLayer(.upper)
                }
            }
        }

        viewModel.setLayer(.lower)
        viewModel.simulateTextInsertion("¡")

        #expect(viewModel.activeLayer == .upper, "Layer should stay upper after inserting ¡")
    }

    @Test func viewModelResetsToLowerAfterRegularCharacter() {
        let viewModel = KeyboardViewModel()

        viewModel.bindActionHandler { _ in }

        // Start in upper case (simulating temporary shift)
        viewModel.setLayer(.upper)
        #expect(viewModel.activeLayer == .upper)

        // Insert a regular character
        viewModel.simulateTextInsertion("a")

        // After inserting a regular character, should reset to lower
        #expect(viewModel.activeLayer == .lower, "Layer should reset to lower after regular character")
    }

    // MARK: - Bug #113: Manual shift should survive auto-capitalization reset

    @Test func manualShiftIsTracked() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        viewModel.bindActionHandler { _ in }

        // User manually activates shift via toggleShift
        viewModel.toggleShift()
        #expect(viewModel.activeLayer == .upper)
        #expect(viewModel.isManualShift == true, "toggleShift should set isManualShift")
    }

    @Test func autoCapShiftIsNotManual() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        viewModel.bindActionHandler { _ in }

        // Auto-capitalization sets layer via setLayer (not toggleShift)
        viewModel.setLayer(.upper)
        #expect(viewModel.activeLayer == .upper)
        #expect(viewModel.isManualShift == false, "setLayer should not set isManualShift")
    }

    @Test func manualShiftClearsAfterInsertion() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        viewModel.bindActionHandler { _ in }

        // User manually shifts, then types a character
        viewModel.toggleShift()
        #expect(viewModel.isManualShift == true)

        viewModel.simulateTextInsertion("a")
        #expect(viewModel.activeLayer == .lower, "Temporary shift should reset after insertion")
        #expect(viewModel.isManualShift == false, "isManualShift should clear after insertion")
    }

    @Test func manualShiftClearsWhenDeactivated() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        viewModel.bindActionHandler { _ in }

        viewModel.toggleShift()
        #expect(viewModel.isManualShift == true)

        // Deactivate shift
        viewModel.toggleShift()
        #expect(viewModel.activeLayer == .lower)
        #expect(viewModel.isManualShift == false, "isManualShift should clear when shift is toggled off")
    }

    @Test func capsLockDoesNotSetManualShift() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        viewModel.bindActionHandler { _ in }

        // First shift activation: temporary shift
        viewModel.toggleShift()
        #expect(viewModel.activeLayer == .upper)
        #expect(viewModel.isManualShift == true)

        // Simulate second shift-up swipe while already upper → caps-lock
        // (In the real keyboard, this is a swipe-up on the shift key,
        // which calls setShiftState(active: true) via .toggleShift(on: true))
        let shiftKey = viewModel.rows[1][2]
        viewModel.handleKeySwipe(shiftKey, direction: .up)
        #expect(viewModel.isCapsLockActive == true)
        #expect(viewModel.isManualShift == false, "Caps-lock should clear isManualShift")
    }
}
