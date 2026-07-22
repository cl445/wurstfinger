//
//  LongPressNumberTests.swift
//  WurstfingerTests
//
//  Tests for the "type numbers by holding" feature.
//  A .longPress gesture on a letter key resolves to the digit that key
//  carries on the numeric layer (via GhostKeyResolver), and handleGesture
//  reports whether the press was handled so the recognizer only consumes
//  touches that actually dispatched an action.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - Definition Layer

struct LongPressBindingTests {
    @Test func numericLayerDigitsAreTapDigitsWithoutMirroredLongPress() {
        // The numeric layer no longer mirrors each digit `.tap` as an identical
        // `.longPress` binding: `GhostKeyResolver` surfaces the `.digit` tap to
        // a hold instead. Verify the digits are present as category `.digit`
        // taps and carry no explicit long-press binding.
        for mode in [NumericLayouts.phone(), NumericLayouts.classic()] {
            for slot in GridSlot.allSlots.flatMap(\.self) {
                let key = mode.key(for: slot)
                #expect(key?.bindings[.tap]?.category == .digit, "slot \(slot)")
                #expect(key?.bindings[.longPress] == nil, "slot \(slot)")
            }
            let zero = mode.key(for: GridSlot.zero)
            #expect(zero?.bindings[.tap]?.action == .commitText("0"))
            #expect(zero?.bindings[.tap]?.category == .digit)
            #expect(zero?.bindings[.longPress] == nil)
        }
    }

    @Test func spaceLongPressUsesNativeZeroOnArabicDefinition() throws {
        // The space-bar hold-for-zero must follow the layout's own digit set:
        // Arabic → ٠ (U+0660), not ASCII "0", in both the main and numeric mode.
        let def = try #require(KeyboardRegistry.load(id: "ar"))
        let mainSpace = def.modes[ModeNames.main]?.key(for: UtilitySlot.space)
        #expect(mainSpace?.bindings[.longPress]?.action == .commitText("٠"))
        let numericSpace = def.modes[ModeNames.numeric]?.key(for: UtilitySlot.space)
        #expect(numericSpace?.bindings[.longPress]?.action == .commitText("٠"))
    }

    @Test func spaceLongPressStaysAsciiZeroOnLatinDefinition() throws {
        // Regression guard: western layouts keep ASCII "0" on space-hold.
        let def = try #require(KeyboardRegistry.load(id: "de_DE"))
        let space = def.modes[ModeNames.main]?.key(for: UtilitySlot.space)
        #expect(space?.bindings[.longPress]?.action == .commitText("0"))
    }
}

// MARK: - Pipeline (gesture → digit)

@Suite(.serialized)
struct LongPressNumberPipelineTests {
    @Test func longPressOnLetterKeyTypesDigit() {
        let (vm, target) = makeViewModel()
        // Phone numpad (default): top-left slot carries "1".
        let handled = vm.handleGesture(.longPress, keyId: GridSlot.topLeft, isReturn: false)
        #expect(handled)
        #expect(target.events == [.insertText("1")])
    }

    @Test func allNineMainSlotsTypeTheirPhoneLayoutDigit() {
        let slots = GridSlot.allSlots.flatMap(\.self)
        for (index, slot) in slots.enumerated() {
            let (vm, target) = makeViewModel()
            vm.handleGesture(.longPress, keyId: slot, isReturn: false)
            #expect(target.events == [.insertText("\(index + 1)")], "slot \(slot)")
        }
    }

    @Test func longPressFollowsClassicNumpadStyle() {
        let defaults = InMemoryUserDefaults()
        defaults.set(NumpadStyle.classic.rawValue, forKey: SettingsKey.numpadStyle.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        let target = MockTextTarget()
        vm.bindTextInputTarget(target)
        vm.loadDefinition(for: "de_DE")

        vm.handleGesture(.longPress, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events == [.insertText("7")])
    }

    @Test func longPressWorksInShiftedMode() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
        vm.handleGesture(.longPress, keyId: GridSlot.center, isReturn: false)
        #expect(target.events.contains(.insertText("5")))
    }

    @Test func longPressOnDigitKeyInNumericModeTypesDigit() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)
        vm.handleGesture(.longPress, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events.contains(.insertText("1")))
    }

    @Test func longPressOnZeroKeyTypesZero() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        vm.handleGesture(.longPress, keyId: GridSlot.zero, isReturn: false)
        #expect(target.events.contains(.insertText("0")))
    }

    @Test func longPressOnSpaceBarTypesZero() {
        let (vm, target) = makeViewModel()
        let handled = vm.handleGesture(.longPress, keyId: UtilitySlot.space, isReturn: false)
        #expect(handled)
        #expect(target.events == [.insertText("0")])
    }

    @Test func longPressOnSpaceBarTypesZeroInNumericMode() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        vm.handleGesture(.longPress, keyId: UtilitySlot.space, isReturn: false)
        #expect(target.events.contains(.insertText("0")))
    }

    @Test func longPressOnSpaceBarTypesNativeZeroArabic() {
        let (vm, target) = makeViewModel(languageId: "ar")
        let handled = vm.handleGesture(.longPress, keyId: UtilitySlot.space, isReturn: false)
        #expect(handled)
        #expect(target.events == [.insertText("٠")])
    }

    @Test func longPressOnSpaceBarTypesNativeZeroInNumericModeArabic() {
        let (vm, target) = makeViewModel(languageId: "ar")
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)
        vm.handleGesture(.longPress, keyId: UtilitySlot.space, isReturn: false)
        #expect(target.events.contains(.insertText("٠")))
    }

    @Test func longPressOnDeleteReportsUnhandled() {
        let (vm, target) = makeViewModel()
        // Delete shares SlideGestureHandler with space but has no long-press
        // binding; the hold must not be consumed.
        let handled = vm.handleGesture(.longPress, keyId: UtilitySlot.delete, isReturn: false)
        #expect(!handled)
        #expect(target.events.isEmpty)
    }

    @Test func unhandledLongPressReportsFalseAndTypesNothing() {
        let (vm, target) = makeViewModel()
        // Utility keys have no digit on the numeric layer: the long press must
        // report unhandled so the touch is not consumed and the key keeps its
        // normal tap on release.
        let handled = vm.handleGesture(.longPress, keyId: UtilitySlot.return, isReturn: false)
        #expect(!handled)
        #expect(target.events.isEmpty)
    }

    @Test func handledGestureReportsTrue() {
        let (vm, _) = makeViewModel()
        #expect(vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false))
    }

    @Test func longPressOnLetterKeyTypesNativeDigitArabic() {
        // Regression lock for the removed numeric-layer `.longPress` mirror:
        // holding a letter key must still surface the layout's native digit via
        // GhostKeyResolver mapping the hold to the fallback `.digit` tap. Arabic
        // top-left carries ١ (Arabic-Indic 1).
        let (vm, target) = makeViewModel(languageId: "ar")
        let handled = vm.handleGesture(.longPress, keyId: GridSlot.topLeft, isReturn: false)
        #expect(handled)
        #expect(target.events == [.insertText("١")])
    }
}
