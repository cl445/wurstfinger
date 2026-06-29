//
//  KeyGestureClassificationTests.swift
//  WurstfingerTests
//
//  Tests for the pure classification functions of KeyGestureRecognizer:
//  `angleToGestureType` (angle → swipe direction) and `classify(features:)`
//  (tap / circular / directional dispatch). These need no SwiftUI rendering.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - Helpers

private enum GestureFixtures {
    /// Thresholds pinned for these tests, independent of the production
    /// defaults. Inputs below are derived from these so retuning the shipped
    /// classifier can't silently move a value across a branch boundary.
    static let thresholds = GestureClassificationThresholds(
        minSwipeLength: 20,
        maxReturnRatio: 0.5,
        returnDisplacementRange: 0.2 ... 0.8,
        minCircularity: 0.3,
        minAngularSpan: .pi * 1.5,
        minPathSeparation: 0.5,
        minTurnConsistency: 0.8,
        minOrientedCompactness: 0.4
    )

    /// Builds a `GestureFeatures` that classifies as a plain rightward swipe
    /// (not a tap, not circular, not a return). Override individual fields to
    /// target a specific branch of `classify(features:)`.
    static func features(
        thresholds: GestureClassificationThresholds = GestureFixtures.thresholds,
        maxDisplacement: CGFloat = 100,
        maxDisplacementProgress: CGFloat = 1.0,
        returnRatio: CGFloat = 1.0,
        maxDisplacementAngle: CGFloat = 0,
        angularSpan: CGFloat = 0,
        circularity: CGFloat = 0,
        turnConsistency: CGFloat = 0,
        orientedCompactness: CGFloat = 0,
        pathLength: CGFloat = 100
    ) -> GestureFeatures {
        GestureFeatures(
            thresholds: thresholds,
            pathLength: pathLength,
            chordLength: pathLength * returnRatio,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            maxDisplacement: maxDisplacement,
            maxDisplacementPoint: .zero,
            maxDisplacementProgress: maxDisplacementProgress,
            centroid: .zero,
            returnRatio: returnRatio,
            aspectRatio: 1,
            dominantAngle: maxDisplacementAngle,
            maxDisplacementAngle: maxDisplacementAngle,
            angularSpan: angularSpan,
            circularity: circularity,
            pathSeparation: 0,
            turnConsistency: turnConsistency,
            orientedCompactness: orientedCompactness
        )
    }
}

// MARK: - angleToGestureType

struct AngleToGestureTypeTests {
    @Test func mapsCardinalAndDiagonalSectors() {
        // atan2 convention: +x = right (0), +y = down. CGFloat radians.
        #expect(KeyGestureRecognizer.angleToGestureType(0) == .swipeRight)
        #expect(KeyGestureRecognizer.angleToGestureType(.pi / 4) == .swipeDownRight)
        #expect(KeyGestureRecognizer.angleToGestureType(.pi / 2) == .swipeDown)
        #expect(KeyGestureRecognizer.angleToGestureType(3 * .pi / 4) == .swipeDownLeft)
        #expect(KeyGestureRecognizer.angleToGestureType(.pi) == .swipeLeft)
    }

    @Test func normalizesNegativeAnglesForUpperSectors() {
        // atan2 returns -π...π, so the "up" half arrives as negative angles.
        #expect(KeyGestureRecognizer.angleToGestureType(-3 * .pi / 4) == .swipeUpLeft)
        #expect(KeyGestureRecognizer.angleToGestureType(-.pi / 2) == .swipeUp)
        #expect(KeyGestureRecognizer.angleToGestureType(-.pi / 4) == .swipeUpRight)
    }

    @Test func wrapsAroundToRightNearFullCircle() {
        // Slightly negative (≈ -5.7°) normalizes to ≈ 354° → right sector.
        #expect(KeyGestureRecognizer.angleToGestureType(-0.1) == .swipeRight)
    }
}

// MARK: - classify(features:)

struct KeyGestureClassifyFeaturesTests {
    @Test func tapWhenDisplacementBelowSwipeThreshold() {
        // Below the swipe threshold → tap.
        let features = GestureFixtures.features(maxDisplacement: GestureFixtures.thresholds.minSwipeLength / 2)
        let result = KeyGestureRecognizer.classify(features: features)

        #expect(result.gesture == .tap)
        #expect(!result.isReturn)
    }

    @Test func clockwiseCircle() {
        let features = GestureFixtures.features(
            angularSpan: GestureFixtures.thresholds.minAngularSpan + 0.5, // above threshold, positive → CW
            circularity: 1,
            turnConsistency: 1,
            orientedCompactness: 1,
            pathLength: 1000
        )
        let result = KeyGestureRecognizer.classify(features: features)

        #expect(result.gesture == .circularClockwise)
        #expect(!result.isReturn)
    }

    @Test func counterclockwiseCircle() {
        let features = GestureFixtures.features(
            angularSpan: -(GestureFixtures.thresholds.minAngularSpan + 0.5), // above threshold, negative → CCW
            circularity: 1,
            turnConsistency: 1,
            orientedCompactness: 1,
            pathLength: 1000
        )
        let result = KeyGestureRecognizer.classify(features: features)

        #expect(result.gesture == .circularCounterclockwise)
    }

    @Test func directionalSwipeIsNotReturn() {
        let features = GestureFixtures.features(
            returnRatio: 1.0, // straight line → not a return
            maxDisplacementAngle: .pi / 2 // downward
        )
        let result = KeyGestureRecognizer.classify(features: features)

        #expect(result.gesture == .swipeDown)
        #expect(!result.isReturn)
    }

    @Test func directionalReturnSwipeSetsReturnFlag() {
        let features = GestureFixtures.features(
            // peak mid-path, inside the return-displacement range
            maxDisplacementProgress: (GestureFixtures.thresholds.returnDisplacementRange.lowerBound
                + GestureFixtures.thresholds.returnDisplacementRange.upperBound) / 2,
            returnRatio: GestureFixtures.thresholds.maxReturnRatio / 2, // returned to start (< maxReturnRatio)
            maxDisplacementAngle: .pi // leftward
        )
        let result = KeyGestureRecognizer.classify(features: features)

        #expect(result.gesture == .swipeLeft)
        #expect(result.isReturn)
    }
}
