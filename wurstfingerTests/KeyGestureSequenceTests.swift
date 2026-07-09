//
//  KeyGestureSequenceTests.swift
//  WurstfingerTests
//
//  Tests for KeyGestureSequence, the touch-sequence state machine backing
//  KeyGestureRecognizer: touch-down detection and recovery from system
//  touch cancellation. These need no SwiftUI rendering.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct KeyGestureSequenceTests {
    /// Feeds a horizontal rightward drag into the sequence.
    private func feedRightwardSwipe(into sequence: inout KeyGestureSequence) {
        for x in stride(from: 10, through: 60, by: 10) {
            _ = sequence.handleChanged(translation: CGSize(width: CGFloat(x), height: 0))
        }
    }

    @Test func firstChangeReportsTouchDown() {
        var sequence = KeyGestureSequence()
        let first = sequence.handleChanged(translation: CGSize(width: 1, height: 0))
        let second = sequence.handleChanged(translation: CGSize(width: 2, height: 0))
        #expect(first)
        #expect(!second)
        #expect(sequence.isTracking)
    }

    @Test func endedSwipeClassifiesAndClears() {
        var sequence = KeyGestureSequence()
        feedRightwardSwipe(into: &sequence)
        let classification = sequence.handleEnded(
            translation: CGSize(width: 60, height: 0), aspectRatio: 1.0
        )
        #expect(classification.gesture == .swipeRight)
        #expect(!sequence.isTracking)
    }

    @Test func cancellationClearsSequence() {
        var sequence = KeyGestureSequence()
        feedRightwardSwipe(into: &sequence)
        #expect(sequence.isTracking)
        sequence.handleCancelled()
        #expect(!sequence.isTracking)
    }

    @Test func touchAfterCancellationIsANewTouchDown() {
        var sequence = KeyGestureSequence()
        feedRightwardSwipe(into: &sequence)
        sequence.handleCancelled()
        // Without the reset, the next touch would skip touch-down handling
        // (no haptic feedback) because samples were still buffered.
        let isTouchDown = sequence.handleChanged(translation: CGSize(width: 1, height: 0))
        #expect(isTouchDown)
    }

    @Test func maxDisplacementTracksPeakDistanceFromOrigin() {
        var sequence = KeyGestureSequence()
        _ = sequence.handleChanged(translation: CGSize(width: 30, height: 40)) // 50pt out …
        _ = sequence.handleChanged(translation: CGSize(width: 3, height: 4)) // … then back
        // The running maximum must survive the return leg — a pending long
        // press stays cancelled after an out-and-back movement.
        #expect(sequence.maxDisplacement == 50)
    }

    @Test func maxDisplacementResetsAfterEnd() {
        var sequence = KeyGestureSequence()
        feedRightwardSwipe(into: &sequence)
        _ = sequence.handleEnded(translation: CGSize(width: 60, height: 0), aspectRatio: 1.0)
        #expect(sequence.maxDisplacement == 0)
    }

    @Test func maxDisplacementResetsAfterCancellation() {
        var sequence = KeyGestureSequence()
        feedRightwardSwipe(into: &sequence)
        sequence.handleCancelled()
        #expect(sequence.maxDisplacement == 0)
    }

    @Test func tapAfterCancelledSwipeClassifiesAsTap() {
        var sequence = KeyGestureSequence()
        // A rightward swipe is cancelled by the system mid-gesture …
        feedRightwardSwipe(into: &sequence)
        sequence.handleCancelled()

        // … then the user taps the key. With the stale path still buffered,
        // the tap's samples would append onto the swipe and classify as a
        // rightward swipe; a fresh sequence classifies it as a tap.
        _ = sequence.handleChanged(translation: CGSize(width: 1, height: 1))
        let classification = sequence.handleEnded(
            translation: CGSize(width: 1, height: 1), aspectRatio: 1.0
        )
        #expect(classification.gesture == .tap)
        #expect(!classification.isReturn)
    }
}
