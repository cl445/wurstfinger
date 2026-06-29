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
    // MARK: - shouldCapitalize tests (pure logic, no ViewModel)

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

    @Test func noCapitalizeAfterWesternEnderWithoutTrailingSpace() {
        // The ender must actually be followed by whitespace; abbreviations and
        // decimals (no trailing space) must not capitalize the next letter.
        #expect(!AutoCapitalization.shouldCapitalize(context: "e."))
        #expect(!AutoCapitalization.shouldCapitalize(context: "e.g"))
        #expect(!AutoCapitalization.shouldCapitalize(context: "Mr."))
        #expect(!AutoCapitalization.shouldCapitalize(context: "3.14"))
    }

    @Test func capitalizeAfterCjkEnderWithoutSpace() {
        // CJK has no inter-sentence spaces, so the ender alone triggers.
        #expect(AutoCapitalization.shouldCapitalize(context: "你好。"))
        #expect(AutoCapitalization.shouldCapitalize(context: "什么！"))
        #expect(AutoCapitalization.shouldCapitalize(context: "吗？"))
    }

    // MARK: - shouldCapitalizeImmediately tests (pure logic)

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

    // MARK: - sentenceEnders and sentenceOpeners (pure constants)

    @Test func sentenceEndersContainsExpectedCharacters() {
        let expected: Set<Character> = [".", "!", "?", "…", "。", "！", "？"]
        #expect(AutoCapitalization.sentenceEnders == expected)
    }

    @Test func sentenceOpenersContainsExpectedCharacters() {
        let expected: Set<Character> = ["¿", "¡"]
        #expect(AutoCapitalization.sentenceOpeners == expected)
    }

    // MARK: - Integration tests (pipeline API)

    @Test func shiftedModeAutoTransitionsToMainAfterLetter() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // Switch to shifted
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)

        // Type a letter -- should auto-transition back to main and produce uppercase
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(vm.activeModeName == ModeNames.main)
        #expect(target.events.contains(.insertText("A")))
    }

    @Test func capsLockDoesNotAutoTransitionAfterLetter() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // Activate capsLock via double-tap shift
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)

        // Type a letter -- should stay in capsLock
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        #expect(target.events.contains(.insertText("A")))
    }

    @Test func switchToNumericMode() {
        let (vm, _) = makeViewModel(languageId: "de_DE")

        // Tap symbols key
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)
    }

    @Test func doubleTapShiftActivatesCapsLock() {
        let (vm, _) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)

        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
    }
}
