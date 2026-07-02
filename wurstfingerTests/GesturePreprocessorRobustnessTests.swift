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

    @Test func pathLongerThanPositionBufferStaysClassifiable() {
        // More samples than KeyboardConstants.Gesture.positionBufferSize (60),
        // a straight rightward drag — must still classify as a right swipe.
        let points = (0 ... 500).map { CGPoint(x: CGFloat($0), y: 0) }
        #expect(classify(points) == .swipeRight)
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
