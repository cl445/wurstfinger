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
        (0..<pointCount).map { i in
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

    @Test func threequarterCircleMayBeCircular() {
        // 270° arc — exactly at boundary
        let points = circlePoints(span: 1.5 * .pi, pointCount: 30)
        let features = GestureFeatures.extract(from: points)

        // At exactly the threshold, this may or may not pass depending on
        // floating-point precision and whether other criteria are met.
        // The angular span threshold is 270° (1.5π), so this is right at the edge.
        // We just verify it doesn't crash and produces valid features.
        #expect(features.pathLength > 0)
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
