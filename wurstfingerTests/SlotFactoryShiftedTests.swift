//
//  SlotFactoryShiftedTests.swift
//  WurstfingerTests
//
//  Tests for GridSlot, UtilitySlot, KeyDefinition factories,
//  and shifted mode generation.
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

// MARK: - KeyDefinition.letter() Tests

struct KeyDefinitionLetterFactoryTests {
    @Test func basicLetterKey() {
        let key = KeyDefinition.letter("center", tap: "d", swipes: [.swipeUp: "g"])
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
        let key = KeyDefinition.letter(
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
        let key = KeyDefinition.letter(
            "center", tap: "d",
            composeSwipes: [.swipeDownLeft: (trigger: "¨", label: "¨")]
        )
        let compose = key.bindings[.swipeDownLeft]
        #expect(compose?.action == .compose(trigger: "¨"))
        #expect(compose?.label == "¨")
        #expect(compose?.resolvedCategory == .compose)
    }

    @Test func letterKeyOnlyContainsRequestedBindings() {
        let key = KeyDefinition.letter("topLeft", tap: "a", swipes: [.swipeUp: "v"])
        #expect(key.bindings.count == 2) // tap + swipeUp
    }
}

// MARK: - KeyDefinition.utility() Tests

struct KeyDefinitionUtilityFactoryTests {
    @Test func basicUtilityKey() {
        let key = KeyDefinition.utility(
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
        let key = KeyDefinition.utility("globe", label: "🌐", action: .advanceToNextInputMode)
        #expect(key.swipeMode == .none)
        #expect(key.slideType == .none)
        #expect(key.bindings.count == 1)
    }

    @Test func utilityKeyWithSwipes() {
        let swipeBinding = KeyBinding(
            label: "→", action: .moveCursor(offset: 1),
            category: .utility, returnAction: nil, accessibilityLabel: nil
        )
        let key = KeyDefinition.utility(
            "delete",
            label: "⌫",
            action: .deleteBackward,
            swipes: [.swipeRight: swipeBinding]
        )
        #expect(key.bindings.count == 2)
        #expect(key.bindings[.swipeRight]?.action == .moveCursor(offset: 1))
    }
}

// MARK: - KeyDefinition.autoShifted() Tests

struct AutoShiftedTests {
    @Test func autoShiftedUsesCommittedTextNotLabel() {
        // Label and committed text differ — shifted must uppercase each independently
        let key = KeyDefinition(
            id: "test",
            bindings: [
                .tap: KeyBinding(
                    label: "display",
                    action: .commitText("payload"),
                    category: .letter,
                    returnAction: nil,
                    accessibilityLabel: nil
                ),
            ],
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "en_US"))
        #expect(shifted.bindings[.tap]?.label == "DISPLAY")
        #expect(shifted.bindings[.tap]?.action == .commitText("PAYLOAD"))
    }

    @Test func autoShiftedGermanBasic() {
        let key = KeyDefinition.letter("center", tap: "d", swipes: [.swipeUp: "g"])
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.id == "center")
        #expect(shifted.bindings[.tap]?.label == "D")
        #expect(shifted.bindings[.tap]?.action == .commitText("D"))
        #expect(shifted.bindings[.swipeUp]?.label == "G")
        #expect(shifted.bindings[.swipeUp]?.action == .commitText("G"))
    }

    @Test func autoShiftedGermanEszett() {
        let key = KeyDefinition.letter("bottomLeft", tap: "ß")
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        // German ß maps to the capital sharp S ẞ (U+1E9E), not the two-letter "SS".
        #expect(shifted.bindings[.tap]?.label == "ẞ")
        #expect(shifted.bindings[.tap]?.action == .commitText("ẞ"))
    }

    @Test func autoShiftedTurkishI() {
        let key = KeyDefinition.letter("center", tap: "i")
        let shifted = key.autoShifted(locale: Locale(identifier: "tr_TR"))

        #expect(shifted.bindings[.tap]?.label == "İ")
        #expect(shifted.bindings[.tap]?.action == .commitText("İ"))
    }

    @Test func autoShiftedPreservesNonLetterBindings() {
        let key = KeyDefinition.letter(
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
        let key = KeyDefinition.letter(
            "topLeft", tap: "a",
            swipes: [.swipeUp: "v"],
            returnSwipes: [.swipeUp: "1"]
        )
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.swipeUp]?.returnAction == .commitText("1"))
    }

    @Test func autoShiftedPreservesKeyProperties() {
        let key = KeyDefinition.letter("center", tap: "d")
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.swipeMode == key.swipeMode)
        #expect(shifted.slideType == key.slideType)
        #expect(shifted.style == key.style)
        #expect(shifted.tapCycleActions == key.tapCycleActions)
    }

    @Test func autoShiftedUtilityKeyUnchanged() {
        let key = KeyDefinition.utility("delete", label: "⌫", action: .deleteBackward)
        let shifted = key.autoShifted(locale: Locale(identifier: "de_DE"))

        #expect(shifted.bindings[.tap]?.label == "⌫")
        #expect(shifted.bindings[.tap]?.action == .deleteBackward)
    }
}

// MARK: - KeyboardMode.generateShifted() Tests

struct GenerateShiftedTests {
    private static func sampleMode() -> KeyboardMode {
        let keys: [String: KeyDefinition] = [
            "a": KeyDefinition.letter("a", tap: "a", swipes: [.swipeUp: "v"]),
            "b": KeyDefinition.letter("b", tap: "b"),
            "shift": KeyDefinition.utility("shift", label: "⇧", action: .switchMode(ModeNames.shifted)),
        ]
        let arrangement = GridArrangement(columns: 3, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b"), KeyPlacement(keyId: "shift")],
        ])
        return KeyboardMode(
            name: ModeNames.main, keys: keys,
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
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
        let overrideKey = KeyDefinition.letter("a", tap: "Ä")
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
    }

    @Test func generateShiftedWithPostConfiguration() {
        let main = Self.sampleMode()
        let shifted = main.generateShifted(locale: Locale(identifier: "de_DE"))
            .with(autoTransitions: [.letter: ModeNames.main])

        #expect(shifted.autoTransitions[.letter] == ModeNames.main)
    }
}
