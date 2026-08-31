//
//  GesturePreprocessorRobustnessTests.swift
//  WurstfingerTests
//
//  Robustness tests for the gesture input path: degenerate and adversarial
//  point sequences (empty, single, identical, non-finite, huge jumps, paths
//  longer than the position buffer) must classify without trapping.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct GesturePreprocessorRobustnessTests {
    private func classify(_ points: [CGPoint]) -> GestureType {
        // Explicit configs keep the test hermetic — independent of whatever
        // is in the shared defaults store on the test host.
        KeyGestureRecognizer.classify(positions: points, config: .default, thresholds: .default).gesture
    }

    @Test func emptyInputClassifiesAsTap() {
        #expect(classify([]) == .tap)
    }

    @Test func singlePointClassifiesAsTap() {
        #expect(classify([CGPoint(x: 7, y: 7)]) == .tap)
    }

    @Test func repeatedIdenticalPointsClassifyAsTap() {
        let points = Array(repeating: CGPoint(x: 12, y: 34), count: 80)
        #expect(classify(points) == .tap)
    }

    @Test func nonFiniteCoordinatesDoNotCrash() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: CGFloat.nan, y: 10),
            CGPoint(x: CGFloat.infinity, y: -CGFloat.infinity),
            CGPoint(x: 20, y: CGFloat.nan),
        ]
        // Must return some valid gesture rather than trapping.
        #expect(GestureType.allCases.contains(classify(points)))
    }

    @Test func hugeCoordinateJumpsDoNotCrash() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1_000_000, y: -1_000_000),
            CGPoint(x: -5_000_000, y: 3_000_000),
            CGPoint(x: 0, y: 0),
        ]
        #expect(GestureType.allCases.contains(classify(points)))
    }

    @Test func fastSwipeWithDroppedFrameGapClassifiesAsSwipe() {
        // One inter-sample gap > maxJumpDistance (50pt default, e.g. from a
        // dropped frame) must not discard the tail of a genuine fast flick
        // and demote it to a tap.
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 80, y: 0),
            CGPoint(x: 95, y: 0),
        ]
        #expect(classify(points) == .swipeRight)
    }

    /// A fling fast enough that no two consecutive samples are within
    /// maxJumpDistance of each other used to have every sample dropped as a
    /// teleport, leaving a single-point path that classifies as a tap — so the
    /// key committed its center letter for an unmistakable swipe.
    @Test func flickFasterThanTheJumpThresholdStaysASwipe() {
        // ~0.5 m/s delivered at 60 Hz ≈ 53pt between samples (the threshold is
        // 50pt), straight down the key.
        let points = (0 ... 4).map { CGPoint(x: 0, y: CGFloat($0) * 53) }
        #expect(classify(points) == .swipeDown)
    }

    /// The gesture trail draws the *raw* touch path while the classifier
    /// consumes the filtered one. When they disagree the user watches a full
    /// swipe comet and gets the center letter — the divergence that made this
    /// failure mode invisible in the first place. Pinned for the flick that
    /// used to diverge, through a real `GestureTrail` at the production
    /// spacing and capacity rather than a copy of its retention rule: what the
    /// overlay keeps is what the classifier has to agree with.
    @Test func aFlickTheTrailDrawsInFullIsNotClassifiedAsATap() {
        let points = (0 ... 4).map { CGPoint(x: CGFloat($0) * 53, y: 0) }

        var trail = GestureTrail()
        trail.begin(at: points[0], time: 0)
        for (index, point) in points.enumerated().dropFirst() {
            trail.extend(to: point, time: TimeInterval(index) / 60)
        }

        // The overlay draws the whole stroke…
        #expect(trail.samples.map(\.point) == points)
        // …so the classification must be the swipe the user saw.
        #expect(classify(points) == .swipeRight)
    }

    @Test func pathLongerThanPositionBufferStaysClassifiable() {
        // More samples than KeyboardConstants.Gesture.positionBufferSize
        // (120), a straight rightward drag — must still classify as a right
        // swipe.
        let points = (0 ... 500).map { CGPoint(x: CGFloat($0), y: 0) }
        #expect(classify(points) == .swipeRight)
    }

    @Test(arguments: [CGFloat.zero, -2, .nan, .infinity])
    func invalidAspectRatioFallsBackInsteadOfPoisoningClassification(aspectRatio: CGFloat) {
        // The aspect ratio reaches the preprocessor via a raw @AppStorage
        // read; a zero/non-finite stored value used to turn normalization
        // into NaN so that every gesture classified as .swipeRight. It must
        // fall back to 1.0 and classify this clean up-swipe correctly.
        let config = GesturePreprocessorConfiguration.default.with(aspectRatio: aspectRatio)
        let points = (0 ... 15).map { CGPoint(x: 0, y: CGFloat($0) * -4) }
        let result = KeyGestureRecognizer.classify(
            positions: points, config: config, thresholds: .default
        )
        #expect(result.gesture == .swipeUp)
    }

    @Test func preprocessHandlesDegenerateInput() {
        let preprocessor = GesturePreprocessor()
        #expect(preprocessor.preprocess([]).isEmpty)

        let single = [CGPoint(x: 1, y: 2)]
        #expect(preprocessor.preprocess(single) == single)
    }

    @Test func featureExtractionOnEmptyInputIsTap() {
        let features = GestureFeatures.extract(from: [])
        #expect(features.isTap)
        #expect(!features.isCircular)
    }
}

// MARK: - Expert-mode store values

/// A stale or foreign value in the shared store must not reach classification:
/// every expert value is clamped to the range the Expert UI offers.
struct ExpertValueClampingTests {
    private func expertStore() -> InMemoryUserDefaults {
        let store = InMemoryUserDefaults()
        store.set(true, forKey: SettingsKey.expertModeEnabled.rawValue)
        return store
    }

    @Test func nonPositiveMinSwipeLengthCannotTurnEveryTouchIntoASwipe() {
        let store = expertStore()
        store.set(0.0, forKey: GestureClassificationThresholds.minSwipeLengthKey)
        let thresholds = GestureClassificationThresholds.fromUserDefaults(store: store)
        #expect(thresholds.minSwipeLength
            == CGFloat(GestureClassificationThresholds.minSwipeLengthRange.lowerBound))
        let result = KeyGestureRecognizer.classify(
            positions: [.zero, CGPoint(x: 2, y: 1)], config: .default, thresholds: thresholds
        )
        #expect(result.gesture == .tap)
    }

    @Test func storeValuesAboveTheExpertRangeClampToItsUpperBound() {
        let store = expertStore()
        store.set(9999.0, forKey: GesturePreprocessorConfiguration.jitterThresholdKey)
        store.set(9999.0, forKey: GesturePreprocessorConfiguration.maxJumpDistanceKey)
        store.set(99, forKey: GesturePreprocessorConfiguration.smoothingWindowKey)
        store.set(9999.0, forKey: GestureClassificationThresholds.minSwipeLengthKey)
        store.set(9999.0, forKey: GestureClassificationThresholds.maxReturnRatioKey)
        store.set(9999.0, forKey: GestureClassificationThresholds.minCircularityKey)
        let config = GesturePreprocessorConfiguration.fromUserDefaults(store: store)
        let thresholds = GestureClassificationThresholds.fromUserDefaults(store: store)
        #expect(config.jitterThreshold == CGFloat(GesturePreprocessorConfiguration.jitterThresholdRange.upperBound))
        #expect(config.maxJumpDistance == CGFloat(GesturePreprocessorConfiguration.maxJumpDistanceRange.upperBound))
        #expect(config.smoothingWindow == GesturePreprocessorConfiguration.smoothingWindowRange.upperBound)
        #expect(thresholds.minSwipeLength
            == CGFloat(GestureClassificationThresholds.minSwipeLengthRange.upperBound))
        #expect(thresholds.maxReturnRatio
            == CGFloat(GestureClassificationThresholds.maxReturnRatioRange.upperBound))
        #expect(thresholds.minCircularity
            == CGFloat(GestureClassificationThresholds.minCircularityRange.upperBound))
    }

    @Test func negativeStoreValuesClampToTheExpertLowerBound() {
        let store = expertStore()
        store.set(-5.0, forKey: GesturePreprocessorConfiguration.jitterThresholdKey)
        store.set(-5.0, forKey: GesturePreprocessorConfiguration.maxJumpDistanceKey)
        store.set(-5, forKey: GesturePreprocessorConfiguration.smoothingWindowKey)
        let config = GesturePreprocessorConfiguration.fromUserDefaults(store: store)
        #expect(config.jitterThreshold == CGFloat(GesturePreprocessorConfiguration.jitterThresholdRange.lowerBound))
        #expect(config.maxJumpDistance == CGFloat(GesturePreprocessorConfiguration.maxJumpDistanceRange.lowerBound))
        #expect(config.smoothingWindow == GesturePreprocessorConfiguration.smoothingWindowRange.lowerBound)
    }

    @Test func evenSmoothingWindowStillRoundsUpInsideTheRange() {
        let store = expertStore()
        store.set(10, forKey: GesturePreprocessorConfiguration.smoothingWindowKey)
        #expect(GesturePreprocessorConfiguration.fromUserDefaults(store: store).smoothingWindow == 11)
    }

    @Test func nonFiniteStoreValueStillFallsBackToTheDefault() {
        let store = expertStore()
        store.set(Double.nan, forKey: GestureClassificationThresholds.minSwipeLengthKey)
        store.set(Double.infinity, forKey: GesturePreprocessorConfiguration.jitterThresholdKey)
        #expect(GestureClassificationThresholds.fromUserDefaults(store: store).minSwipeLength
            == GestureClassificationThresholds.defaultMinSwipeLength)
        #expect(GesturePreprocessorConfiguration.fromUserDefaults(store: store).jitterThreshold
            == GesturePreprocessorConfiguration.defaultJitterThreshold)
    }
}
