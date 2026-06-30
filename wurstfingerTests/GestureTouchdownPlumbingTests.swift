//
//  GestureTouchdownPlumbingTests.swift
//  WurstfingerTests
//
//  P4: the gesture recognizer normalizes the touchdown to the key frame and
//  carries the feature vector in the classification (plumbed for offset
//  learning §4.1 and telemetry §13).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct GestureTouchdownPlumbingTests {
    @Test func normalizesCenterToHalf() {
        let p = KeyGestureRecognizer.normalizedTouchdown(CGPoint(x: 50, y: 30), in: CGSize(width: 100, height: 60))
        #expect(abs(p.x - 0.5) < 1e-9)
        #expect(abs(p.y - 0.5) < 1e-9)
    }

    @Test func normalizesCornerToZero() {
        let p = KeyGestureRecognizer.normalizedTouchdown(.zero, in: CGSize(width: 80, height: 40))
        #expect(p.x == 0 && p.y == 0)
    }

    @Test func clampsOutOfBoundsTouchdown() {
        let p = KeyGestureRecognizer.normalizedTouchdown(CGPoint(x: 200, y: -10), in: CGSize(width: 100, height: 60))
        #expect(p.x == 1 && p.y == 0)
    }

    @Test func zeroSizeFallsBackToCenter() {
        let p = KeyGestureRecognizer.normalizedTouchdown(CGPoint(x: 10, y: 10), in: .zero)
        #expect(p.x == 0.5 && p.y == 0.5)
    }

    @Test func classificationCarriesFeatures() {
        // A degenerate (no-displacement) path classifies as a tap and still
        // carries the extracted feature vector.
        let result = KeyGestureRecognizer.classify(positions: [.zero, .zero])
        #expect(result.gesture == .tap)
        #expect(result.features != nil)
    }

    @Test func defaultTouchdownIsCenter() {
        // Callers that build a classification without a touchdown get center.
        let result = KeyGestureRecognizer.classify(features: .empty())
        #expect(result.touchdown == CGPoint(x: 0.5, y: 0.5))
    }
}
