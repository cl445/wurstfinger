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

    // MARK: - Engagement outside the pipeline (textDidChange / appearance)

    /// View model with the user's auto-capitalize setting enabled, as wired
    /// by `KeyboardViewController` in production.
    private func makeAutoCapViewModel() -> (KeyboardViewModel, MockTextTarget) {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.sharedDefaults.set(true, forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        return (vm, target)
    }

    @Test func refreshEngagesShiftInEmptyField() {
        let (vm, target) = makeAutoCapViewModel()
        target.documentContextBeforeInput = nil

        // Simulates textDidChange / keyboard appearance in an empty field.
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.shifted)
    }

    @Test func refreshEngagesShiftAfterSentenceEnderAndSpace() {
        let (vm, target) = makeAutoCapViewModel()
        target.documentContextBeforeInput = "Hello. "

        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.shifted)
    }

    @Test func refreshReleasesStaleShiftWhenCaretMovesMidSentence() {
        let (vm, target) = makeAutoCapViewModel()
        target.documentContextBeforeInput = nil
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.shifted)

        // Caret relocated into the middle of a word (host-side change).
        target.documentContextBeforeInput = "Hello wor"
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.main)
    }

    @Test func refreshDoesNothingWhenUserSettingDisabled() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = nil

        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.main)
    }

    @Test func refreshIsIdempotentWhenAlreadyShifted() {
        let (vm, target) = makeAutoCapViewModel()
        target.documentContextBeforeInput = ""

        vm.refreshAutoCapitalization()
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.shifted)
    }

    @Test func refreshDoesNotReleaseManuallyTappedShift() {
        let (vm, target) = makeAutoCapViewModel()
        // Mid-sentence context: auto-capitalization evaluates to false.
        target.documentContextBeforeInput = "Hello wor"

        // User taps shift to type a proper noun mid-sentence…
        vm.switchToMode(ModeNames.shifted)
        // …then the host fires textDidChange (e.g. caret bookkeeping).
        vm.refreshAutoCapitalization()

        #expect(
            vm.activeModeName == ModeNames.shifted,
            "A manual shift must survive out-of-pipeline refreshes"
        )
    }

    @Test func refreshStillReleasesAutoEngagedShiftAfterManualCheck() {
        let (vm, target) = makeAutoCapViewModel()
        // Auto-engage in an empty field, then the caret moves mid-sentence:
        // the auto-engaged shift is stale and must be released.
        target.documentContextBeforeInput = nil
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.shifted)

        target.documentContextBeforeInput = "Hello wor"
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.main)
    }

    // MARK: - Engagement through the pipeline (key actions)

    @Test func middlewareEngagesShiftAfterSentenceEnderFromMain() {
        let (vm, target) = makeAutoCapViewModel()
        target.documentContextBeforeInput = "Hello"

        vm.dispatchAction(.commitText(". "))
        #expect(vm.activeModeName == ModeNames.shifted)
    }

    @Test func capsLockSurvivesSentenceEnder() {
        let (vm, target) = makeAutoCapViewModel()

        // Activate capsLock via double-tap shift.
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)

        // Typing "HELLO. " must not demote capsLock to shifted.
        vm.dispatchAction(.commitText("HELLO. "))
        #expect(vm.activeModeName == ModeNames.capsLock)
        #expect(target.events.contains(.insertText("HELLO. ")))
    }

    @Test func capsLockNotDemotedByRefresh() {
        let (vm, target) = makeAutoCapViewModel()

        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)

        // Neither an engage (empty field) nor a release (mid-word) context
        // may change the user's explicit capsLock.
        target.documentContextBeforeInput = nil
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.capsLock)

        target.documentContextBeforeInput = "Hello wor"
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.capsLock)
    }

    @Test func numericLayerStaysOnSentenceEnder() {
        let (vm, target) = makeAutoCapViewModel()

        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)

        // Typing ". " on the numeric layer must not teleport to shifted.
        vm.dispatchAction(.commitText(". "))
        #expect(vm.activeModeName == ModeNames.numeric)

        // A host-side refresh must not either.
        target.documentContextBeforeInput = "Hello. "
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.numeric)
    }

    // MARK: - Definition-level enablement

    @Test func definitionWithoutAutoCapitalizeDisablesEngagement() throws {
        let (vm, target) = makeAutoCapViewModel()
        let base = try #require(vm.currentDefinition)
        vm.currentDefinition = KeyboardDefinition(
            title: base.title,
            id: base.id,
            localeIdentifier: base.localeIdentifier,
            modes: base.modes,
            defaultMode: base.defaultMode,
            settings: KeyboardDefinitionSettings(
                autoCapitalize: false,
                composeRuleOverrides: base.settings.composeRuleOverrides,
                inputMethod: base.settings.inputMethod
            ),
            numericBackToAlphaLabel: base.numericBackToAlphaLabel
        )

        // User setting is on, but the definition opts out entirely.
        target.documentContextBeforeInput = nil
        vm.refreshAutoCapitalization()
        #expect(vm.activeModeName == ModeNames.main)

        vm.dispatchAction(.commitText("Hello. "))
        #expect(vm.activeModeName == ModeNames.main)
    }
}
