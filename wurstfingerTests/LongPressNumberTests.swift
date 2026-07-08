//
//  LongPressNumberTests.swift
//  WurstfingerTests
//
//  Tests for the MessagEase-style "type numbers by holding" feature.
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
    @Test func numericLayerExposesDigitsAsLongPress() {
        for mode in [NumericLayouts.phone(), NumericLayouts.classic()] {
            for slot in GridSlot.allSlots.flatMap(\.self) {
                let key = mode.key(for: slot)
                #expect(key?.bindings[.longPress] != nil, "slot \(slot)")
                #expect(key?.bindings[.longPress] == key?.bindings[.tap], "slot \(slot)")
            }
            #expect(mode.key(for: GridSlot.zero)?.bindings[.longPress]?.action == .commitText("0"))
        }
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
}
