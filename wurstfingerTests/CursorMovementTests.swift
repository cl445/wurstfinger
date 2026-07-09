//
//  CursorMovementTests.swift
//  WurstfingerTests
//
//  Tests for discrete gesture classification and cursor movement via pipeline.
//

import Foundation
import Testing
@testable import WurstfingerApp

// Note: a `DiscreteGestureClassificationTests` suite used to live here. Its
// tests recomputed the production return-ratio formula inside the test (or
// asserted a constant lies in (0, 1)), so they could never catch a
// classification regression. The actual return-vs-regular swipe behavior is
// exercised end-to-end by `DiscreteCursorMovementTests` below (review L20).

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

    @Test func continuousSlideForwardCrossesWholeEmojiCluster() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        // 👍🏽 = thumbs up + skin-tone modifier = 4 UTF-16 code units.
        target.documentContextAfterInput = "👍🏽x"
        guard let spaceKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            Issue.record("Space key not found in definition")
            return
        }
        vm.handleSlide(spaceKey, phase: .began)
        vm.handleSlide(spaceKey, phase: .changed(deltaX: KeyboardConstants.SpaceGestures.dragStep))
        vm.handleSlide(spaceKey, phase: .ended)
        // One step must cross the whole cluster, not get stuck inside it.
        #expect(target.events == [.adjustCursor(4)])
        #expect(target.documentContextAfterInput == "x")
    }

    @Test func continuousSlideBackwardCrossesWholeEmojiCluster() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "x👍"
        guard let spaceKey = vm.activeModeFromDefinition?.key(for: UtilitySlot.space) else {
            Issue.record("Space key not found in definition")
            return
        }
        vm.handleSlide(spaceKey, phase: .began)
        vm.handleSlide(spaceKey, phase: .changed(deltaX: -KeyboardConstants.SpaceGestures.dragStep))
        vm.handleSlide(spaceKey, phase: .ended)
        // 👍 is a surrogate pair = 2 UTF-16 code units.
        #expect(target.events == [.adjustCursor(-2)])
        #expect(target.documentContextBeforeInput == "x")
    }
}

// MARK: - Discrete cursor movement (one swipe = char, return swipe = word)

@Suite(.serialized)
struct DiscreteCursorMovementTests {
    private func makeDiscreteViewModel() -> (KeyboardViewModel, MockTextTarget) {
        let defaults = InMemoryUserDefaults()
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

    private func spaceKey(_ vm: KeyboardViewModel) throws -> KeyConfig {
        try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.space))
    }

    @Test func regularSwipeForwardMovesExactlyOneCharacter() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        // Travels two full steps, but discrete moves a single character.
        vm.handleSlide(key, phase: .changed(deltaX: step * 2))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events == [.adjustCursor(1)])
    }

    @Test func regularSwipeBackwardMovesExactlyOneCharacter() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -step * 2))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events == [.adjustCursor(-1)])
    }

    @Test func returnSwipeForwardMovesOneWord() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextAfterInput = "foo bar"
        vm.handleSlide(key, phase: .began)
        // Out far, then back toward the origin → return swipe.
        vm.handleSlide(key, phase: .changed(deltaX: 40))
        vm.handleSlide(key, phase: .changed(deltaX: -36))
        vm.handleSlide(key, phase: .ended)
        // "foo" = 3 characters forward to the word boundary.
        #expect(target.events == [.adjustCursor(3)])
    }

    @Test func returnSwipeBackwardMovesOneWord() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextBeforeInput = "hello world"
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -40))
        vm.handleSlide(key, phase: .changed(deltaX: 36))
        vm.handleSlide(key, phase: .ended)
        // "world" = 5 characters backward to the word boundary.
        #expect(target.events == [.adjustCursor(-5)])
    }

    @Test func tinyDragDoesNotMove() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: KeyboardConstants.SpaceGestures.dragStep / 2))
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

    // MARK: - UTF-16 offsets for emoji and surrogate pairs

    @Test func forwardWordOffsetCountsUTF16UnitsForEmoji() {
        // 👍 = surrogate pair = 2 UTF-16 units; leading space adds 1.
        #expect(KeyboardViewModel.forwardWordOffset(in: " 👍 bar") == 3)
        // 👍🏽 = thumbs up + skin-tone modifier = 4 units.
        #expect(KeyboardViewModel.forwardWordOffset(in: "👍🏽 bar") == 4)
        // 👨‍👩‍👧‍👦 = ZWJ family sequence = 11 units.
        #expect(KeyboardViewModel.forwardWordOffset(in: "👨‍👩‍👧‍👦 x") == 11)
    }

    @Test func backwardWordOffsetCountsUTF16UnitsForEmoji() {
        #expect(KeyboardViewModel.backwardWordOffset(in: "bar 👍 ") == 3)
        #expect(KeyboardViewModel.backwardWordOffset(in: "foo 👍🏽") == 4)
        #expect(KeyboardViewModel.backwardWordOffset(in: "x 👨‍👩‍👧‍👦") == 11)
    }

    @Test func returnSwipeForwardAcrossEmojiLandsOnClusterBoundary() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextAfterInput = "👍🏽 bar"
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: 40))
        vm.handleSlide(key, phase: .changed(deltaX: -36))
        vm.handleSlide(key, phase: .ended)
        // Word jump must cover the emoji's full 4 UTF-16 units.
        #expect(target.events == [.adjustCursor(4)])
        #expect(target.documentContextBeforeInput == "👍🏽")
        #expect(target.documentContextAfterInput == " bar")
    }

    @Test func returnSwipeBackwardAcrossEmojiLandsOnClusterBoundary() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextBeforeInput = "foo 👍🏽"
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -40))
        vm.handleSlide(key, phase: .changed(deltaX: 36))
        vm.handleSlide(key, phase: .ended)
        #expect(target.events == [.adjustCursor(-4)])
        #expect(target.documentContextBeforeInput == "foo ")
        #expect(target.documentContextAfterInput == "👍🏽")
    }

    @Test func regularSwipeForwardCrossesWholeEmojiCluster() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextAfterInput = "👍 bar"
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: step * 2))
        vm.handleSlide(key, phase: .ended)
        // One discrete step = one grapheme = 2 UTF-16 units for 👍.
        #expect(target.events == [.adjustCursor(2)])
        #expect(target.documentContextAfterInput == " bar")
    }

    @Test func regularSwipeBackwardCrossesZWJSequence() throws {
        let (vm, target) = makeDiscreteViewModel()
        let key = try spaceKey(vm)
        target.documentContextBeforeInput = "x👨‍👩‍👧‍👦"
        let step = KeyboardConstants.SpaceGestures.dragStep
        vm.handleSlide(key, phase: .began)
        vm.handleSlide(key, phase: .changed(deltaX: -step * 2))
        vm.handleSlide(key, phase: .ended)
        // The whole family emoji (11 UTF-16 units) is a single step.
        #expect(target.events == [.adjustCursor(-11)])
        #expect(target.documentContextBeforeInput == "x")
    }
}
