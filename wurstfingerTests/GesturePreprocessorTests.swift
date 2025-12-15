//
//  GesturePreprocessorTests.swift
//  wurstfingerTests
//
//  Tests for gesture preprocessing pipeline and feature extraction
//

import Foundation
import Testing
@testable import WurstfingerApp

struct GesturePreprocessorTests {

    // MARK: - Jitter Filter Tests

    @Test func jitterFilterRemovesClosePoints() async throws {
        let config = GesturePreprocessorConfig(
            jitterThreshold: 5.0,
            maxJumpDistance: 100.0,
            smoothingWindow: 5,
            smoothingOrder: 2,
            aspectRatio: 1.0
        )
        let preprocessor = GesturePreprocessor(config: config)

        // Points with small movements (< 5pt) should be filtered
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 1),   // too close, should be removed
            CGPoint(x: 2, y: 2),   // too close, should be removed
            CGPoint(x: 10, y: 10), // far enough, should be kept
            CGPoint(x: 11, y: 11), // too close, should be removed
            CGPoint(x: 20, y: 20)  // far enough, should be kept
        ]

        let filtered = preprocessor.filterJitter(points)

        // Should keep: first, 10/10, 20/20 (and last if different)
        #expect(filtered.count >= 3)
        #expect(filtered.first == CGPoint(x: 0, y: 0))
    }

    @Test func jitterFilterKeepsDistantPoints() async throws {
        let config = GesturePreprocessorConfig.default
        let preprocessor = GesturePreprocessor(config: config)

        // All points are far apart
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 60, y: 0)
        ]

        let filtered = preprocessor.filterJitter(points)

        #expect(filtered.count == 4)
    }

    // MARK: - Outlier Filter Tests

    @Test func outlierFilterRemovesLargeJumps() async throws {
        let config = GesturePreprocessorConfig(
            jitterThreshold: 3.0,
            maxJumpDistance: 30.0,
            smoothingWindow: 5,
            smoothingOrder: 2,
            aspectRatio: 1.0
        )
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 100, y: 0),  // outlier: jump of 90pt
            CGPoint(x: 20, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        // The outlier at (100, 0) should be removed
        #expect(filtered.count == 3)
        #expect(!filtered.contains(CGPoint(x: 100, y: 0)))
    }

    // MARK: - Aspect Ratio Normalization Tests

    @Test func aspectRatioNormalizationDividesX() async throws {
        let config = GesturePreprocessorConfig(
            jitterThreshold: 3.0,
            maxJumpDistance: 50.0,
            smoothingWindow: 5,
            smoothingOrder: 2,
            aspectRatio: 2.0  // width is 2x height
        )
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 20)
        ]

        let normalized = preprocessor.normalizeAspectRatio(points)

        #expect(normalized[0].x == 10)  // 20 / 2
        #expect(normalized[0].y == 10)  // unchanged
        #expect(normalized[1].x == 20)  // 40 / 2
        #expect(normalized[1].y == 20)  // unchanged
    }

    @Test func aspectRatioNormalizationSkipsForSquare() async throws {
        let config = GesturePreprocessorConfig.default  // aspectRatio = 1.0
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 20, y: 10)
        ]

        let normalized = preprocessor.normalizeAspectRatio(points)

        #expect(normalized[0] == points[0])  // unchanged
    }

    // MARK: - Savitzky-Golay Smoothing Tests

    @Test func savitzkyGolaySmoothsPath() async throws {
        let config = GesturePreprocessorConfig.default
        let preprocessor = GesturePreprocessor(config: config)

        // A noisy path
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 5),
            CGPoint(x: 20, y: -2),  // noise
            CGPoint(x: 30, y: 3),
            CGPoint(x: 40, y: 0)
        ]

        let smoothed = preprocessor.smoothSavitzkyGolay(points)

        // Smoothed path should have same count
        #expect(smoothed.count == points.count)

        // The noisy point should be smoothed (closer to neighbors)
        let originalNoise = abs(points[2].y)
        let smoothedNoise = abs(smoothed[2].y)
        #expect(smoothedNoise < originalNoise)
    }

    // MARK: - Full Pipeline Tests

    @Test func preprocessPipelineProducesCleanPath() async throws {
        let config = GesturePreprocessorConfig.default.with(aspectRatio: 1.5)
        let preprocessor = GesturePreprocessor(config: config)

        // A realistic swipe path with some noise
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),   // jitter
            CGPoint(x: 5, y: 2),
            CGPoint(x: 15, y: 8),
            CGPoint(x: 25, y: 12),
            CGPoint(x: 35, y: 18),
            CGPoint(x: 45, y: 22)
        ]

        let processed = preprocessor.preprocess(points)

        // Should have fewer points after jitter removal
        #expect(processed.count <= points.count)
        // Should still have meaningful path
        #expect(processed.count >= 2)
    }
}

// MARK: - Gesture Features Tests

struct GestureFeaturesTests {

    // MARK: - Feature Extraction Tests

    @Test func extractFeaturesFromStraightLine() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 40, y: 0)
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.pathLength == 40)
        #expect(features.chordLength == 40)
        #expect(abs(features.returnRatio - 1.0) < 0.01)  // chord == path for straight line
        #expect(abs(features.dominantAngle) < 0.1)  // angle ~0 for rightward
        #expect(features.maxDisplacementProgress > 0.9)  // max at end
    }

    @Test func extractFeaturesFromReturnSwipe() async throws {
        // Swipe right then return to start
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 15, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 45, y: 0),  // max displacement here (middle-ish)
            CGPoint(x: 30, y: 0),
            CGPoint(x: 15, y: 0),
            CGPoint(x: 5, y: 0)    // return near start
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.maxDisplacement == 45)
        #expect(features.chordLength < features.maxDisplacement)
        #expect(features.returnRatio < 0.5)  // low ratio = returned to start
        // maxDisplacementProgress should be around 0.5 (middle of path)
        #expect(features.maxDisplacementProgress > 0.3)
        #expect(features.maxDisplacementProgress < 0.7)
    }

    @Test func extractFeaturesFromCircularPath() async throws {
        // Approximate circle (8 points around a circle)
        let radius: CGFloat = 30
        let center = CGPoint(x: 30, y: 30)
        var points: [CGPoint] = []

        for i in 0..<16 {
            let angle = CGFloat(i) * .pi / 8  // 0 to 2π
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        // Close the circle
        points.append(points[0])

        let features = GestureFeatures.extract(from: points)

        #expect(features.circularity > 0.5)
        #expect(abs(features.angularSpan) > .pi * 1.5)  // > 270°
        #expect(features.isCircular)
    }

    // MARK: - Classification Tests

    @Test func classifyTapForSmallDisplacement() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 5, y: 3),
            CGPoint(x: 8, y: 5)
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.maxDisplacement < 30)
        #expect(features.isTap)
        #expect(!features.isReturn)
        #expect(!features.isCircular)
    }

    @Test func classifySwipeForLongPath() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 20),
            CGPoint(x: 60, y: 30)
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.pathLength > 30)
        #expect(!features.isTap)
        #expect(!features.isReturn)  // didn't return to start
    }

    @Test func classifyReturnSwipe() async throws {
        // Explicit return swipe: out and back
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 50, y: 0),  // max displacement
            CGPoint(x: 40, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 5, y: 0)    // back near start
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.maxDisplacement > 30)
        #expect(features.isReturn)
    }

    // MARK: - Edge Cases

    @Test func handleEmptyPath() async throws {
        let features = GestureFeatures.extract(from: [])

        #expect(features.pathLength == 0)
        #expect(features.isTap)
    }

    @Test func handleSinglePoint() async throws {
        let features = GestureFeatures.extract(from: [CGPoint(x: 10, y: 10)])

        #expect(features.pathLength == 0)
        #expect(features.isTap)
    }

    @Test func handleTwoPoints() async throws {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0)]
        let features = GestureFeatures.extract(from: points)

        #expect(features.pathLength == 50)
        #expect(features.chordLength == 50)
        #expect(!features.isTap)
    }

    // MARK: - Direction Tests

    @Test func maxDisplacementAnglePointsRight() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~0 (pointing right)
        #expect(abs(features.maxDisplacementAngle) < 0.1)
    }

    @Test func maxDisplacementAnglePointsDown() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 50)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~π/2 (pointing down)
        #expect(abs(features.maxDisplacementAngle - .pi / 2) < 0.1)
    }

    @Test func maxDisplacementAnglePointsDownRight() async throws {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~π/4 (45°, pointing down-right)
        #expect(abs(features.maxDisplacementAngle - .pi / 4) < 0.1)
    }

    // MARK: - Clockwise Detection Tests

    @Test func detectClockwiseCircle() async throws {
        // Clockwise circle (in screen coordinates: right, down, left, up)
        let radius: CGFloat = 30
        let center = CGPoint(x: 30, y: 30)
        var points: [CGPoint] = []

        // Go clockwise: 0 → -2π (negative because clockwise in screen coords)
        for i in 0..<16 {
            let angle = -CGFloat(i) * .pi / 8
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        points.append(points[0])

        let features = GestureFeatures.extract(from: points)

        #expect(features.isCircular)
        // Note: isClockwise checks if angularSpan > 0
        // In screen coordinates, clockwise gives negative angularSpan
        #expect(!features.isClockwise)  // clockwise in screen = negative angularSpan
    }

    @Test func detectCounterclockwiseCircle() async throws {
        // Counter-clockwise circle
        let radius: CGFloat = 30
        let center = CGPoint(x: 30, y: 30)
        var points: [CGPoint] = []

        for i in 0..<16 {
            let angle = CGFloat(i) * .pi / 8  // positive = CCW in math, but in screen coords...
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        points.append(points[0])

        let features = GestureFeatures.extract(from: points)

        #expect(features.isCircular)
        #expect(features.isClockwise)  // CCW in math coords = positive angularSpan
    }
}
