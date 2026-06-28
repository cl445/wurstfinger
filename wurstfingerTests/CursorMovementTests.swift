//
//  CursorMovementTests.swift
//  WurstfingerTests
//
//  Tests for discrete gesture classification and cursor movement via pipeline.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct DiscreteGestureClassificationTests {
    @Test func returnRatioBelowThresholdIsReturnSwipe() {
        // finalX near zero, maxDisplacement large -> return swipe
        let maxDisplacement: CGFloat = 50
        let finalX: CGFloat = 5
        let ratio = abs(finalX) / abs(maxDisplacement)
        #expect(ratio < KeyboardConstants.SpaceGestures.returnSwipeThreshold)
    }

    @Test func returnRatioAboveThresholdIsRegularSwipe() {
        // finalX close to maxDisplacement -> regular swipe
        let maxDisplacement: CGFloat = 50
        let finalX: CGFloat = 45
        let ratio = abs(finalX) / abs(maxDisplacement)
        #expect(ratio >= KeyboardConstants.SpaceGestures.returnSwipeThreshold)
    }

    @Test func returnSwipeThresholdIsReasonable() {
        let threshold = KeyboardConstants.SpaceGestures.returnSwipeThreshold
        #expect(threshold > 0)
        #expect(threshold < 1)
    }
}

@Suite(.serialized)
struct CursorMovementPipelineTests {
    @Test func spaceSlideMoveCursorForward() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
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

    @Test func spaceSlideMoveCursorBackward() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        guard let spaceKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            Issue.record("Space key not found in definition")
            return
        }
        vm.handleSlide(spaceKey, phase: .began)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(spaceKey, phase: .changed(deltaX: -step * 2))
        vm.handleSlide(spaceKey, phase: .ended)
        #expect(target.events.contains(.adjustCursor(-1)))
    }

    @Test func deleteSlideProducesDeletions() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
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
}

// MARK: - Discrete cursor movement (one swipe = char, return swipe = word)

@Suite(.serialized)
struct DiscreteCursorMovementTests {
    private func makeDiscreteViewModel() -> (KeyboardViewModel, MockTextTarget) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(
            CursorMovementStyle.discrete.rawValue,
            forKey: SettingsKey.cursorMovementStyle.rawValue
        )
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        let target = MockTextTarget()
        vm.bindTextInputTarget(target)
        vm.loadDefinition(for: "de_DE")
        return (vm, target)
    }

    private func spaceKey(_ vm: KeyboardViewModel) -> KeyConfig {
        guard let key = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            fatalError("Space key not found in definition")
        }
        return key
    }

    @Test func regularSwipeForwardMovesExactlyOneCharacter() {
        let (vm, target) = makeDiscreteViewModel()
        let key = spaceKey(vm)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        // Travels two full steps, but discrete moves a single character.
        vm.handleSlide(key, phase: .changed(deltaX: step * 2))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events == [.adjustCursor(1)])
    }

    @Test func regularSwipeBackwardMovesExactlyOneCharacter() {
        let (vm, target) = makeDiscreteViewModel()
        let key = spaceKey(vm)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -step * 2))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events == [.adjustCursor(-1)])
    }

    @Test func returnSwipeForwardMovesOneWord() {
        let (vm, target) = makeDiscreteViewModel()
        let key = spaceKey(vm)
        target.documentContextAfterInput = "foo bar"
        vm.handleSlide(key, phase: .began)
        // Out far, then back toward the origin → return swipe.
        vm.handleSlide(key, phase: .changed(deltaX: 40))
        vm.handleSlide(key, phase: .changed(deltaX: -36))
        vm.handleSlide(key, phase: .ended)
        // "foo" = 3 characters forward to the word boundary.
        #expect(target.events == [.adjustCursor(3)])
    }

    @Test func returnSwipeBackwardMovesOneWord() {
        let (vm, target) = makeDiscreteViewModel()
        let key = spaceKey(vm)
        target.documentContextBeforeInput = "hello world"
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -40))
        vm.handleSlide(key, phase: .changed(deltaX: 36))
        vm.handleSlide(key, phase: .ended)
        // "world" = 5 characters backward to the word boundary.
        #expect(target.events == [.adjustCursor(-5)])
    }

    @Test func tinyDragDoesNotMove() {
        let (vm, target) = makeDiscreteViewModel()
        let key = spaceKey(vm)
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: 3))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events.isEmpty)
    }

    @Test func forwardWordOffsetSkipsLeadingWhitespace() {
        #expect(KeyboardViewModel.forwardWordOffset(in: "  foo bar") == 5)
        #expect(KeyboardViewModel.forwardWordOffset(in: "foo") == 3)
        #expect(KeyboardViewModel.forwardWordOffset(in: "") == 0)
    }

    @Test func backwardWordOffsetSkipsTrailingWhitespace() {
        #expect(KeyboardViewModel.backwardWordOffset(in: "foo bar  ") == 5)
        #expect(KeyboardViewModel.backwardWordOffset(in: "foo") == 3)
        #expect(KeyboardViewModel.backwardWordOffset(in: "") == 0)
    }
}
