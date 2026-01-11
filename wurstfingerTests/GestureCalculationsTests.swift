//
//  GestureCalculationsTests.swift
//  wurstfingerTests
//
//  Tests for GestureCalculations helper functions
//

import Foundation
import Testing
@testable import WurstfingerApp

struct GestureCalculationsTests {

    // MARK: - Path Length Tests

    @Test func pathLengthOfStraightLine() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 30, y: 0)
        ]

        let length = GestureCalculations.pathLength(of: points)
        #expect(length == 30)
    }

    @Test func pathLengthOfDiagonal() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 3, y: 4)  // 3-4-5 triangle
        ]

        let length = GestureCalculations.pathLength(of: points)
        #expect(length == 5)
    }

    @Test func pathLengthOfEmptyArray() {
        let length = GestureCalculations.pathLength(of: [])
        #expect(length == 0)
    }

    @Test func pathLengthOfSinglePoint() {
        let length = GestureCalculations.pathLength(of: [CGPoint(x: 5, y: 5)])
        #expect(length == 0)
    }

    // MARK: - Chord Length Tests

    @Test func chordLengthIgnoresMiddlePoints() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),  // ignored
            CGPoint(x: -50, y: -50),  // ignored
            CGPoint(x: 30, y: 40)     // end point
        ]

        let chord = GestureCalculations.chordLength(of: points)
        #expect(chord == 50)  // distance from (0,0) to (30,40)
    }

    @Test func chordLengthOfReturnPath() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 5, y: 0)  // returned near start
        ]

        let chord = GestureCalculations.chordLength(of: points)
        #expect(chord == 5)
    }

    // MARK: - Bounding Box Tests

    @Test func boundingBoxOfPoints() {
        let points: [CGPoint] = [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 50, y: 30),
            CGPoint(x: 30, y: 80)
        ]

        let bbox = GestureCalculations.boundingBox(of: points)

        #expect(bbox.minX == 10)
        #expect(bbox.minY == 20)
        #expect(bbox.maxX == 50)
        #expect(bbox.maxY == 80)
        #expect(bbox.width == 40)
        #expect(bbox.height == 60)
    }

    @Test func boundingBoxOfEmptyArray() {
        let bbox = GestureCalculations.boundingBox(of: [])
        #expect(bbox == .zero)
    }

    // MARK: - Centroid Tests

    @Test func centroidOfTriangle() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 15, y: 30)
        ]

        let centroid = GestureCalculations.centroid(of: points)

        #expect(centroid.x == 15)
        #expect(centroid.y == 10)
    }

    @Test func centroidOfSinglePoint() {
        let points = [CGPoint(x: 10, y: 20)]
        let centroid = GestureCalculations.centroid(of: points)

        #expect(centroid.x == 10)
        #expect(centroid.y == 20)
    }

    @Test func centroidOfEmptyArray() {
        let centroid = GestureCalculations.centroid(of: [])
        #expect(centroid == .zero)
    }

    // MARK: - Max Displacement Tests

    @Test func maxDisplacementAtEnd() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 30, y: 0)
        ]

        let result = GestureCalculations.maxDisplacement(in: points)

        #expect(result.distance == 30)
        #expect(result.point == CGPoint(x: 30, y: 0))
        #expect(result.index == 3)
        #expect(result.progress == 1.0)
    }

    @Test func maxDisplacementInMiddle() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 50, y: 0),  // max displacement
            CGPoint(x: 30, y: 0),
            CGPoint(x: 10, y: 0)
        ]

        let result = GestureCalculations.maxDisplacement(in: points)

        #expect(result.distance == 50)
        #expect(result.point == CGPoint(x: 50, y: 0))
        #expect(result.index == 2)
        #expect(result.progress == 0.5)
    }

    // MARK: - Angular Span Tests

    @Test func angularSpanOfStraightLine() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0)
        ]
        let centroid = GestureCalculations.centroid(of: points)
        let span = GestureCalculations.angularSpan(of: points, around: centroid)

        // Straight line has minimal angular span
        #expect(abs(span) < 0.5)
    }

    @Test func angularSpanOfCircle() {
        // Create points in a circle
        var points: [CGPoint] = []
        let center = CGPoint(x: 50, y: 50)
        let radius: CGFloat = 30

        for i in 0..<20 {
            let angle = CGFloat(i) * .pi * 2 / 20
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        let centroid = GestureCalculations.centroid(of: points)
        let span = GestureCalculations.angularSpan(of: points, around: centroid)

        // Full circle should have span close to 2π
        #expect(abs(span) > .pi * 1.8)
    }

    // MARK: - Circularity Tests

    @Test func circularityOfPerfectCircle() {
        var points: [CGPoint] = []
        let center = CGPoint(x: 0, y: 0)
        let radius: CGFloat = 50

        for i in 0..<36 {
            let angle = CGFloat(i) * .pi * 2 / 36
            points.append(CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        let circularity = GestureCalculations.circularity(of: points, centroid: center)

        // Perfect circle should have high circularity
        #expect(circularity > 0.95)
    }

    @Test func circularityOfStraightLine() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 25, y: 0),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 75, y: 0),
            CGPoint(x: 100, y: 0)
        ]
        let centroid = GestureCalculations.centroid(of: points)
        let circularity = GestureCalculations.circularity(of: points, centroid: centroid)

        // Straight line should have low circularity
        #expect(circularity < 0.5)
    }

    // MARK: - Path Separation Tests

    @Test func pathSeparationOfReturnSwipe() {
        // Return swipe: out and back
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 0, y: 0)
        ]

        let maxDisp = GestureCalculations.maxDisplacement(in: points).distance
        let separation = GestureCalculations.pathSeparation(of: points, maxDisplacement: maxDisp)

        // Return swipe: mirrored points are close together
        #expect(separation < 0.3)
    }

    @Test func pathSeparationOfSpiral() {
        // Spiral: points expand outward
        var points: [CGPoint] = []
        for i in 0..<20 {
            let angle = CGFloat(i) * .pi / 5
            let radius = 5.0 + CGFloat(i) * 3.0
            points.append(CGPoint(
                x: radius * cos(angle),
                y: radius * sin(angle)
            ))
        }

        let maxDisp = GestureCalculations.maxDisplacement(in: points).distance
        let separation = GestureCalculations.pathSeparation(of: points, maxDisplacement: maxDisp)

        // Spiral: mirrored points are far apart
        #expect(separation > 0.5)
    }

    // MARK: - Turn Consistency Tests

    @Test func turnConsistencyOfCircle() {
        var points: [CGPoint] = []
        let center = CGPoint(x: 0, y: 0)
        let radius: CGFloat = 50

        for i in 0..<20 {
            let angle = CGFloat(i) * .pi * 2 / 20
            points.append(CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        let consistency = GestureCalculations.turnConsistency(of: points)

        // Circle: all turns in same direction
        #expect(consistency > 0.9)
    }

    @Test func turnConsistencyOfZigZag() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 30, y: 10),
            CGPoint(x: 40, y: 0)
        ]

        let consistency = GestureCalculations.turnConsistency(of: points)

        // Zig-zag: alternating turns
        #expect(consistency < 0.7)
    }

    // MARK: - Oriented Compactness Tests

    @Test func orientedCompactnessOfSquare() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 0, y: 50)
        ]

        let compactness = GestureCalculations.orientedCompactness(of: points, principalAngle: 0)

        // Square-ish shape should have high compactness
        #expect(compactness > 0.8)
    }

    @Test func orientedCompactnessOfNarrowLine() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 25, y: 1),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 75, y: 1),
            CGPoint(x: 100, y: 0)
        ]

        let compactness = GestureCalculations.orientedCompactness(of: points, principalAngle: 0)

        // Narrow line should have low compactness
        #expect(compactness < 0.2)
    }
}
