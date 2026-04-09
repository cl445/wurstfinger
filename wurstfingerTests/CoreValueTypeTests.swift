//
//  CoreValueTypeTests.swift
//  WurstfingerTests
//
//  Tests for the core value types: KeyAction, KeyCategory, GestureType,
//  SwipeMode, SlideType, KeyStyle, KeyBinding, KeyConfig.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - KeyAction Tests

struct KeyActionTests {
    @Test func codableRoundtripCommitText() throws {
        let action = KeyAction.commitText("a")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyAction.self, from: data)
        #expect(decoded == action)
    }

    @Test func codableRoundtripCompose() throws {
        let action = KeyAction.compose(trigger: "¨")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyAction.self, from: data)
        #expect(decoded == action)
    }

    @Test func codableRoundtripSwitchMode() throws {
        let action = KeyAction.switchMode("shifted")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyAction.self, from: data)
        #expect(decoded == action)
    }

    @Test func codableRoundtripMoveCursor() throws {
        let action = KeyAction.moveCursor(offset: -3)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyAction.self, from: data)
        #expect(decoded == action)
    }

    @Test func codableRoundtripSimpleCases() throws {
        let cases: [KeyAction] = [
            .cycleAccents, .capitalizeWord(uppercased: true), .capitalizeWord(uppercased: false),
            .advanceToNextInputMode, .dismissKeyboard,
            .deleteBackward, .deleteForward,
            .space, .newline,
            .copy, .paste, .cut, .none,
        ]
        for action in cases {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(KeyAction.self, from: data)
            #expect(decoded == action)
        }
    }

    @Test func equatable() {
        #expect(KeyAction.commitText("a") == KeyAction.commitText("a"))
        #expect(KeyAction.commitText("a") != KeyAction.commitText("b"))
        #expect(KeyAction.space == KeyAction.space)
        #expect(KeyAction.space != KeyAction.newline)
        #expect(KeyAction.switchMode("shifted") == KeyAction.switchMode("shifted"))
        #expect(KeyAction.switchMode("shifted") != KeyAction.switchMode("numeric"))
    }
}

// MARK: - KeyCategory / inferredCategory Tests

struct KeyCategoryTests {
    @Test func letterInference() {
        #expect(KeyAction.commitText("a").inferredCategory == .letter)
        #expect(KeyAction.commitText("Z").inferredCategory == .letter)
        #expect(KeyAction.commitText("ß").inferredCategory == .letter)
        #expect(KeyAction.commitText("é").inferredCategory == .letter)
        #expect(KeyAction.commitText("ñ").inferredCategory == .letter)
    }

    @Test func digitInference() {
        #expect(KeyAction.commitText("0").inferredCategory == .digit)
        #expect(KeyAction.commitText("9").inferredCategory == .digit)
    }

    @Test func symbolInference() {
        #expect(KeyAction.commitText(".").inferredCategory == .symbol)
        #expect(KeyAction.commitText(",").inferredCategory == .symbol)
        #expect(KeyAction.commitText("!").inferredCategory == .symbol)
        #expect(KeyAction.commitText("@").inferredCategory == .symbol)
    }

    @Test func emptyTextInference() {
        #expect(KeyAction.commitText("").inferredCategory == .symbol)
    }

    @Test func composeInference() {
        #expect(KeyAction.compose(trigger: "¨").inferredCategory == .compose)
        #expect(KeyAction.cycleAccents.inferredCategory == .compose)
    }

    @Test func modifierInference() {
        #expect(KeyAction.switchMode("shifted").inferredCategory == .modifier)
        #expect(KeyAction.capitalizeWord(uppercased: true).inferredCategory == .modifier)
    }

    @Test func whitespaceInference() {
        #expect(KeyAction.space.inferredCategory == .whitespace)
        #expect(KeyAction.newline.inferredCategory == .whitespace)
    }

    @Test func utilityInference() {
        #expect(KeyAction.deleteBackward.inferredCategory == .utility)
        #expect(KeyAction.deleteForward.inferredCategory == .utility)
        #expect(KeyAction.moveCursor(offset: 1).inferredCategory == .utility)
        #expect(KeyAction.advanceToNextInputMode.inferredCategory == .utility)
        #expect(KeyAction.dismissKeyboard.inferredCategory == .utility)
        #expect(KeyAction.copy.inferredCategory == .utility)
        #expect(KeyAction.paste.inferredCategory == .utility)
        #expect(KeyAction.cut.inferredCategory == .utility)
        #expect(KeyAction.none.inferredCategory == .utility)
    }

    @Test func keyCategoryCodable() throws {
        for category in [KeyCategory.letter, .digit, .symbol, .compose, .modifier, .utility, .whitespace] {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(KeyCategory.self, from: data)
            #expect(decoded == category)
        }
    }
}

// MARK: - GestureType Tests

struct GestureTypeTests {
    @Test func isSwipe() {
        let swipes: [GestureType] = [
            .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
            .swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight,
        ]
        for gesture in swipes {
            #expect(gesture.isSwipe, "Expected \(gesture) to be a swipe")
        }

        let nonSwipes: [GestureType] = [.tap, .circularClockwise, .circularCounterclockwise, .longPress]
        for gesture in nonSwipes {
            #expect(!gesture.isSwipe, "Expected \(gesture) not to be a swipe")
        }
    }

    @Test func caseIterable() {
        #expect(GestureType.allCases.count == 12)
    }

    @Test func codableRoundtrip() throws {
        for gesture in GestureType.allCases {
            let data = try JSONEncoder().encode(gesture)
            let decoded = try JSONDecoder().decode(GestureType.self, from: data)
            #expect(decoded == gesture)
        }
    }
}

// MARK: - SwipeMode Tests

struct SwipeModeTests {
    @Test func eightWayAllowsAllSwipes() {
        let swipes: [GestureType] = [
            .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
            .swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight,
        ]
        for gesture in swipes {
            #expect(SwipeMode.eightWay.allows(gesture), "eightWay should allow \(gesture)")
        }
    }

    @Test func eightWayRejectsNonSwipes() {
        #expect(!SwipeMode.eightWay.allows(.tap))
        #expect(!SwipeMode.eightWay.allows(.circularClockwise))
        #expect(!SwipeMode.eightWay.allows(.longPress))
    }

    @Test func fourWayCrossAllowsOnlyCardinals() {
        #expect(SwipeMode.fourWayCross.allows(.swipeUp))
        #expect(SwipeMode.fourWayCross.allows(.swipeDown))
        #expect(SwipeMode.fourWayCross.allows(.swipeLeft))
        #expect(SwipeMode.fourWayCross.allows(.swipeRight))
        #expect(!SwipeMode.fourWayCross.allows(.swipeUpLeft))
        #expect(!SwipeMode.fourWayCross.allows(.swipeDownRight))
    }

    @Test func fourWayDiagonalAllowsOnlyDiagonals() {
        #expect(SwipeMode.fourWayDiagonal.allows(.swipeUpLeft))
        #expect(SwipeMode.fourWayDiagonal.allows(.swipeUpRight))
        #expect(SwipeMode.fourWayDiagonal.allows(.swipeDownLeft))
        #expect(SwipeMode.fourWayDiagonal.allows(.swipeDownRight))
        #expect(!SwipeMode.fourWayDiagonal.allows(.swipeUp))
        #expect(!SwipeMode.fourWayDiagonal.allows(.swipeLeft))
    }

    @Test func twoWayHorizontal() {
        #expect(SwipeMode.twoWayHorizontal.allows(.swipeLeft))
        #expect(SwipeMode.twoWayHorizontal.allows(.swipeRight))
        #expect(!SwipeMode.twoWayHorizontal.allows(.swipeUp))
        #expect(!SwipeMode.twoWayHorizontal.allows(.swipeDown))
        #expect(!SwipeMode.twoWayHorizontal.allows(.swipeUpLeft))
    }

    @Test func twoWayVertical() {
        #expect(SwipeMode.twoWayVertical.allows(.swipeUp))
        #expect(SwipeMode.twoWayVertical.allows(.swipeDown))
        #expect(!SwipeMode.twoWayVertical.allows(.swipeLeft))
        #expect(!SwipeMode.twoWayVertical.allows(.swipeRight))
    }

    @Test func noneRejectsEverything() {
        for gesture in GestureType.allCases {
            #expect(!SwipeMode.none.allows(gesture), "none should reject \(gesture)")
        }
    }
}

// MARK: - KeyBinding Tests

struct KeyBindingTests {
    @Test func resolvedCategoryAutoDerivesFromAction() {
        let binding = KeyBinding(
            label: "a", action: .commitText("a"),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        #expect(binding.resolvedCategory == .letter)
    }

    @Test func resolvedCategoryPrefersExplicitCategory() {
        // "ß" would infer .letter, but we can override to .symbol for testing
        let binding = KeyBinding(
            label: "ß", action: .commitText("ß"),
            category: .symbol, returnAction: nil, accessibilityLabel: nil
        )
        #expect(binding.resolvedCategory == .symbol)
    }

    @Test func resolvedCategoryExplicitLetterForEdgeCase() {
        // Explicit .letter for a character that might be ambiguous
        let binding = KeyBinding(
            label: "ℝ", action: .commitText("ℝ"),
            category: .letter, returnAction: nil, accessibilityLabel: nil
        )
        #expect(binding.resolvedCategory == .letter)
    }

    @Test func codableRoundtrip() throws {
        let binding = KeyBinding(
            label: "a", action: .commitText("a"),
            category: nil, returnAction: .commitText("1"),
            accessibilityLabel: "Letter A"
        )
        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(KeyBinding.self, from: data)
        #expect(decoded == binding)
    }

    @Test func codableRoundtripWithNilOptionalFields() throws {
        let binding = KeyBinding(
            label: "⌫", action: .deleteBackward,
            category: .utility, returnAction: nil,
            accessibilityLabel: nil
        )
        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(KeyBinding.self, from: data)
        #expect(decoded == binding)
    }
}

// MARK: - KeyConfig Tests

struct KeyConfigTests {
    @Test func identifiable() {
        let config = KeyConfig(
            id: "topLeft",
            bindings: [
                .tap: KeyBinding(
                    label: "a", action: .commitText("a"),
                    category: nil, returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
        #expect(config.id == "topLeft")
    }

    @Test func codableRoundtrip() throws {
        let config = KeyConfig(
            id: "center",
            bindings: [
                .tap: KeyBinding(
                    label: "d", action: .commitText("d"),
                    category: nil, returnAction: nil, accessibilityLabel: nil
                ),
                .swipeUp: KeyBinding(
                    label: "g", action: .commitText("g"),
                    category: nil, returnAction: .commitText("5"),
                    accessibilityLabel: nil
                ),
            ],
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeyConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test func codableRoundtripWithTapCycleActions() throws {
        let config = KeyConfig(
            id: "space",
            bindings: [
                .tap: KeyBinding(
                    label: "␣", action: .space,
                    category: nil, returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .none,
            slideType: .moveCursor,
            style: .spacebar,
            tapCycleActions: [.space, .commitText(","), .commitText(".")]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeyConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test func codableRoundtripUtilityKey() throws {
        let config = KeyConfig(
            id: "delete",
            bindings: [
                .tap: KeyBinding(
                    label: "⌫", action: .deleteBackward,
                    category: .utility, returnAction: nil,
                    accessibilityLabel: "Löschen"
                ),
            ],
            swipeMode: .twoWayHorizontal,
            slideType: .delete,
            style: .utility,
            tapCycleActions: nil
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeyConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test func equatable() {
        let binding = KeyBinding(
            label: "a", action: .commitText("a"),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        let config1 = KeyConfig(
            id: "topLeft", bindings: [.tap: binding],
            swipeMode: .eightWay, slideType: .none,
            style: .primary, tapCycleActions: nil
        )
        let config2 = KeyConfig(
            id: "topLeft", bindings: [.tap: binding],
            swipeMode: .eightWay, slideType: .none,
            style: .primary, tapCycleActions: nil
        )
        let config3 = KeyConfig(
            id: "topRight", bindings: [.tap: binding],
            swipeMode: .eightWay, slideType: .none,
            style: .primary, tapCycleActions: nil
        )
        #expect(config1 == config2)
        #expect(config1 != config3)
    }
}

// MARK: - Exhaustive Enum Codable Roundtrips

struct EnumCodableTests {
    @Test func swipeModeAllCases() throws {
        for mode in [SwipeMode.eightWay, .fourWayCross, .fourWayDiagonal, .twoWayHorizontal, .twoWayVertical, .none] {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SwipeMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test func slideTypeAllCases() throws {
        for slide in [SlideType.none, .moveCursor, .delete] {
            let data = try JSONEncoder().encode(slide)
            let decoded = try JSONDecoder().decode(SlideType.self, from: data)
            #expect(decoded == slide)
        }
    }

    @Test func keyStyleAllCases() throws {
        for style in [KeyStyle.primary, .secondary, .utility, .spacebar, .accent] {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(KeyStyle.self, from: data)
            #expect(decoded == style)
        }
    }
}
