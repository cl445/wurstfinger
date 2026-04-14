//
//  ViewModelPipelineTests.swift
//  WurstfingerTests
//
//  End-to-end tests for the gesture → resolver → pipeline → text flow.
//  Each test constructs a real KeyboardViewModel with a real
//  KeyboardDefinition and a mock TextInputTarget, then exercises
//  handleGesture/handleSlide to verify observable side effects.
//

import Foundation
import Testing
@testable import WurstfingerApp

// Helpers (MockTextTarget, makeViewModel) are in TestHelpers.swift

// MARK: - Tap → commitText

@Suite(.serialized)
struct ViewModelTapTests {
    @Test func tapCenterKeyCommitsText() {
        let (vm, target) = makeViewModel()
        // German layout: top-left key center tap → "a"
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events.contains(.insertText("a")))
    }

    @Test func tapCenterMiddleCommitsText() {
        let (vm, target) = makeViewModel()
        // German: center key center tap → "d"
        vm.handleGesture(.tap, keyId: GridSlot.center, isReturn: false)
        #expect(target.events.contains(.insertText("d")))
    }

    @Test func tapSpaceKeyCommitsSpace() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.space, isReturn: false)
        #expect(target.events.contains(.insertText(" ")))
    }

    @Test func tapDeleteKeyDeletesBackward() {
        let (vm, target) = makeViewModel()
        target.documentContextBeforeInput = "x"
        vm.handleGesture(.tap, keyId: UtilitySlot.delete, isReturn: false)
        #expect(target.events.contains(.deleteBackward))
    }

    @Test func tapReturnKeyCommitsNewline() {
        let (vm, target) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.return, isReturn: false)
        #expect(target.events.contains(.insertText("\n")))
    }
}

// MARK: - Swipe → correct character

@Suite(.serialized)
struct ViewModelSwipeTests {
    @Test func swipeDownRightFromTopLeftCommitsV() {
        let (vm, target) = makeViewModel()
        // German: top-left key, swipe down-right → "v"
        vm.handleGesture(.swipeDownRight, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events.contains(.insertText("v")))
    }

    @Test func swipeUpFromCenterCommitsU() {
        let (vm, target) = makeViewModel()
        // German: center key, swipe up → "u"
        vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: false)
        #expect(target.events.contains(.insertText("u")))
    }

    @Test func swipeDownFromTopLeftCommitsAUmlaut() {
        let (vm, target) = makeViewModel()
        // German: top-left key, swipe down → "ä"
        vm.handleGesture(.swipeDown, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events.contains(.insertText("ä")))
    }
}

// MARK: - Return swipe → returnAction

@Suite(.serialized)
struct ViewModelReturnSwipeTests {
    @Test func returnSwipeExecutesReturnAction() {
        // topLeft swipeRight: normal → "-", return → "÷"
        let (normalVM, normalTarget) = makeViewModel()
        normalVM.handleGesture(.swipeRight, keyId: GridSlot.topLeft, isReturn: false)

        let (returnVM, returnTarget) = makeViewModel()
        returnVM.handleGesture(.swipeRight, keyId: GridSlot.topLeft, isReturn: true)

        #expect(normalTarget.events.contains(.insertText("-")))
        #expect(returnTarget.events.contains(.insertText("÷")))
    }
}

// MARK: - Mode switching (shift)

@Suite(.serialized)
struct ViewModelModeTests {
    @Test func switchModeToShifted() {
        let (vm, _) = makeViewModel()
        #expect(vm.activeModeName == ModeNames.main)
        // Shift is swipeUp on midRight key
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
    }

    @Test func shiftedModeAutoTransitionsBackAfterLetter() {
        let (vm, target) = makeViewModel()
        // Switch to shifted
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
        // Type a letter — should auto-transition back to main
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(vm.activeModeName == ModeNames.main)
        // The committed text should be uppercase
        #expect(target.events.contains(.insertText("A")))
    }

    @Test func shiftWhileShiftedActivatesCapsLock() {
        let (vm, _) = makeViewModel()
        // First shift → shifted
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
        // Second shift while shifted → capsLock (direct switchMode)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
    }

    @Test func capsLockSwipeUpStaysInCapsLock() {
        let (vm, _) = makeViewModel()
        // Activate capsLock
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        // Third swipe up — stays in capsLock (no-op)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
    }

    @Test func capsLockSwipeDownGoesToMain() {
        let (vm, _) = makeViewModel()
        // Activate capsLock
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        // Swipe down → back to main
        vm.handleGesture(.swipeDown, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.main)
    }

    @Test func capsLockStaysAfterLetter() {
        let (vm, target) = makeViewModel()
        // Activate capsLock
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        // Type a letter — should stay in capsLock
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        #expect(target.events.contains(.insertText("A")))
    }

    @Test func switchToNumeric() {
        let (vm, _) = makeViewModel()
        // Tap symbols key → numeric mode
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)
    }

    @Test func shiftLabelChangesPerMode() throws {
        let (vm, _) = makeViewModel()

        // Main mode: midRight swipeUp label = "⇧"
        let mainMode = try #require(vm.activeModeFromDefinition)
        let mainMidRight = try #require(mainMode.keys[GridSlot.midRight])
        #expect(mainMidRight.bindings[.swipeUp]?.label == "⇧")

        // Shifted mode: midRight swipeUp label = "⇧"
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
        let shiftedMode = try #require(vm.activeModeFromDefinition)
        let shiftedMidRight = try #require(shiftedMode.keys[GridSlot.midRight])
        #expect(shiftedMidRight.bindings[.swipeUp]?.label == "⇧")

        // CapsLock mode: midRight swipeUp label = "⇪"
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.capsLock)
        let capsMode = try #require(vm.activeModeFromDefinition)
        let capsMidRight = try #require(capsMode.keys[GridSlot.midRight])
        #expect(capsMidRight.bindings[.swipeUp]?.label == "⇪")
    }

    @Test func shiftDownHiddenInMainVisibleInShiftedAndCapsLock() throws {
        let (vm, _) = makeViewModel()

        // Main mode: midRight swipeDown is removed (only shown in shifted/capsLock)
        let mainMode = try #require(vm.activeModeFromDefinition)
        let mainMidRight = try #require(mainMode.keys[GridSlot.midRight])
        #expect(mainMidRight.bindings[.swipeDown] == nil)

        // Shifted mode: swipeDown "⇩" is visible
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        let shiftedMode = try #require(vm.activeModeFromDefinition)
        let shiftedMidRight = try #require(shiftedMode.keys[GridSlot.midRight])
        #expect(shiftedMidRight.bindings[.swipeDown]?.label == "⇩")

        // CapsLock mode: swipeDown "⇩" is visible
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        let capsMode = try #require(vm.activeModeFromDefinition)
        let capsMidRight = try #require(capsMode.keys[GridSlot.midRight])
        #expect(capsMidRight.bindings[.swipeDown]?.label == "⇩")
    }
}

// MARK: - Slide gestures

@Suite(.serialized)
struct ViewModelSlideTests {
    @Test func spaceSlideTapCommitsSpace() {
        let (vm, target) = makeViewModel()
        // Use the actual space key from the definition
        guard let spaceKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            Issue.record("Space key not found in definition")
            return
        }
        vm.handleSlide(spaceKey, phase: .tap)
        #expect(target.events.contains(.insertText(" ")))
    }

    @Test func deleteSlideProducesDeletions() {
        let (vm, target) = makeViewModel()
        target.documentContextBeforeInput = "hello"
        guard let deleteKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.delete) else {
            Issue.record("Delete key not found in definition")
            return
        }
        vm.handleSlide(deleteKey, phase: .began)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(deleteKey, phase: .changed(deltaX: -step * 2))
        vm.handleSlide(deleteKey, phase: .ended)
        #expect(target.events.contains(.deleteBackward))
    }

    @Test func spaceSlideMoveCursor() {
        let (vm, target) = makeViewModel()
        guard let spaceKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            Issue.record("Space key not found in definition")
            return
        }
        vm.handleSlide(spaceKey, phase: .began)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(spaceKey, phase: .changed(deltaX: step * 2))
        vm.handleSlide(spaceKey, phase: .ended)
        #expect(target.events.contains(.adjustCursor(1)))
    }
}

// MARK: - Definition loading

struct ViewModelDefinitionTests {
    @Test func loadDefinitionSetsActiveMode() {
        let (vm, _) = makeViewModel()
        #expect(vm.activeModeName == ModeNames.main)
        #expect(vm.currentDefinition != nil)
        #expect(vm.activeModeFromDefinition != nil)
    }

    @Test func loadDefinitionSetsArrangement() {
        let (vm, _) = makeViewModel()
        #expect(vm.currentArrangement != nil)
    }

    @Test func unknownLanguageIdDoesNotCrash() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        vm.loadDefinition(for: "nonexistent_XX")
        #expect(vm.currentDefinition == nil)
        #expect(vm.activeModeFromDefinition == nil)
    }

    @Test func allLanguagesLoadSuccessfully() {
        for info in KeyboardRegistry.available {
            let definition = KeyboardRegistry.load(id: info.id)
            #expect(definition != nil, "Failed to load \(info.id)")
        }
    }
}

// MARK: - ViewControllerActionMiddleware integration

@Suite(.serialized)
struct ViewModelVCActionTests {
    @Test func advanceToNextInputModeCallsClosure() {
        var advanceCalled = false
        let (vm, _) = makeViewModel(
            advanceToNextInputMode: { advanceCalled = true }
        )
        vm.handleGesture(.tap, keyId: UtilitySlot.globe, isReturn: false)
        #expect(advanceCalled)
    }
}
