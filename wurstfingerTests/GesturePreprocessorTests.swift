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

    @Test func jitterFilterRemovesClosePoints() {
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
            CGPoint(x: 1, y: 1), // too close, should be removed
            CGPoint(x: 2, y: 2), // too close, should be removed
            CGPoint(x: 10, y: 10), // far enough, should be kept
            CGPoint(x: 11, y: 11), // too close, should be removed
            CGPoint(x: 20, y: 20) // far enough, should be kept
        ]

        let filtered = preprocessor.filterJitter(points)

        // Should keep: first, 10/10, 20/20 (and last if different)
        #expect(filtered.count >= 3)
        #expect(filtered.first == CGPoint(x: 0, y: 0))
    }

    @Test func jitterFilterKeepsDistantPoints() {
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

    @Test func outlierFilterRemovesLargeJumps() {
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
            CGPoint(x: 100, y: 0), // outlier: jump of 90pt
            CGPoint(x: 20, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        // The outlier at (100, 0) should be removed
        #expect(filtered.count == 3)
        #expect(!filtered.contains(CGPoint(x: 100, y: 0)))
    }

    @Test func outlierFilterRemovesTrailingGlitchPoint() {
        let config = GesturePreprocessorConfig(
            jitterThreshold: 3.0,
            maxJumpDistance: 30.0,
            smoothingWindow: 5,
            smoothingOrder: 2,
            aspectRatio: 1.0
        )
        let preprocessor = GesturePreprocessor(config: config)

        // A glitch as the final sample has no raw successor and must
        // still be removed. What removes it is its size, not its position:
        // the established step is 10pt and the jump is 130, thirteen times
        // what the finger was covering per sample.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 150, y: 0) // trailing outlier: jump of 130pt
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == Array(points.prefix(3)))
    }

    @Test func outlierFilterKeepsTailAfterDroppedFrameGap() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A dropped frame under main-thread load creates one inter-sample
        // gap > maxJumpDistance in a genuine fast swipe. The points after
        // the gap are mutually consistent and must not cascade away.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 80, y: 0), // 60pt gap: dropped frame, real motion
            CGPoint(x: 95, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == points)
    }

    @Test func outlierFilterRemovesClusteredGlitchPair() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // Two mutually close ghost points far from the path must not admit
        // each other via raw-neighbor support: the run is short (2) and the
        // cluster sits beyond the 3x plausibility ceiling.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 200, y: 5), // ghost pair, ~190pt off the path
            CGPoint(x: 205, y: 0),
            CGPoint(x: 20, y: 0), // real motion resumes
            CGPoint(x: 30, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == [points[0], points[1], points[4], points[5]])
    }

    @Test func outlierFilterKeepsAFlickFasterThanTheJumpThreshold() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A fling at ~0.5 m/s delivered at 60 Hz puts ~53pt between
        // consecutive samples, so *every* step exceeds maxJumpDistance and no
        // sample has a raw neighbor within it. Only the fact that the steps
        // continue one another marks this as real motion rather than a run of
        // teleports — without that criterion the whole gesture was discarded
        // and the key committed its center letter.
        let points = (0 ... 4).map { CGPoint(x: CGFloat($0) * 53, y: 0) }

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == points)
    }

    @Test func outlierFilterRejectsAJumpTheFingerWasTooSlowFor() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // Same direction as the established motion, but ~15x its per-sample
        // travel: a finger moving 12pt per sample cannot cover 176 in the
        // next one. The glitch has a dwell partner after it, so the
        // trailing-glitch rule does not apply — this pins that the velocity
        // criterion refuses to admit it either.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 12, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 200, y: 0), // glitch: 176pt in one sample
            CGPoint(x: 201, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(!filtered.contains(CGPoint(x: 200, y: 0)))
    }

    @Test func outlierFilterRejectsATeleportThatReturnsToThePath() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A glitch on the first sample after touch-down, where the accepted
        // path has no step of its own yet and the following raw step is the
        // only velocity evidence there is. Both steps around the ghost are
        // long, so magnitude alone reads as fast motion — they point opposite
        // ways, which no finger does between two samples.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 150, y: 0), // out…
            CGPoint(x: 5, y: 0), // …and straight back to the finger
            CGPoint(x: 10, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == [points[0], points[2], points[3]])
    }

    @Test func outlierFilterRemovesATrailingGlitchOnAFastSwipe() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // An ordinary fast right swipe with one glitch sample on the end. The
        // glitch is 119pt from the path — just inside 3x the 40pt established
        // step — but nearly perpendicular to it. Admitting it moved the
        // committed direction from right to down-right, i.e. a different
        // letter, on a gesture the filter used to read correctly.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 80, y: 0),
            CGPoint(x: 120, y: 0),
            CGPoint(x: 125, y: 119) // glitch: 88° off the established motion
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == Array(points.prefix(4)))
    }

    @Test func outlierFilterKeepsTheGenuineTailAfterRejectingAGlitch() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // The same glitch with the swipe continuing past it. Accepting a
        // glitch costs twice: the anchor moves onto it, and the genuine
        // sample after it is then measured from the glitch instead of from
        // the path — so it fails every criterion and the swipe loses its tail.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 80, y: 0),
            CGPoint(x: 120, y: 0),
            CGPoint(x: 125, y: 119), // glitch
            CGPoint(x: 160, y: 0) // real motion continues
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == [points[0], points[1], points[2], points[3], points[5]])
    }

    @Test func outlierFilterRejectsAJumpAcrossTheEstablishedDirection() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A 3-4-5 step: 100pt long, 53° off the established direction. The
        // length is inside the 3x tolerance the 40pt established step buys, so
        // only the direction cone rejects it — 53° is wider than the 45° a
        // swipe sector spans, which is exactly when admitting a sample can
        // change the committed letter.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 80, y: 0),
            CGPoint(x: 120, y: 0),
            CGPoint(x: 180, y: 80) // step (60, 80): |100| at 53°
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == Array(points.prefix(4)))
    }

    @Test func outlierFilterCannotRaiseItsOwnJumpBudget() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A 53pt flick, then jumps of 159 and 477 — each one exactly 3x its
        // predecessor and dead straight, so every one of them continues the
        // established direction. Only the cap on the reference stops the
        // allowance from tripling per accepted jump; without it the chain
        // walks itself arbitrarily far off the key.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 53, y: 0),
            CGPoint(x: 106, y: 0),
            CGPoint(x: 159, y: 0),
            CGPoint(x: 318, y: 0), // 159pt in one sample
            CGPoint(x: 795, y: 0) // 477pt in the next
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == Array(points.prefix(4)))
    }

    @Test func outlierFilterPrefersTheEstablishedStepOverTheFollowingRawStep() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // The glitch is followed by more fast motion rather than a dwell, so
        // the two candidate references disagree: the 12pt step the accepted
        // path established refuses the 120pt jump, the 60pt step that follows
        // it would wave it through. The established one has to win — the step
        // after a glitch is part of the same unverified excursion.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 12, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 144, y: 0), // glitch: 120pt in one sample
            CGPoint(x: 204, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == Array(points.prefix(3)))
    }

    @Test func outlierFilterKeepsSustainedFarRun() {
        let config = GesturePreprocessorConfig.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        // A run of >= 3 mutually consistent samples beyond the ceiling is
        // sustained real motion (re-anchored long drag), not a ghost cluster.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 200, y: 0), // far window, but the motion continues
            CGPoint(x: 210, y: 0),
            CGPoint(x: 220, y: 0),
            CGPoint(x: 230, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == points)
    }

    // MARK: - Aspect Ratio Normalization Tests

    @Test func aspectRatioNormalizationDividesX() {
        let config = GesturePreprocessorConfig(
            jitterThreshold: 3.0,
            maxJumpDistance: 50.0,
            smoothingWindow: 5,
            smoothingOrder: 2,
            aspectRatio: 2.0 // width is 2x height
        )
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 20)
        ]

        let normalized = preprocessor.normalizeAspectRatio(points)

        #expect(normalized[0].x == 10) // 20 / 2
        #expect(normalized[0].y == 10) // unchanged
        #expect(normalized[1].x == 20) // 40 / 2
        #expect(normalized[1].y == 20) // unchanged
    }

    @Test func aspectRatioNormalizationSkipsForSquare() {
        let config = GesturePreprocessorConfig.default // aspectRatio = 1.0
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 20, y: 10)
        ]

        let normalized = preprocessor.normalizeAspectRatio(points)

        #expect(normalized[0] == points[0]) // unchanged
    }

    // MARK: - Savitzky-Golay Smoothing Tests

    @Test func savitzkyGolaySmoothsPath() {
        let config = GesturePreprocessorConfig.default
        let preprocessor = GesturePreprocessor(config: config)

        // A noisy path
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 5),
            CGPoint(x: 20, y: -2), // noise
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

    @Test func preprocessPipelineProducesCleanPath() {
        let config = GesturePreprocessorConfig.default.with(aspectRatio: 1.5)
        let preprocessor = GesturePreprocessor(config: config)

        // A realistic swipe path with some noise
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0), // jitter
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

    @Test func extractFeaturesFromStraightLine() {
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
        #expect(abs(features.returnRatio - 1.0) < 0.01) // chord == path for straight line
        #expect(abs(features.dominantAngle) < 0.1) // angle ~0 for rightward
        #expect(features.maxDisplacementProgress > 0.9) // max at end
    }

    @Test func extractFeaturesFromReturnSwipe() {
        // Swipe right then return to start
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 15, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 45, y: 0), // max displacement here (middle-ish)
            CGPoint(x: 30, y: 0),
            CGPoint(x: 15, y: 0),
            CGPoint(x: 5, y: 0) // return near start
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.maxDisplacement == 45)
        #expect(features.chordLength < features.maxDisplacement)
        #expect(features.returnRatio < 0.5) // low ratio = returned to start
        // maxDisplacementProgress should be around 0.5 (middle of path)
        #expect(features.maxDisplacementProgress > 0.3)
        #expect(features.maxDisplacementProgress < 0.7)
    }

    @Test func extractFeaturesFromSpiralPath() {
        // Realistic spiral gesture: starts at origin and expands outward
        // Use more points with larger angular coverage to ensure > 270° sweep
        var points: [CGPoint] = []

        for i in 0 ..< 30 {
            let angle = CGFloat(i) * .pi / 6 // counter-clockwise, ~900° total
            let radius = 5.0 + CGFloat(i) * 2.0 // expanding radius (5 to 63)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        let features = GestureFeatures.extract(from: points)

        #expect(features.circularity > 0.3)
        #expect(abs(features.angularSpan) > .pi * 1.5) // > 270°
        #expect(features.pathSeparation > 0.5) // mirrored points far apart
        #expect(features.isCircular)
    }

    // MARK: - Classification Tests

    @Test func classifyTapForSmallDisplacement() {
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

    @Test func classifySwipeForLongPath() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 20),
            CGPoint(x: 60, y: 30)
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.pathLength > 30)
        #expect(!features.isTap)
        #expect(!features.isReturn) // didn't return to start
    }

    @Test func classifyReturnSwipe() {
        // Explicit return swipe: out and back
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 50, y: 0), // max displacement
            CGPoint(x: 40, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 5, y: 0) // back near start
        ]

        let features = GestureFeatures.extract(from: points)

        #expect(features.maxDisplacement > 30)
        #expect(features.isReturn)
    }

    // MARK: - Edge Cases

    @Test func handleEmptyPath() {
        let features = GestureFeatures.extract(from: [])

        #expect(features.pathLength == 0)
        #expect(features.isTap)
    }

    @Test func handleSinglePoint() {
        let features = GestureFeatures.extract(from: [CGPoint(x: 10, y: 10)])

        #expect(features.pathLength == 0)
        #expect(features.isTap)
    }

    @Test func handleTwoPoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0)]
        let features = GestureFeatures.extract(from: points)

        #expect(features.pathLength == 50)
        #expect(features.chordLength == 50)
        #expect(!features.isTap)
    }

    // MARK: - Direction Tests

    @Test func maxDisplacementAnglePointsRight() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~0 (pointing right)
        #expect(abs(features.maxDisplacementAngle) < 0.1)
    }

    @Test func maxDisplacementAnglePointsDown() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 50)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~π/2 (pointing down)
        #expect(abs(features.maxDisplacementAngle - .pi / 2) < 0.1)
    }

    @Test func maxDisplacementAnglePointsDownRight() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50)
        ]

        let features = GestureFeatures.extract(from: points)

        // Angle should be ~π/4 (45°, pointing down-right)
        #expect(abs(features.maxDisplacementAngle - .pi / 4) < 0.1)
    }

    // MARK: - Clockwise Detection Tests

    @Test func detectClockwiseSpiral() {
        // Realistic spiral: starts and spirals outward clockwise
        // Use more points with larger angular coverage
        var points: [CGPoint] = []

        for i in 0 ..< 30 {
            let angle = -CGFloat(i) * .pi / 6 // clockwise (negative), ~900° total
            let radius = 5.0 + CGFloat(i) * 2.0 // expanding radius (5 to 63)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        let features = GestureFeatures.extract(from: points)

        // Spiral: early and late points are far apart (high pathSeparation)
        #expect(features.pathSeparation > 0.5)
        #expect(features.isCircular)
        #expect(!features.isClockwise) // clockwise in screen = negative angularSpan
    }

    @Test func detectCounterclockwiseSpiral() {
        // Realistic spiral: starts and spirals outward counter-clockwise
        // Use more points with larger angular coverage
        var points: [CGPoint] = []

        for i in 0 ..< 30 {
            let angle = CGFloat(i) * .pi / 6 // counter-clockwise (positive), ~900° total
            let radius = 5.0 + CGFloat(i) * 2.0 // expanding radius (5 to 63)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        let features = GestureFeatures.extract(from: points)

        // Spiral: early and late points are far apart (high pathSeparation)
        #expect(features.pathSeparation > 0.5)
        #expect(features.isCircular)
        #expect(features.isClockwise) // CCW in math = positive angularSpan
    }
}

// MARK: - Expert Mode Gating Tests

/// Custom `gesture.*` values must only govern gesture recognition while
/// expert mode is enabled. When the user turns expert mode off (the obvious
/// recovery action after breaking gesture recognition), the defaults apply
/// again — but the stored values survive so re-enabling restores them.
struct ExpertModeGatingTests {
    private func storeWithCustomValues(expertModeEnabled: Bool) -> InMemoryUserDefaults {
        let store = InMemoryUserDefaults()
        store.set(expertModeEnabled, forKey: SettingsKey.expertModeEnabled.rawValue)
        // Inside the Expert ranges: out-of-range values are clamped (see
        // ExpertValueClampingTests).
        store.set(9.0, forKey: GesturePreprocessorConfig.jitterThresholdKey)
        store.set(90.0, forKey: GesturePreprocessorConfig.maxJumpDistanceKey)
        store.set(7, forKey: GesturePreprocessorConfig.smoothingWindowKey)
        store.set(42.0, forKey: GestureClassificationThresholds.minSwipeLengthKey)
        store.set(0.7, forKey: GestureClassificationThresholds.maxReturnRatioKey)
        store.set(0.6, forKey: GestureClassificationThresholds.minCircularityKey)
        return store
    }

    @Test func configIgnoresCustomValuesWhenExpertModeIsOff() {
        let store = storeWithCustomValues(expertModeEnabled: false)

        let config = GesturePreprocessorConfig.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == GesturePreprocessorConfig.defaultJitterThreshold)
        #expect(config.maxJumpDistance == GesturePreprocessorConfig.defaultMaxJumpDistance)
        #expect(config.smoothingWindow == GesturePreprocessorConfig.defaultSmoothingWindow)
    }

    @Test func configAppliesCustomValuesWhenExpertModeIsOn() {
        let store = storeWithCustomValues(expertModeEnabled: true)

        let config = GesturePreprocessorConfig.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == 9.0)
        #expect(config.maxJumpDistance == 90.0)
        #expect(config.smoothingWindow == 7)
    }

    @Test func configIgnoresCustomValuesWhenExpertModeKeyIsMissing() {
        let store = storeWithCustomValues(expertModeEnabled: false)
        store.removeObject(forKey: SettingsKey.expertModeEnabled.rawValue)

        let config = GesturePreprocessorConfig.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == GesturePreprocessorConfig.defaultJitterThreshold)
    }

    @Test func thresholdsIgnoreCustomValuesWhenExpertModeIsOff() {
        let store = storeWithCustomValues(expertModeEnabled: false)

        let thresholds = GestureClassificationThresholds.fromUserDefaults(store: store)

        #expect(thresholds.minSwipeLength == GestureClassificationThresholds.defaultMinSwipeLength)
        #expect(thresholds.maxReturnRatio == GestureClassificationThresholds.defaultMaxReturnRatio)
        #expect(thresholds.minCircularity == GestureClassificationThresholds.defaultMinCircularity)
    }

    @Test func thresholdsApplyCustomValuesWhenExpertModeIsOn() {
        let store = storeWithCustomValues(expertModeEnabled: true)

        let thresholds = GestureClassificationThresholds.fromUserDefaults(store: store)

        #expect(thresholds.minSwipeLength == 42.0)
        #expect(thresholds.maxReturnRatio == 0.7)
        #expect(thresholds.minCircularity == 0.6)
    }

    @Test func customValuesSurviveExpertModeRoundTrip() {
        let store = storeWithCustomValues(expertModeEnabled: true)

        store.set(false, forKey: SettingsKey.expertModeEnabled.rawValue)
        #expect(GestureClassificationThresholds.fromUserDefaults(store: store).minSwipeLength
            == GestureClassificationThresholds.defaultMinSwipeLength)

        store.set(true, forKey: SettingsKey.expertModeEnabled.rawValue)
        #expect(GestureClassificationThresholds.fromUserDefaults(store: store).minSwipeLength == 42.0)
    }

    @Test func configValuesSurviveExpertModeRoundTrip() {
        let store = storeWithCustomValues(expertModeEnabled: true)

        store.set(false, forKey: SettingsKey.expertModeEnabled.rawValue)
        #expect(GesturePreprocessorConfig.fromUserDefaults(store: store).jitterThreshold
            == GesturePreprocessorConfig.defaultJitterThreshold)

        store.set(true, forKey: SettingsKey.expertModeEnabled.rawValue)
        #expect(GesturePreprocessorConfig.fromUserDefaults(store: store).jitterThreshold == 9.0)
        #expect(GesturePreprocessorConfig.fromUserDefaults(store: store).maxJumpDistance == 90.0)
    }
}
