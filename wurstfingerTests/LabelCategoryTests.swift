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
        // The accent-cycle key is a control and stays visible.
        #expect(LabelCategory.of(binding("\u{1F152}", .cycleAccents)) == .functional)
    }

    @Test func composeTriggersHideLikeSymbols() {
        // Compose triggers read as symbols on the key face, so they follow the
        // symbol toggles instead of staying pinned like control keys.
        for trigger in ["´", "^", "~", "¨", "$"] {
            #expect(
                LabelCategory.of(binding(trigger, .compose(trigger: trigger))) == .extraSymbol,
                "\(trigger) should hide with extra symbols"
            )
        }
        // The grave trigger ˋ (U+02CB, a modifier *letter* per Unicode) is
        // displayed as "`" on the key face — classify by the shipped label.
        #expect(LabelCategory.of(binding("`", .compose(trigger: "ˋ"))) == .extraSymbol)
        #expect(LabelCategory.of(binding("°", .compose(trigger: "°"))) == .standardSymbol)
        #expect(LabelCategory.of(binding("*", .compose(trigger: "*"))) == .standardSymbol)
    }

    @Test func hidingEverythingLeavesOnlyControlLabelsOnLetterGrid() throws {
        // With all three toggles on, the letter grid of the German layout must
        // show only the accent-cycle key and the shift modifier; the utility
        // column is not part of this rule and stays untouched.
        let definition = KeyboardRegistry.load(id: "de_DE")
        let mode = try #require(definition?.modes[ModeNames.main])

        var visibleLabels: Set<String> = []
        for slotRow in GridSlot.allSlots {
            for slot in slotRow {
                guard let key = mode.keys[slot] else { continue }
                for (_, keyBinding) in key.bindings where !keyBinding.label.isEmpty {
                    let category = LabelCategory.of(keyBinding)
                    if category.isVisible(
                        areLetterLabelsHidden: true,
                        areStandardSymbolLabelsHidden: true,
                        areExtraSymbolLabelsHidden: true
                    ) {
                        visibleLabels.insert(keyBinding.label)
                    }
                }
            }
        }

        #expect(
            visibleLabels == ["\u{1F152}", "⇧"],
            "Unexpected labels survive hide-all: \(visibleLabels.sorted())"
        )
    }

    // MARK: - isVisible(...)

    @Test func eachHideableCategoryTogglesIndependently() {
        #expect(LabelCategory.letter.isVisible(
            areLetterLabelsHidden: false,
            areStandardSymbolLabelsHidden: true,
            areExtraSymbolLabelsHidden: true
        ))
        #expect(!LabelCategory.letter.isVisible(
            areLetterLabelsHidden: true,
            areStandardSymbolLabelsHidden: false,
            areExtraSymbolLabelsHidden: false
        ))

        #expect(LabelCategory.standardSymbol.isVisible(
            areLetterLabelsHidden: true,
            areStandardSymbolLabelsHidden: false,
            areExtraSymbolLabelsHidden: true
        ))
        #expect(!LabelCategory.standardSymbol.isVisible(
            areLetterLabelsHidden: false,
            areStandardSymbolLabelsHidden: true,
            areExtraSymbolLabelsHidden: false
        ))

        #expect(LabelCategory.extraSymbol.isVisible(
            areLetterLabelsHidden: true,
            areStandardSymbolLabelsHidden: true,
            areExtraSymbolLabelsHidden: false
        ))
        #expect(!LabelCategory.extraSymbol.isVisible(
            areLetterLabelsHidden: false,
            areStandardSymbolLabelsHidden: false,
            areExtraSymbolLabelsHidden: true
        ))
    }

    @Test func numbersAndFunctionalAreAlwaysVisible() {
        #expect(LabelCategory.number.isVisible(
            areLetterLabelsHidden: true,
            areStandardSymbolLabelsHidden: true,
            areExtraSymbolLabelsHidden: true
        ))
        #expect(LabelCategory.functional.isVisible(
            areLetterLabelsHidden: true,
            areStandardSymbolLabelsHidden: true,
            areExtraSymbolLabelsHidden: true
        ))
    }
}
