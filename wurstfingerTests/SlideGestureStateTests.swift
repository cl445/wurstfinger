//
//  SlideGestureStateTests.swift
//  WurstfingerTests
//
//  Tests for the SlideGestureState machine backing SlideGestureHandler:
//  tap/slide classification (including vertical drags) and recovery from
//  system touch cancellation. These need no SwiftUI rendering.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct SlideGestureStateTests {
    /// Space-bar activation threshold used throughout these tests.
    private let threshold = KeyboardConstants.SpaceGestures.dragActivationThreshold

    // MARK: - Basic classification

    @Test func firstChangeReportsTouchDown() {
        var state = SlideGestureState()
        let update = state.handleChanged(
            translation: CGSize(width: 1, height: 0), activationThreshold: threshold
        )
        #expect(update.isTouchDown)
        let second = state.handleChanged(
            translation: CGSize(width: 2, height: 0), activationThreshold: threshold
        )
        #expect(!second.isTouchDown)
    }

    @Test func smallMovementEndsAsTap() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: 2), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 2, height: 2), activationThreshold: threshold
        )
        #expect(phase == .tap)
    }

    @Test func horizontalDragBeyondThresholdSlides() {
        var state = SlideGestureState()
        let update = state.handleChanged(
            translation: CGSize(width: threshold + 4, height: 0),
            activationThreshold: threshold
        )
        // Anchored at the threshold crossing: the overshoot is reported
        // immediately instead of being dropped.
        #expect(update.phases == [.began, .changed(deltaX: 4)])
        let phase = state.handleEnded(
            translation: CGSize(width: threshold + 4, height: 0),
            activationThreshold: threshold
        )
        #expect(phase == .ended)
    }

    // MARK: - Vertical drags are not taps (Bug 2)

    @Test func verticalFlickIsNotATap() {
        var state = SlideGestureState()
        // 80 pt vertical flick with almost no horizontal travel: previously
        // classified as a tap (space inserted / character deleted).
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: 40), activationThreshold: threshold
        )
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: 80), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 2, height: 80), activationThreshold: threshold
        )
        #expect(phase == nil)
    }

    @Test func diagonalDisplacementBeyondThresholdIsNotATap() {
        var state = SlideGestureState()
        // Horizontal travel alone is under the threshold, but the total
        // displacement is not — this is a drag, not a tap.
        let translation = CGSize(width: threshold * 0.75, height: threshold * 0.75)
        _ = state.handleChanged(translation: translation, activationThreshold: threshold)
        let phase = state.handleEnded(translation: translation, activationThreshold: threshold)
        #expect(phase == nil)
    }

    // MARK: - Vertical up-swipes (label visibility toggles)

    /// Space-bar up-swipe classification threshold.
    private let upThreshold = KeyboardConstants.SpaceGestures.swipeUpActivationThreshold

    @Test func upSwipeBeyondThresholdClassifiesAsSwipeUp() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: -upThreshold), activationThreshold: threshold
        )
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: -upThreshold - 30), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 2, height: -upThreshold - 30), activationThreshold: threshold
        )
        #expect(phase == .swipeUp(isReturn: false))
    }

    @Test func upSwipeReturningToOriginClassifiesAsReturn() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 0, height: -upThreshold - 30), activationThreshold: threshold
        )
        _ = state.handleChanged(
            translation: CGSize(width: 0, height: -4), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 0, height: -4), activationThreshold: threshold
        )
        // Ends near the origin (below the tap threshold!) but the peak makes
        // it a return-up swipe, not a tap.
        #expect(phase == .swipeUp(isReturn: true))
    }

    @Test func upSwipeWithHorizontalDriftStaysAnUpSwipe() {
        var state = SlideGestureState()
        // A natural upward flick drifts sideways beyond the (small) slide
        // threshold. While the vertical axis dominates, the cursor slide must
        // not latch — previously this became a cursor slide and the toggle
        // never fired.
        let drift = threshold + 4
        let first = state.handleChanged(
            translation: CGSize(width: drift, height: -drift - 6), activationThreshold: threshold
        )
        #expect(first.phases.isEmpty)
        let second = state.handleChanged(
            translation: CGSize(width: drift, height: -upThreshold - 20),
            activationThreshold: threshold
        )
        #expect(second.phases.isEmpty)
        let phase = state.handleEnded(
            translation: CGSize(width: drift, height: -upThreshold - 20),
            activationThreshold: threshold
        )
        #expect(phase == .swipeUp(isReturn: false))
    }

    @Test func horizontalDominanceStillActivatesSlideAfterVerticalWobble() {
        var state = SlideGestureState()
        // Contact wobble where the vertical axis briefly dominates must not
        // block a genuine cursor slide once the horizontal axis takes over.
        let wobble = state.handleChanged(
            translation: CGSize(width: threshold, height: -threshold - 2),
            activationThreshold: threshold
        )
        #expect(wobble.phases.isEmpty)
        let sliding = state.handleChanged(
            translation: CGSize(width: threshold * 3, height: -threshold - 2),
            activationThreshold: threshold
        )
        #expect(sliding.phases.first == .began)
        let phase = state.handleEnded(
            translation: CGSize(width: threshold * 3, height: -threshold - 2),
            activationThreshold: threshold
        )
        #expect(phase == .ended)
    }

    @Test func returnUpSwipeOvershootingOriginIsStillAReturn() {
        var state = SlideGestureState()
        // Fast return swipes routinely overshoot past the starting point.
        // Measured as absolute distance from the origin this looked like a
        // plain up-swipe and toggled the wrong label group.
        _ = state.handleChanged(
            translation: CGSize(width: 0, height: -upThreshold - 10), activationThreshold: threshold
        )
        _ = state.handleChanged(
            translation: CGSize(width: 0, height: 20), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 0, height: 20), activationThreshold: threshold
        )
        #expect(phase == .swipeUp(isReturn: true))
    }

    @Test func upSwipeBelowThresholdIsIgnored() {
        var state = SlideGestureState()
        let translation = CGSize(width: 0, height: -upThreshold + 4)
        _ = state.handleChanged(translation: translation, activationThreshold: threshold)
        let phase = state.handleEnded(translation: translation, activationThreshold: threshold)
        #expect(phase == nil)
    }

    @Test func downwardSwipeIsIgnored() {
        var state = SlideGestureState()
        let translation = CGSize(width: 0, height: upThreshold + 30)
        _ = state.handleChanged(translation: translation, activationThreshold: threshold)
        let phase = state.handleEnded(translation: translation, activationThreshold: threshold)
        #expect(phase == nil)
    }

    @Test func upSwipeAfterHorizontalActivationEndsAsSlide() {
        var state = SlideGestureState()
        // Horizontal slide activates first, then the finger drifts far up:
        // the gesture stays a cursor slide, never a label toggle.
        _ = state.handleChanged(
            translation: CGSize(width: threshold + 4, height: 0), activationThreshold: threshold
        )
        _ = state.handleChanged(
            translation: CGSize(width: threshold + 4, height: -upThreshold - 30),
            activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: threshold + 4, height: -upThreshold - 30),
            activationThreshold: threshold
        )
        #expect(phase == .ended)
    }

    @Test func tapWithSmallVerticalJitterIsStillATap() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 1, height: -3), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 1, height: -3), activationThreshold: threshold
        )
        #expect(phase == .tap)
    }

    @Test func cancellationResetsVerticalTracking() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 0, height: -upThreshold - 70), activationThreshold: threshold
        )
        _ = state.handleCancelled()

        // Next touch: a small movement must be a tap — a stale upward peak
        // would classify it as a return-up swipe and toggle labels.
        _ = state.handleChanged(
            translation: CGSize(width: 1, height: -2), activationThreshold: threshold
        )
        let phase = state.handleEnded(
            translation: CGSize(width: 1, height: -2), activationThreshold: threshold
        )
        #expect(phase == .tap)
    }

    // MARK: - Touch cancellation (Bug 1)

    @Test func cancellationMidSlideReportsCancelled() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: threshold + 50, height: 0),
            activationThreshold: threshold
        )
        #expect(state.handleCancelled() == .cancelled)
    }

    @Test func cancellationBeforeSlideReportsCancelled() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 2, height: 0), activationThreshold: threshold
        )
        #expect(state.handleCancelled() == .cancelled)
    }

    @Test func cancellationWithoutTouchReportsNothing() {
        var state = SlideGestureState()
        #expect(state.handleCancelled() == nil)
    }

    @Test func sequenceAfterCancellationStartsFresh() {
        var state = SlideGestureState()
        // Drag far to the right, then get cancelled by the system.
        _ = state.handleChanged(
            translation: CGSize(width: 100, height: 0), activationThreshold: threshold
        )
        _ = state.handleCancelled()

        // Next touch: a small movement must be a fresh touch-down with no
        // phases — a stale anchor would replay a large negative delta here
        // (burst of deletions on the delete key, cursor jump on space).
        let update = state.handleChanged(
            translation: CGSize(width: 2, height: 0), activationThreshold: threshold
        )
        #expect(update.isTouchDown)
        #expect(update.phases.isEmpty)

        // And crossing the threshold anchors at the threshold, not at the
        // previous gesture's translation.
        let sliding = state.handleChanged(
            translation: CGSize(width: threshold + 2, height: 0),
            activationThreshold: threshold
        )
        #expect(sliding.phases == [.began, .changed(deltaX: 2)])
    }

    @Test func sequenceAfterNormalEndStartsFresh() {
        var state = SlideGestureState()
        _ = state.handleChanged(
            translation: CGSize(width: 100, height: 0), activationThreshold: threshold
        )
        _ = state.handleEnded(
            translation: CGSize(width: 100, height: 0), activationThreshold: threshold
        )

        let update = state.handleChanged(
            translation: CGSize(width: 2, height: 0), activationThreshold: threshold
        )
        #expect(update.isTouchDown)
        #expect(update.phases.isEmpty)
    }
}

// MARK: - ViewModel handling of .cancelled

@Suite(.serialized)
struct SlideCancellationPipelineTests {
    @Test func cancelledSpaceSlideResetsDragStateWithoutInput() throws {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        let spaceKey = try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.space))
        vm.handleSlide(spaceKey, phase: .began)
        #expect(vm.isSpaceDragging)
        vm.handleSlide(spaceKey, phase: .cancelled)
        #expect(!vm.isSpaceDragging)
        #expect(target.events.isEmpty)
    }

    @Test func cancelledDeleteSlideResetsDragStateWithoutInput() throws {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "hello"
        let deleteKey = try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.delete))
        vm.handleSlide(deleteKey, phase: .began)
        #expect(vm.isDeleteDragging)
        vm.handleSlide(deleteKey, phase: .cancelled)
        #expect(!vm.isDeleteDragging)
        #expect(target.events.isEmpty)
    }
}

// MARK: - Space-bar label visibility toggles (.swipeUp)

@Suite(.serialized)
struct SpaceLabelTogglePipelineTests {
    private func hides(_ vm: KeyboardViewModel, _ key: SettingsKey) -> Bool {
        vm.sharedDefaults.bool(forKey: key.rawValue)
    }

    @Test(arguments: [CursorMovementStyle.continuous, .discrete])
    func upSwipeTogglesExtraSymbolsWithoutTextInput(style: CursorMovementStyle) throws {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.sharedDefaults.set(style.rawValue, forKey: SettingsKey.cursorMovementStyle.rawValue)
        let spaceKey = try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.space))

        vm.handleSlide(spaceKey, phase: .swipeUp(isReturn: false))
        #expect(hides(vm, .hideExtraSymbols))
        // No space typed, no cursor movement.
        #expect(target.events.isEmpty)

        vm.handleSlide(spaceKey, phase: .swipeUp(isReturn: false))
        #expect(!hides(vm, .hideExtraSymbols))
        #expect(target.events.isEmpty)
        // Letter/standard visibility is untouched by the plain up-swipe.
        #expect(!hides(vm, .hideLetters))
        #expect(!hides(vm, .hideStandardSymbols))
    }

    /// Return-up group semantics: only when letters AND standard symbols are
    /// both hidden does the gesture show them again; any other combination
    /// hides both.
    @Test(arguments: [
        (letters: false, symbols: false, expected: true),
        (letters: true, symbols: false, expected: true),
        (letters: false, symbols: true, expected: true),
        (letters: true, symbols: true, expected: false),
    ])
    func returnUpSwipeTogglesLettersAndStandardSymbolsAsGroup(
        start: (letters: Bool, symbols: Bool, expected: Bool)
    ) throws {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.sharedDefaults.set(start.letters, forKey: SettingsKey.hideLetters.rawValue)
        vm.sharedDefaults.set(start.symbols, forKey: SettingsKey.hideStandardSymbols.rawValue)
        let spaceKey = try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.space))

        vm.handleSlide(spaceKey, phase: .swipeUp(isReturn: true))
        #expect(hides(vm, .hideLetters) == start.expected)
        #expect(hides(vm, .hideStandardSymbols) == start.expected)
        // Extra symbols belong to the plain up-swipe, not the return swipe.
        #expect(!hides(vm, .hideExtraSymbols))
        #expect(target.events.isEmpty)
    }

    @Test func upSwipeOnDeleteKeyIsIgnored() throws {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "hello"
        let deleteKey = try #require(vm.activeModeFromDefinition?.key(for: UtilitySlot.delete))

        vm.handleSlide(deleteKey, phase: .swipeUp(isReturn: false))
        vm.handleSlide(deleteKey, phase: .swipeUp(isReturn: true))
        #expect(target.events.isEmpty)
        #expect(!hides(vm, .hideLetters))
        #expect(!hides(vm, .hideStandardSymbols))
        #expect(!hides(vm, .hideExtraSymbols))
    }
}
