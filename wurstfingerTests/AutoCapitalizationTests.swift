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
            if case .insert(let text) = action {
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
            if case .insert(let text) = action {
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
}
