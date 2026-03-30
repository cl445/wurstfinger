//
//  CircularGestureTests.swift
//  WurstfingerTests
//
//  Tests for circular gesture detection via GestureFeatures.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct CircularGestureTests {
    // MARK: - Helper: Generate circle points

    /// Generates points along a circle arc.
    /// - Parameters:
    ///   - center: Center of the circle
    ///   - radius: Radius of the circle
    ///   - startAngle: Start angle in radians
    ///   - span: Angular span in radians (positive = clockwise in screen coords)
    ///   - pointCount: Number of points to generate
    private func circlePoints(
        center: CGPoint = CGPoint(x: 50, y: 50),
        radius: CGFloat = 30,
        startAngle: CGFloat = 0,
        span: CGFloat = 2 * .pi,
        pointCount: Int = 40
    ) -> [CGPoint] {
        guard pointCount > 1 else {
            return pointCount == 1 ? [CGPoint(x: center.x + radius * cos(startAngle),
                                               y: center.y + radius * sin(startAngle))] : []
        }
        return (0..<pointCount).map { i in
            let t = CGFloat(i) / CGFloat(pointCount - 1)
            let angle = startAngle + span * t
            return CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }

    // MARK: - Perfect Circles

    @Test func perfectClockwiseCircleIsDetected() {
        // Use 1.1 full turns to ensure the angular span is clearly above threshold
        // and the path doesn't close perfectly (which can trigger isReturn due to low chord)
        let points = circlePoints(span: 2.2 * .pi, pointCount: 50)
        let features = GestureFeatures.extract(from: points)

        #expect(features.isCircular)
        #expect(features.isClockwise)
        #expect(!features.isTap)
    }

    @Test func perfectCounterclockwiseCircleIsDetected() {
        let points = circlePoints(span: -2.2 * .pi, pointCount: 50)
        let features = GestureFeatures.extract(from: points)

        #expect(features.isCircular)
        #expect(!features.isClockwise)
        #expect(!features.isTap)
    }

    // MARK: - Incomplete Circles

    @Test func halfCircleIsNotCircular() {
        // Only 180° arc — below minAngularSpan (270°)
        let points = circlePoints(span: .pi)
        let features = GestureFeatures.extract(from: points)

        #expect(!features.isCircular)
    }

    @Test func arcBelowAngularSpanThreshold() {
        // 200° arc — comfortably below the 270° minAngularSpan threshold
        let span = 200.0 / 180.0 * .pi
        let points = circlePoints(span: span, pointCount: 40)
        let features = GestureFeatures.extract(from: points)

        let threshold = GestureClassificationThresholds.default.minAngularSpan
        #expect(abs(features.angularSpan) < threshold,
                "A 200° arc angular span (\(abs(features.angularSpan))) should be below the \(threshold) threshold")
    }

    @Test func arcAboveAngularSpanThreshold() {
        // 330° arc — comfortably above the 270° minAngularSpan threshold
        let span = 330.0 / 180.0 * .pi
        let points = circlePoints(span: span, pointCount: 50)
        let features = GestureFeatures.extract(from: points)

        let threshold = GestureClassificationThresholds.default.minAngularSpan
        #expect(abs(features.angularSpan) > threshold,
                "A 330° arc angular span (\(abs(features.angularSpan))) should exceed the \(threshold) threshold")
    }

    // MARK: - Too Few Points

    @Test func singlePointIsNotCircular() {
        let features = GestureFeatures.extract(from: [CGPoint(x: 50, y: 50)])
        #expect(!features.isCircular)
        #expect(features.isTap)
    }

    @Test func twoPointsIsNotCircular() {
        let features = GestureFeatures.extract(from: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 30)
        ])
        #expect(!features.isCircular)
    }

    // MARK: - Path Too Small

    @Test func tinyCircleIsTap() {
        // Circle with radius 3 — maxDisplacement will be below minSwipeLength (20)
        let points = circlePoints(radius: 3, pointCount: 20)
        let features = GestureFeatures.extract(from: points)

        // pathLength is small, so isTap should be true
        #expect(features.isTap)
        #expect(!features.isCircular)
    }

    // MARK: - Straight Line is Not Circular

    @Test func straightLineIsNotCircular() {
        let points = (0..<20).map { i in
            CGPoint(x: CGFloat(i) * 3, y: 0)
        }
        let features = GestureFeatures.extract(from: points)

        #expect(!features.isCircular)
    }
}
