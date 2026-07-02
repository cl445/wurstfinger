//
//  OriginAnchoringTests.swift
//  WurstfingerTests
//
//  Tests for KeyGestureRecognizer.anchoringOrigin, which restores the
//  touch-down origin (0,0) when a long gesture overflows the position ring
//  buffer and the origin sample is evicted.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct OriginAnchoringTests {
    // MARK: - Pure function

    @Test func emptyStaysEmpty() {
        #expect(KeyGestureRecognizer.anchoringOrigin([]).isEmpty)
    }

    @Test func leadingOriginIsUnchanged() {
        let points = [CGPoint.zero, CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)]
        #expect(KeyGestureRecognizer.anchoringOrigin(points) == points)
    }

    @Test func evictedOriginIsReAnchored() {
        // Buffer overflowed: first retained sample is mid-gesture, not (0,0).
        let evicted = [CGPoint(x: 30, y: 0), CGPoint(x: 40, y: 0)]
        let result = KeyGestureRecognizer.anchoringOrigin(evicted)
        #expect(result.first == .zero)
        #expect(result == [.zero] + evicted)
    }

    // MARK: - End-to-end classification

    @Test func longReturnSwipeIsRecognizedAfterOriginEviction() {
        // A rightward return swipe (out and back) long enough that the ring
        // buffer evicted the origin and the early outward samples — the
        // retained points start mid-gesture at x=40.
        var evicted: [CGPoint] = []
        for x in stride(from: 40, through: 60, by: 4) {
            evicted.append(CGPoint(x: CGFloat(x), y: 0))
        }
        for x in stride(from: 56, through: 4, by: -4) {
            evicted.append(CGPoint(x: CGFloat(x), y: 0))
        }

        // Re-anchoring restores (0,0) as the origin, so the gesture reads as a
        // rightward return swipe again — checked through the production
        // classify(positions:) pipeline rather than a hand-rolled extraction.
        let anchored = KeyGestureRecognizer.anchoringOrigin(evicted)
        let classification = KeyGestureRecognizer.classify(
            positions: anchored,
            config: .default,
            thresholds: .default
        )
        #expect(classification.isReturn)
        #expect(classification.gesture == .swipeRight)
    }

    @Test func longDragWithFarOutRetainedWindowClassifiesAsSwipe() {
        // A long slow drag overflowed the ring buffer and the retained
        // window sits entirely beyond maxJumpDistance (50pt) from the
        // origin. The synthetic (0,0) → first-sample jump must not make
        // the outlier filter discard the whole gesture (which would
        // classify the drag as a tap).
        var evicted: [CGPoint] = []
        for x in stride(from: 100, through: 160, by: 4) {
            evicted.append(CGPoint(x: CGFloat(x), y: 0))
        }

        let anchored = KeyGestureRecognizer.anchoringOrigin(evicted)
        let classification = KeyGestureRecognizer.classify(positions: anchored)
        #expect(classification.gesture == .swipeRight)
        #expect(!classification.isReturn)
    }
}
