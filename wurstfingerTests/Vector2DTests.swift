//
//  Vector2DTests.swift
//  wurstfingerTests
//
//  Tests for Vector2D type and geometric operations
//

import Foundation
import Testing
@testable import WurstfingerApp

struct Vector2DTests {
    // MARK: - Initialization Tests

    @Test func initWithXY() {
        let v = Vector2D(x: 3, y: 4)
        #expect(v.x == 3)
        #expect(v.y == 4)
    }

    @Test func initFromPoints() {
        let start = CGPoint(x: 1, y: 2)
        let end = CGPoint(x: 4, y: 6)
        let v = Vector2D(from: start, to: end)

        #expect(v.x == 3)
        #expect(v.y == 4)
    }

    @Test func initRelativeToOrigin() {
        let point = CGPoint(x: 5, y: 10)
        let origin = CGPoint(x: 2, y: 3)
        let v = Vector2D(point: point, relativeTo: origin)

        #expect(v.x == 3)
        #expect(v.y == 7)
    }

    // MARK: - Magnitude Tests

    @Test func magnitudeOf345Triangle() {
        let v = Vector2D(x: 3, y: 4)
        #expect(v.magnitude == 5)
    }

    @Test func magnitudeSquaredAvoidsSqrt() {
        let v = Vector2D(x: 3, y: 4)
        #expect(v.magnitudeSquared == 25)
    }

    @Test func zeroVectorMagnitude() {
        let v = Vector2D.zero
        #expect(v.magnitude == 0)
    }

    // MARK: - Normalization Tests

    @Test func normalizedVectorHasMagnitudeOne() {
        let v = Vector2D(x: 3, y: 4)
        let n = v.normalized

        #expect(abs(n.magnitude - 1.0) < 0.0001)
    }

    @Test func normalizedPreservesDirection() {
        let v = Vector2D(x: 3, y: 4)
        let n = v.normalized

        // Ratio should be preserved
        #expect(abs(n.x / n.y - v.x / v.y) < 0.0001)
    }

    @Test func normalizedZeroVectorReturnsZero() {
        let v = Vector2D.zero
        let n = v.normalized

        #expect(n == Vector2D.zero)
    }

    // MARK: - Angle Tests

    @Test func angleOfRightwardVector() {
        let v = Vector2D(x: 1, y: 0)
        #expect(abs(v.angle) < 0.0001)
    }

    @Test func angleOfDownwardVector() {
        let v = Vector2D(x: 0, y: 1)
        #expect(abs(v.angle - .pi / 2) < 0.0001)
    }

    @Test func angleOfLeftwardVector() {
        let v = Vector2D(x: -1, y: 0)
        #expect(abs(abs(v.angle) - .pi) < 0.0001)
    }

    @Test func angleOfUpwardVector() {
        let v = Vector2D(x: 0, y: -1)
        #expect(abs(v.angle + .pi / 2) < 0.0001)
    }

    // MARK: - Dot Product Tests

    @Test func dotProductOfPerpendicularVectorsIsZero() {
        let v1 = Vector2D(x: 1, y: 0)
        let v2 = Vector2D(x: 0, y: 1)

        #expect(abs(v1.dot(v2)) < 0.0001)
    }

    @Test func dotProductOfParallelVectors() {
        let v1 = Vector2D(x: 2, y: 0)
        let v2 = Vector2D(x: 3, y: 0)

        #expect(v1.dot(v2) == 6)
    }

    @Test func dotProductOfOppositeVectors() {
        let v1 = Vector2D(x: 2, y: 0)
        let v2 = Vector2D(x: -3, y: 0)

        #expect(v1.dot(v2) == -6)
    }

    // MARK: - Cross Product Tests

    @Test func crossProductSignIndicatesRotation() {
        let v1 = Vector2D(x: 1, y: 0)
        let v2ccw = Vector2D(x: 0, y: 1) // counterclockwise from v1
        let v2cw = Vector2D(x: 0, y: -1) // clockwise from v1

        #expect(v1.cross(v2ccw) > 0) // CCW = positive
        #expect(v1.cross(v2cw) < 0) // CW = negative
    }

    @Test func crossProductOfParallelVectorsIsZero() {
        let v1 = Vector2D(x: 2, y: 4)
        let v2 = Vector2D(x: 4, y: 8) // parallel (same direction)

        #expect(abs(v1.cross(v2)) < 0.0001)
    }

    // MARK: - Angle To Tests

    @Test func angleToPerpendicularVector() {
        let v1 = Vector2D(x: 1, y: 0)
        let v2 = Vector2D(x: 0, y: 1)

        let angle = v1.angle(to: v2)
        #expect(abs(angle - .pi / 2) < 0.0001)
    }

    @Test func angleToSameDirectionIsZero() {
        let v1 = Vector2D(x: 1, y: 0)
        let v2 = Vector2D(x: 2, y: 0)

        let angle = v1.angle(to: v2)
        #expect(abs(angle) < 0.0001)
    }

    // MARK: - Distance Tests

    @Test func distanceBetweenVectors() {
        let v1 = Vector2D(x: 0, y: 0)
        let v2 = Vector2D(x: 3, y: 4)

        #expect(v1.distance(to: v2) == 5)
    }

    // MARK: - Operator Tests

    @Test func additionOperator() {
        let v1 = Vector2D(x: 1, y: 2)
        let v2 = Vector2D(x: 3, y: 4)
        let sum = v1 + v2

        #expect(sum.x == 4)
        #expect(sum.y == 6)
    }

    @Test func subtractionOperator() {
        let v1 = Vector2D(x: 5, y: 7)
        let v2 = Vector2D(x: 2, y: 3)
        let diff = v1 - v2

        #expect(diff.x == 3)
        #expect(diff.y == 4)
    }

    @Test func scalarMultiplication() {
        let v = Vector2D(x: 2, y: 3)
        let scaled = v * 2

        #expect(scaled.x == 4)
        #expect(scaled.y == 6)
    }

    @Test func scalarMultiplicationCommutative() {
        let v = Vector2D(x: 2, y: 3)
        let scaled1 = v * 2
        let scaled2 = 2 * v

        #expect(scaled1 == scaled2)
    }

    @Test func scalarDivision() {
        let v = Vector2D(x: 6, y: 8)
        let divided = v / 2

        #expect(divided.x == 3)
        #expect(divided.y == 4)
    }

    @Test func negationOperator() {
        let v = Vector2D(x: 3, y: -4)
        let neg = -v

        #expect(neg.x == -3)
        #expect(neg.y == 4)
    }

    // MARK: - Rotation Tests

    @Test func rotate90Degrees() {
        let v = Vector2D(x: 1, y: 0)
        let rotated = v.rotated(by: .pi / 2)

        #expect(abs(rotated.x) < 0.0001)
        #expect(abs(rotated.y - 1) < 0.0001)
    }

    @Test func rotate180Degrees() {
        let v = Vector2D(x: 1, y: 0)
        let rotated = v.rotated(by: .pi)

        #expect(abs(rotated.x + 1) < 0.0001)
        #expect(abs(rotated.y) < 0.0001)
    }

    // MARK: - Projection Tests

    @Test func projectOntoParallelVector() {
        let v = Vector2D(x: 3, y: 4)
        let onto = Vector2D(x: 1, y: 0)
        let proj = v.projected(onto: onto)

        #expect(proj.x == 3)
        #expect(abs(proj.y) < 0.0001)
    }

    @Test func projectOntoPerpendicularVector() {
        let v = Vector2D(x: 0, y: 5)
        let onto = Vector2D(x: 1, y: 0)
        let proj = v.projected(onto: onto)

        #expect(abs(proj.x) < 0.0001)
        #expect(abs(proj.y) < 0.0001)
    }

    // MARK: - CGPoint Conversion Tests

    @Test func convertToCGPoint() {
        let v = Vector2D(x: 3, y: 4)
        let point = v.asCGPoint

        #expect(point.x == 3)
        #expect(point.y == 4)
    }
}
