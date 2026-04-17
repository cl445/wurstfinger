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
