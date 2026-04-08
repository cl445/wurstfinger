//
//  CursorMovementTests.swift
//  WurstfingerTests
//
//  Tests for word boundary calculation used by discrete cursor movement.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct WordBoundaryTests {
    // MARK: - Forward (nextWordBoundaryOffset)

    @Test func forwardSkipsToEndOfFirstWord() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "hello world") == 5)
    }

    @Test func forwardSkipsLeadingWhitespace() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "  hello") == 7)
    }

    @Test func forwardHandlesSingleCharacter() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "a") == 1)
    }

    @Test func forwardHandlesOnlyWhitespace() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "   ") == 3)
    }

    @Test func forwardHandlesEmptyString() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "") == 0)
    }

    @Test func forwardHandlesPunctuation() {
        // Punctuation is non-whitespace, so it's treated as part of a word
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "hello, world") == 6)
    }

    @Test func forwardHandlesMultipleSpaces() {
        #expect(KeyboardViewController.nextWordBoundaryOffset(in: "   word") == 7)
    }

    // MARK: - Backward (previousWordBoundaryOffset)

    @Test func backwardSkipsToStartOfLastWord() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "hello world") == 5)
    }

    @Test func backwardSkipsTrailingWhitespace() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "hello  ") == 7)
    }

    @Test func backwardHandlesSingleCharacter() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "a") == 1)
    }

    @Test func backwardHandlesOnlyWhitespace() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "   ") == 3)
    }

    @Test func backwardHandlesEmptyString() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "") == 0)
    }

    @Test func backwardHandlesPunctuation() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "hello, world") == 5)
    }

    @Test func backwardHandlesMultipleWords() {
        #expect(KeyboardViewController.previousWordBoundaryOffset(in: "one two three") == 5)
    }
}

struct DiscreteGestureClassificationTests {
    @Test func returnRatioBelowThresholdIsReturnSwipe() {
        // finalX near zero, maxDisplacement large → return swipe
        let maxDisplacement: CGFloat = 50
        let finalX: CGFloat = 5
        let ratio = abs(finalX) / abs(maxDisplacement)
        #expect(ratio < KeyboardConstants.SpaceGestures.returnSwipeThreshold)
    }

    @Test func returnRatioAboveThresholdIsRegularSwipe() {
        // finalX close to maxDisplacement → regular swipe
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
