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
        let config = GesturePreprocessorConfiguration(
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
        let config = GesturePreprocessorConfiguration.default
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
        let config = GesturePreprocessorConfiguration(
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
        let config = GesturePreprocessorConfiguration(
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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

    /// The two candidate references disagree: the 12pt step the accepted
    /// path established refuses the 120pt jump, the 60pt step the jump
    /// leads into carries it. The longer one wins. Preferring the
    /// established step reads as the safer choice and is not: a slow step
    /// is no evidence against acceleration, since a flick launching out of
    /// a rolling start is exactly a slow step followed by a fast one, and
    /// preferring the established step lost every one of those (review
    /// 2026-08-29, finding 1). What still separates a glitch from a launch
    /// is the direction cone and the magnitude ceiling, pinned by the
    /// tests around this one.
    @Test func outlierFilterMeasuresAJumpAgainstTheLongerCandidateStep() {
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 12, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 144, y: 0), // 120pt in one sample…
            CGPoint(x: 204, y: 0) // …and the finger keeps going at 60pt
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == points)
    }

    /// A finger that settles on the key with a slow drift and only then
    /// flicks. The drift establishes a 5pt step, so measuring the first
    /// 80pt sample against it rejects the jump — and since a rejection
    /// leaves both the anchor and the established step alone, every later
    /// flick sample fails the same way and the classifier only ever saw
    /// the drift. The flick's own following step is what vouches for it.
    @Test func outlierFilterKeepsAFlickThatLaunchesOutOfARollingStart() {
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 5, y: 0), // drift…
            CGPoint(x: 10, y: 0),
            CGPoint(x: 90, y: 0), // …then the flick launches
            CGPoint(x: 170, y: 0),
            CGPoint(x: 250, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == points)
    }

    /// The out-and-back shape with the excursion in the middle of the path
    /// rather than on the first sample. This is the position where taking
    /// the longer candidate step changes the reference: the 138pt step
    /// leading back to the finger outweighs the 12pt gait, so magnitude
    /// alone would admit the teleport. It is opposed to that reference, so
    /// the direction cone rejects it — the criterion the mid-path case
    /// rests on entirely.
    @Test func outlierFilterRejectsAMidPathTeleportThatReturnsToThePath() {
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 12, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 174, y: 0), // out…
            CGPoint(x: 36, y: 0), // …and back to where the finger was
            CGPoint(x: 48, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == [points[0], points[1], points[2], points[4], points[5]])
    }

    /// Two ghost samples far off the path, each far enough from its
    /// neighbors that raw-neighbor support cannot admit them, and moving
    /// fast enough that magnitude alone would. They do not travel
    /// together: the 100pt step between them is perpendicular to the 200pt
    /// jump onto the first, so the reference the first would ride in on
    /// does not point its way, and the second is past the ceiling by the
    /// time the first is refused.
    @Test func outlierFilterRejectsAGhostBurstThatTurnsBetweenItsSamples() {
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 12, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 24, y: 200), // ghost…
            CGPoint(x: 124, y: 200), // …turning 90° between its two samples
            CGPoint(x: 36, y: 0), // real motion resumes
            CGPoint(x: 48, y: 0)
        ]

        let filtered = preprocessor.filterOutliers(points)

        #expect(filtered == [points[0], points[1], points[2], points[5], points[6]])
    }

    // MARK: - Rolling-Start Classification Tests

    /// Three drift samples followed by three 80pt flick samples, the shape
    /// review 2026-08-29 finding 1 measured. Both bands it names are covered:
    /// 1–5 pt per sample, where the drift stays under `minSwipeLength` and the
    /// lost flick committed the key's center letter, and 8–26 pt per sample,
    /// where the drift is itself long enough to classify.
    private static let rollingStartDriftRates: [CGFloat] = [1, 2, 3, 5, 8, 12, 20, 26]

    /// That shape for one drift direction and rate: three drift samples,
    /// then three 80 pt flick samples leaving the last of them.
    private func rollingStartPath(driftDegrees: CGFloat, driftRate: CGFloat) -> [CGPoint] {
        let drift = CGVector(dx: cos(driftDegrees * .pi / 180), dy: sin(driftDegrees * .pi / 180))
        var points: [CGPoint] = [.zero]
        for sample in 1 ... 3 {
            points.append(CGPoint(
                x: drift.dx * driftRate * CGFloat(sample),
                y: drift.dy * driftRate * CGFloat(sample)
            ))
        }
        // Safe: the loop above appended three points.
        let launch = points[points.count - 1]
        for sample in 1 ... 3 {
            points.append(CGPoint(x: launch.x + 80 * CGFloat(sample), y: launch.y))
        }
        return points
    }

    /// The gesture the recognizer commits for a raw path, production config.
    private func classify(_ points: [CGPoint]) -> GestureType {
        KeyGestureRecognizer.classify(positions: points, config: .default, thresholds: .default).gesture
    }

    /// A flick launching out of a drift that runs *along* it commits the
    /// flick's direction at every drift rate the sweep covers.
    ///
    /// Taken alone this direction looks healthy whether the flick survives or
    /// not: a lost flick below 5 pt per sample leaves a drift shorter than
    /// `minSwipeLength`, so the key commits its center letter, and from 8 pt
    /// the drift itself classifies — as a swipe that happens to point the
    /// right way. The across-drift case is what tells the two apart.
    @Test func aFlickOutOfADriftAlongItCommitsTheFlickDirection() {
        var mismatches: [String] = []
        for rate in Self.rollingStartDriftRates {
            let actual = classify(rollingStartPath(driftDegrees: 0, driftRate: rate))
            if actual != .swipeRight { mismatches.append("drift \(rate)pt: \(actual)") }
        }

        #expect(mismatches.isEmpty, "flick lost at: \(mismatches)")
    }

    /// A flick launching out of a drift that runs *across* it commits the
    /// flick's direction, not the drift's.
    ///
    /// This is the case that types a *different* letter rather than the
    /// center one: a drift that survives at 8 pt per sample or more
    /// classifies as `swipeDown`, and no drift rate is fast enough to carry
    /// the turn into the flick through the 45° cone.
    @Test func aFlickOutOfADriftAcrossItCommitsTheFlickDirection() {
        var mismatches: [String] = []
        for rate in Self.rollingStartDriftRates {
            let actual = classify(rollingStartPath(driftDegrees: 90, driftRate: rate))
            if actual != .swipeRight { mismatches.append("drift \(rate)pt: \(actual)") }
        }

        #expect(mismatches.isEmpty, "flick lost at: \(mismatches)")
    }

    @Test func outlierFilterKeepsSustainedFarRun() {
        let config = GesturePreprocessorConfiguration.default // maxJumpDistance = 50
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
        let config = GesturePreprocessorConfiguration(
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
        let config = GesturePreprocessorConfiguration.default // aspectRatio = 1.0
        let preprocessor = GesturePreprocessor(config: config)

        let points: [CGPoint] = [
            CGPoint(x: 20, y: 10)
        ]

        let normalized = preprocessor.normalizeAspectRatio(points)

        #expect(normalized[0] == points[0]) // unchanged
    }

    // MARK: - Savitzky-Golay Smoothing Tests

    @Test func savitzkyGolaySmoothsPath() {
        let config = GesturePreprocessorConfiguration.default
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
        let config = GesturePreprocessorConfiguration.default.with(aspectRatio: 1.5)
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
        store.set(9.0, forKey: GesturePreprocessorConfiguration.jitterThresholdKey)
        store.set(90.0, forKey: GesturePreprocessorConfiguration.maxJumpDistanceKey)
        store.set(7, forKey: GesturePreprocessorConfiguration.smoothingWindowKey)
        store.set(42.0, forKey: GestureClassificationThresholds.minSwipeLengthKey)
        store.set(0.7, forKey: GestureClassificationThresholds.maxReturnRatioKey)
        store.set(0.6, forKey: GestureClassificationThresholds.minCircularityKey)
        return store
    }

    @Test func configIgnoresCustomValuesWhenExpertModeIsOff() {
        let store = storeWithCustomValues(expertModeEnabled: false)

        let config = GesturePreprocessorConfiguration.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == GesturePreprocessorConfiguration.defaultJitterThreshold)
        #expect(config.maxJumpDistance == GesturePreprocessorConfiguration.defaultMaxJumpDistance)
        #expect(config.smoothingWindow == GesturePreprocessorConfiguration.defaultSmoothingWindow)
    }

    @Test func configAppliesCustomValuesWhenExpertModeIsOn() {
        let store = storeWithCustomValues(expertModeEnabled: true)

        let config = GesturePreprocessorConfiguration.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == 9.0)
        #expect(config.maxJumpDistance == 90.0)
        #expect(config.smoothingWindow == 7)
    }

    @Test func configIgnoresCustomValuesWhenExpertModeKeyIsMissing() {
        let store = storeWithCustomValues(expertModeEnabled: false)
        store.removeObject(forKey: SettingsKey.expertModeEnabled.rawValue)

        let config = GesturePreprocessorConfiguration.fromUserDefaults(store: store)

        #expect(config.jitterThreshold == GesturePreprocessorConfiguration.defaultJitterThreshold)
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
        #expect(GesturePreprocessorConfiguration.fromUserDefaults(store: store).jitterThreshold
            == GesturePreprocessorConfiguration.defaultJitterThreshold)

        store.set(true, forKey: SettingsKey.expertModeEnabled.rawValue)
        #expect(GesturePreprocessorConfiguration.fromUserDefaults(store: store).jitterThreshold == 9.0)
        #expect(GesturePreprocessorConfiguration.fromUserDefaults(store: store).maxJumpDistance == 90.0)
    }
}
