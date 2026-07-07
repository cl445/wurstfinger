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
        let config = GesturePreprocessorConfig.default.with(aspectRatio: aspectRatio)
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
