//
//  LabelCategoryTests.swift
//  wurstfingerTests
//
//  Covers the label-visibility classification: character classification,
//  binding → display-category mapping, and the per-category visibility rule.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct LabelCategoryTests {
    private func binding(_ label: String, _ action: KeyAction, category: KeyCategory? = nil) -> KeyBinding {
        KeyBinding(label: label, action: action, category: category, returnAction: nil, accessibilityLabel: nil)
    }

    // MARK: - classify(_:)

    @Test func classifyRecognisesLetters() {
        #expect(LabelCategory.classify("a") == .letter)
        #expect(LabelCategory.classify("ä") == .letter)
        #expect(LabelCategory.classify("ß") == .letter)
    }

    @Test func classifyRecognisesDigits() {
        #expect(LabelCategory.classify("5") == .number)
    }

    @Test func classifyRecognisesStandardSymbols() {
        for symbol in [".", ",", "!", "?", "@", "%", "€", "("] {
            #expect(LabelCategory.classify(symbol) == .standardSymbol, "\(symbol) should be a standard symbol")
        }
    }

    @Test func classifyTreatsRareSymbolsAsExtra() {
        for symbol in ["$", "^", "#", "\\", "{", "~", "<", "|"] {
            #expect(LabelCategory.classify(symbol) == .extraSymbol, "\(symbol) should be an extra symbol")
        }
    }

    @Test func classifyEmptyStringIsExtra() {
        #expect(LabelCategory.classify("") == .extraSymbol)
    }

    // MARK: - of(_ binding:)

    @Test func mapsTextBindingsByCharacter() {
        #expect(LabelCategory.of(binding("a", .commitText("a"))) == .letter)
        #expect(LabelCategory.of(binding("5", .commitText("5"))) == .number)
        #expect(LabelCategory.of(binding(".", .commitText("."))) == .standardSymbol)
        #expect(LabelCategory.of(binding("$", .commitText("$"))) == .extraSymbol)
    }

    @Test func mapsControlKeysToFunctional() {
        #expect(LabelCategory.of(binding("", .switchMode("symbols"))) == .functional) // modifier
        #expect(LabelCategory.of(binding("⌫", .deleteBackward)) == .functional) // utility
        #expect(LabelCategory.of(binding(" ", .space)) == .functional) // whitespace
        // Compose/accent triggers stay visible like other control keys.
        #expect(LabelCategory.of(binding("´", .compose(trigger: "´"))) == .functional)
    }

    // MARK: - isVisible(...)

    @Test func eachHideableCategoryTogglesIndependently() {
        #expect(LabelCategory.letter.isVisible(hideLetters: false, hideStandardSymbols: true, hideExtraSymbols: true))
        #expect(!LabelCategory.letter.isVisible(hideLetters: true, hideStandardSymbols: false, hideExtraSymbols: false))

        #expect(LabelCategory.standardSymbol.isVisible(hideLetters: true, hideStandardSymbols: false, hideExtraSymbols: true))
        #expect(!LabelCategory.standardSymbol.isVisible(hideLetters: false, hideStandardSymbols: true, hideExtraSymbols: false))

        #expect(LabelCategory.extraSymbol.isVisible(hideLetters: true, hideStandardSymbols: true, hideExtraSymbols: false))
        #expect(!LabelCategory.extraSymbol.isVisible(hideLetters: false, hideStandardSymbols: false, hideExtraSymbols: true))
    }

    @Test func numbersAndFunctionalAreAlwaysVisible() {
        #expect(LabelCategory.number.isVisible(hideLetters: true, hideStandardSymbols: true, hideExtraSymbols: true))
        #expect(LabelCategory.functional.isVisible(hideLetters: true, hideStandardSymbols: true, hideExtraSymbols: true))
    }
}
