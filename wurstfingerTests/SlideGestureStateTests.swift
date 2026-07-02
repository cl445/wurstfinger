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
