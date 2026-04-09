//
//  SlotFactoryShiftedTests.swift
//  WurstfingerTests
//
//  Tests for GridSlot, UtilitySlot, KeyConfig factories,
//  and shifted layer generation.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - GridSlot Tests

struct GridSlotTests {
    @Test func allSlotsContainsNineSlots() {
        let flat = GridSlot.allSlots.flatMap(\.self)
        #expect(flat.count == 9)
    }

    @Test func allSlotsHasThreeRows() {
        #expect(GridSlot.allSlots.count == 3)
        for row in GridSlot.allSlots {
            #expect(row.count == 3)
        }
    }

    @Test func allSlotsAreUnique() {
        let flat = GridSlot.allSlots.flatMap(\.self)
        #expect(Set(flat).count == 9)
    }

    @Test func slotNamesMatchAllSlots() {
        let expected: [[String]] = [
            [GridSlot.topLeft, GridSlot.topCenter, GridSlot.topRight],
            [GridSlot.midLeft, GridSlot.center, GridSlot.midRight],
            [GridSlot.bottomLeft, GridSlot.bottomCenter, GridSlot.bottomRight],
        ]
        #expect(GridSlot.allSlots == expected)
    }
}

// MARK: - UtilitySlot Tests

struct UtilitySlotTests {
    @Test func utilitySlotConstants() {
        #expect(UtilitySlot.globe == "globe")
        #expect(UtilitySlot.delete == "delete")
        #expect(UtilitySlot.return == "return")
        #expect(UtilitySlot.space == "space")
        #expect(UtilitySlot.symbols == "symbols")
    }

    @Test func utilitySlotNamesAreDistinct() {
        let names = [UtilitySlot.globe, UtilitySlot.delete, UtilitySlot.return, UtilitySlot.space, UtilitySlot.symbols]
        #expect(Set(names).count == 5)
    }
}

// MARK: - KeyConfig.letter() Tests

struct KeyConfigLetterFactoryTests {
    @Test func basicLetterKey() {
        let key = KeyConfig.letter("center", tap: "d", swipes: [.swipeUp: "g"])
        #expect(key.id == "center")
        #expect(key.style == .primary)
        #expect(key.swipeMode == .eightWay)
        #expect(key.slideType == .none)
        #expect(key.tapCycleActions == nil)

        // Tap binding
        let tap = key.bindings[.tap]
        #expect(tap?.label == "d")
        #expect(tap?.action == .commitText("d"))
        #expect(tap?.resolvedCategory == .letter)
        #expect(tap?.returnAction == nil)

        // Swipe binding
        let swipeUp = key.bindings[.swipeUp]
        #expect(swipeUp?.label == "g")
        #expect(swipeUp?.action == .commitText("g"))
        #expect(swipeUp?.returnAction == nil)
    }

    @Test func letterKeyWithReturnSwipes() {
        let key = KeyConfig.letter(
            "topLeft", tap: "a",
            swipes: [.swipeUp: "v", .swipeRight: "x"],
            returnSwipes: [.swipeUp: "1"]
        )
        // .tap has no returnAction
        #expect(key.bindings[.tap]?.returnAction == nil)
        // .swipeUp has returnAction "1"
        #expect(key.bindings[.swipeUp]?.returnAction == .commitText("1"))
        // .swipeRight has no returnAction (not in returnSwipes)
        #expect(key.bindings[.swipeRight]?.returnAction == nil)
    }

    @Test func letterKeyWithComposeSwipes() {
        let key = KeyConfig.letter(
            "center", tap: "d",
            composeSwipes: [.swipeDownLeft: (trigger: "¨", label: "¨")]
        )
        let compose = key.bindings[.swipeDownLeft]
        #expect(compose?.action == .compose(trigger: "¨"))
        #expect(compose?.label == "¨")
        #expect(compose?.resolvedCategory == .compose)
    }

    @Test func letterKeyOnlyContainsRequestedBindings() {
        let key = KeyConfig.letter("topLeft", tap: "a", swipes: [.swipeUp: "v"])
        #expect(key.bindings.count == 2) // tap + swipeUp
    }
}

// MARK: - KeyConfig.utility() Tests

struct KeyConfigUtilityFactoryTests {
    @Test func basicUtilityKey() {
        let key = KeyConfig.utility(
            "delete",
            label: "⌫",
            action: .deleteBackward,
            swipeMode: .twoWayHorizontal,
            slideType: .delete,
            accessibilityLabel: "Delete"
        )
        #expect(key.id == "delete")
        #expect(key.style == .utility)
        #expect(key.swipeMode == .twoWayHorizontal)
        #expect(key.slideType == .delete)

        let tap = key.bindings[.tap]
        #expect(tap?.label == "⌫")
        #expect(tap?.action == .deleteBackward)
        #expect(tap?.resolvedCategory == .utility)
        #expect(tap?.accessibilityLabel == "Delete")
    }

    @Test func utilityKeyDefaults() {
        let key = KeyConfig.utility("globe", label: "🌐", action: .advanceToNextInputMode)
        #expect(key.swipeMode == .none)
        #expect(key.slideType == .none)
        #expect(key.bindings.count == 1)
    }

    @Test func utilityKeyWithSwipes() {
        let swipeBinding = KeyBinding(
            label: "→", action: .moveCursor(offset: 1),
            category: .utility, returnAction: nil, accessibilityLabel: nil
        )
        let key = KeyConfig.utility(
            "delete",
            label: "⌫",
            action: .deleteBackward,
            swipes: [.swipeRight: swipeBinding]
        )
        #expect(key.bindings.count == 2)
        #expect(key.bindings[.swipeRight]?.action == .moveCursor(offset: 1))
    }
}

// MARK: - KeyConfig.autoShifted() Tests

struct AutoShiftedTests {
    @Test func autoShiftedGermanBasic() {
        let key = KeyConfig.letter("center", tap: "d", swipes: [.swipeUp: "g"])
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.id == "center")
        #expect(shifted.bindings[.tap]?.label == "D")
        #expect(shifted.bindings[.tap]?.action == .commitText("D"))
        #expect(shifted.bindings[.swipeUp]?.label == "G")
        #expect(shifted.bindings[.swipeUp]?.action == .commitText("G"))
    }

    @Test func autoShiftedGermanEszett() {
        let key = KeyConfig.letter("bottomLeft", tap: "ß")
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        // German ß uppercases to SS (or ẞ depending on locale data, but SS is the standard)
        let upper = "ß".uppercased(with: Locale(identifier: "de_DE"))
        #expect(shifted.bindings[.tap]?.label == upper)
        #expect(shifted.bindings[.tap]?.action == .commitText(upper))
    }

    @Test func autoShiftedTurkishI() {
        let key = KeyConfig.letter("center", tap: "i")
        let shifted = key.autoShifted(locale: Locale(identifier: "tr_TR"))

        #expect(shifted.bindings[.tap]?.label == "İ")
        #expect(shifted.bindings[.tap]?.action == .commitText("İ"))
    }

    @Test func autoShiftedPreservesNonLetterBindings() {
        let key = KeyConfig.letter(
            "center", tap: "d",
            composeSwipes: [.swipeDownLeft: (trigger: "¨", label: "¨")]
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        // Letter binding is shifted
        #expect(shifted.bindings[.tap]?.label == "D")
        // Compose binding is unchanged
        #expect(shifted.bindings[.swipeDownLeft]?.action == .compose(trigger: "¨"))
        #expect(shifted.bindings[.swipeDownLeft]?.label == "¨")
    }

    @Test func autoShiftedPreservesReturnAction() {
        let key = KeyConfig.letter(
            "topLeft", tap: "a",
            swipes: [.swipeUp: "v"],
            returnSwipes: [.swipeUp: "1"]
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.swipeUp]?.returnAction == .commitText("1"))
    }

    @Test func autoShiftedPreservesKeyProperties() {
        let key = KeyConfig.letter("center", tap: "d")
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.swipeMode == key.swipeMode)
        #expect(shifted.slideType == key.slideType)
        #expect(shifted.style == key.style)
        #expect(shifted.tapCycleActions == key.tapCycleActions)
    }

    @Test func autoShiftedUtilityKeyUnchanged() {
        let key = KeyConfig.utility("delete", label: "⌫", action: .deleteBackward)
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == "⌫")
        #expect(shifted.bindings[.tap]?.action == .deleteBackward)
    }
}

// MARK: - KeyboardMode.generateShifted() Tests

struct GenerateShiftedTests {
    private static func sampleMode() -> KeyboardMode {
        let keys: [String: KeyConfig] = [
            "a": KeyConfig.letter("a", tap: "a", swipes: [.swipeUp: "v"]),
            "b": KeyConfig.letter("b", tap: "b"),
            "shift": KeyConfig.utility("shift", label: "⇧", action: .switchMode(ModeNames.shifted)),
        ]
        let arrangement = GridArrangement(columns: 3, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b"), KeyPlacement(keyId: "shift")],
        ])
        return KeyboardMode(
            name: ModeNames.main, keys: keys,
            arrangements: [.portrait: arrangement],
            autoTransitions: [:], doubleTapMode: nil
        )
    }

    @Test func generateShiftedBasic() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.name == ModeNames.shifted)
        #expect(shifted.keys["a"]?.bindings[.tap]?.label == "A")
        #expect(shifted.keys["a"]?.bindings[.swipeUp]?.label == "V")
        #expect(shifted.keys["b"]?.bindings[.tap]?.label == "B")
    }

    @Test func generateShiftedReusesArrangements() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.arrangements == main.arrangements)
    }

    @Test func generateShiftedWithOverrides() {
        let main = Self.sampleMode()
        let overrideKey = KeyConfig.letter("a", tap: "Ä")
        let shifted = main.generateShifted(
            locale: Locale(identifier: "de_DE"),
            overrides: ["a": overrideKey]
        )

        // Override takes effect
        #expect(shifted.keys["a"]?.bindings[.tap]?.label == "Ä")
        // Non-overridden key is auto-shifted
        #expect(shifted.keys["b"]?.bindings[.tap]?.label == "B")
    }

    @Test func generateShiftedUtilityKeysUnchanged() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.keys["shift"]?.bindings[.tap]?.label == "⇧")
        #expect(shifted.keys["shift"]?.bindings[.tap]?.action == .switchMode(ModeNames.shifted))
    }

    @Test func generateShiftedDefaultTransitions() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))

        // Default: empty autoTransitions (stays active like caps lock)
        #expect(shifted.autoTransitions.isEmpty)
        #expect(shifted.doubleTapMode == nil)
    }

    @Test func generateShiftedWithPostConfiguration() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))
            .with(autoTransitions: [.letter: ModeNames.main], doubleTapMode: ModeNames.capsLock)

        #expect(shifted.autoTransitions[.letter] == ModeNames.main)
        #expect(shifted.doubleTapMode == ModeNames.capsLock)
    }

    @Test func generateShiftedPreservesKeyCount() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.keys.count == main.keys.count)
    }

    @Test func generateShiftedEmptyKeysProducesEmptyShifted() {
        let arrangement = GridArrangement(columns: 1, rows: [])
        let emptyMode = KeyboardMode(
            name: ModeNames.main, keys: [:],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:], doubleTapMode: nil
        )
        let shifted = emptyMode.generateShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.keys.isEmpty)
        #expect(shifted.name == ModeNames.shifted)
    }

    @Test func generateShiftedAllOverridden() {
        let main = Self.sampleMode()
        let overrides: [String: KeyConfig] = [
            "a": KeyConfig.letter("a", tap: "Ä"),
            "b": KeyConfig.letter("b", tap: "Ö"),
            "shift": KeyConfig.utility("shift", label: "⇪", action: .switchMode(ModeNames.capsLock)),
        ]
        let shifted = main.generateShifted(
            locale: Locale(identifier: "de_DE"),
            overrides: overrides
        )

        #expect(shifted.keys["a"]?.bindings[.tap]?.label == "Ä")
        #expect(shifted.keys["b"]?.bindings[.tap]?.label == "Ö")
        #expect(shifted.keys["shift"]?.bindings[.tap]?.label == "⇪")
    }
}

// MARK: - Additional GridSlot Tests

extension GridSlotTests {
    @Test func individualSlotStringValues() {
        #expect(GridSlot.topLeft == "topLeft")
        #expect(GridSlot.topCenter == "topCenter")
        #expect(GridSlot.topRight == "topRight")
        #expect(GridSlot.midLeft == "midLeft")
        #expect(GridSlot.center == "center")
        #expect(GridSlot.midRight == "midRight")
        #expect(GridSlot.bottomLeft == "bottomLeft")
        #expect(GridSlot.bottomCenter == "bottomCenter")
        #expect(GridSlot.bottomRight == "bottomRight")
    }

    @Test func allSlotsRowOrdering() {
        // First row is top, last row is bottom
        #expect(GridSlot.allSlots[0].contains(GridSlot.topLeft))
        #expect(GridSlot.allSlots[0].contains(GridSlot.topCenter))
        #expect(GridSlot.allSlots[0].contains(GridSlot.topRight))
        #expect(GridSlot.allSlots[2].contains(GridSlot.bottomLeft))
        #expect(GridSlot.allSlots[2].contains(GridSlot.bottomCenter))
        #expect(GridSlot.allSlots[2].contains(GridSlot.bottomRight))
    }
}

// MARK: - Additional KeyConfig.letter() Tests

extension KeyConfigLetterFactoryTests {
    @Test func letterKeyNoSwipesHasOnlyTapBinding() {
        let key = KeyConfig.letter("center", tap: "d")
        #expect(key.bindings.count == 1)
        #expect(key.bindings[.tap] != nil)
    }

    @Test func letterKeyTapHasNilExplicitCategory() {
        let key = KeyConfig.letter("center", tap: "d")
        // category is stored as nil; resolvedCategory is auto-derived
        #expect(key.bindings[.tap]?.category == nil)
        #expect(key.bindings[.tap]?.resolvedCategory == .letter)
    }

    @Test func letterKeySwipeHasNilExplicitCategory() {
        let key = KeyConfig.letter("center", tap: "d", swipes: [.swipeUp: "g"])
        // Swipe bindings also store nil category; resolvedCategory is auto-derived
        #expect(key.bindings[.swipeUp]?.category == nil)
        #expect(key.bindings[.swipeUp]?.resolvedCategory == .letter)
    }
}

// MARK: - Additional KeyConfig.utility() Tests

extension KeyConfigUtilityFactoryTests {
    @Test func utilityKeyTapCycleActionsIsNil() {
        let key = KeyConfig.utility("delete", label: "⌫", action: .deleteBackward)
        #expect(key.tapCycleActions == nil)
    }

    @Test func utilityKeyTapReturnActionIsNil() {
        let key = KeyConfig.utility("return", label: "↵", action: .newline)
        #expect(key.bindings[.tap]?.returnAction == nil)
    }

    @Test func utilityKeyNilAccessibilityLabelByDefault() {
        let key = KeyConfig.utility("globe", label: "🌐", action: .advanceToNextInputMode)
        #expect(key.bindings[.tap]?.accessibilityLabel == nil)
    }
}

// MARK: - Additional autoShifted() Tests

extension AutoShiftedTests {
    @Test func autoShiftedIsIdempotentOnAlreadyUppercase() {
        let key = KeyConfig.letter("center", tap: "D")
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == "D")
        #expect(shifted.bindings[.tap]?.action == .commitText("D"))
    }

    @Test func autoShiftedPreservesAccessibilityLabelOnLetterBinding() {
        // Build a letter key manually so we can set accessibilityLabel
        let binding = KeyBinding(
            label: "a", action: .commitText("a"),
            category: nil, returnAction: nil, accessibilityLabel: "Buchstabe A"
        )
        let key = KeyConfig(
            id: "center", bindings: [.tap: binding],
            swipeMode: .eightWay, slideType: .none, style: .primary, tapCycleActions: nil
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == "A")
        #expect(shifted.bindings[.tap]?.accessibilityLabel == "Buchstabe A")
    }

    @Test func autoShiftedDoesNotShiftDigitBindings() {
        let digitBinding = KeyBinding(
            label: "1", action: .commitText("1"),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        let key = KeyConfig(
            id: "topLeft", bindings: [.tap: digitBinding],
            swipeMode: .eightWay, slideType: .none, style: .primary, tapCycleActions: nil
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        // Digit bindings must remain unchanged
        #expect(shifted.bindings[.tap]?.label == "1")
        #expect(shifted.bindings[.tap]?.action == .commitText("1"))
    }

    @Test func autoShiftedDoesNotShiftSymbolBindings() {
        let symbolBinding = KeyBinding(
            label: ".", action: .commitText("."),
            category: .symbol, returnAction: nil, accessibilityLabel: nil
        )
        let key = KeyConfig(
            id: "topRight", bindings: [.tap: symbolBinding],
            swipeMode: .eightWay, slideType: .none, style: .primary, tapCycleActions: nil
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == ".")
        #expect(shifted.bindings[.tap]?.action == .commitText("."))
    }

    @Test func autoShiftedMixedBindingsOnlyShiftsLetters() {
        // Letter tap + digit swipe + symbol swipe
        let letterBinding = KeyBinding(
            label: "a", action: .commitText("a"),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        let digitBinding = KeyBinding(
            label: "1", action: .commitText("1"),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        let symbolBinding = KeyBinding(
            label: "!", action: .commitText("!"),
            category: .symbol, returnAction: nil, accessibilityLabel: nil
        )
        let key = KeyConfig(
            id: "center",
            bindings: [.tap: letterBinding, .swipeUp: digitBinding, .swipeDown: symbolBinding],
            swipeMode: .eightWay, slideType: .none, style: .primary, tapCycleActions: nil
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == "A")      // letter → shifted
        #expect(shifted.bindings[.swipeUp]?.label == "1")  // digit → unchanged
        #expect(shifted.bindings[.swipeDown]?.label == "!") // symbol → unchanged
    }
}