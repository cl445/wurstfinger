//
//  GeometryUtilsTests.swift
//  wurstfingerTests
//
//  Tests for CGPoint, CGSize, and CGRect extensions in GeometryUtils
//

import Foundation
import Testing
@testable import WurstfingerApp

struct CGPointExtensionTests {
    // MARK: - Distance Tests

    @Test func distanceToSamePoint() {
        let p = CGPoint(x: 5, y: 10)
        #expect(p.distance(to: p) == 0)
    }

    @Test func distanceHorizontal() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 10, y: 0)
        #expect(p1.distance(to: p2) == 10)
    }

    @Test func distanceVertical() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 0, y: 10)
        #expect(p1.distance(to: p2) == 10)
    }

    @Test func distanceDiagonal345() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 3, y: 4)
        #expect(p1.distance(to: p2) == 5)
    }

    @Test func distanceIsSymmetric() {
        let p1 = CGPoint(x: 1, y: 2)
        let p2 = CGPoint(x: 5, y: 7)
        #expect(p1.distance(to: p2) == p2.distance(to: p1))
    }

    // MARK: - Magnitude Tests

    @Test func magnitudeOfOrigin() {
        let p = CGPoint.zero
        #expect(p.magnitude() == 0)
    }

    @Test func magnitudeOf345() {
        let p = CGPoint(x: 3, y: 4)
        #expect(p.magnitude() == 5)
    }

    @Test func magnitudeWithNegativeCoordinates() {
        let p = CGPoint(x: -3, y: -4)
        #expect(p.magnitude() == 5)
    }

    // MARK: - Vector Conversion Tests

    @Test func asVectorConvertsCorrectly() {
        let p = CGPoint(x: 3, y: 4)
        let v = p.asVector

        #expect(v.x == 3)
        #expect(v.y == 4)
    }

    @Test func vectorToPoint() {
        let p1 = CGPoint(x: 1, y: 2)
        let p2 = CGPoint(x: 4, y: 6)
        // Use Vector2D initializer directly to avoid potential ambiguity
        let v = Vector2D(from: p1, to: p2)

        #expect(v.x == 3)
        #expect(v.y == 4)
    }
}

struct CGSizeExtensionTests {
    @Test func aspectRatioOfSquare() {
        let size = CGSize(width: 100, height: 100)
        #expect(size.aspectRatio == 1.0)
    }

    @Test func aspectRatioWideRectangle() {
        let size = CGSize(width: 200, height: 100)
        #expect(size.aspectRatio == 2.0)
    }

    @Test func aspectRatioTallRectangle() {
        let size = CGSize(width: 100, height: 200)
        #expect(size.aspectRatio == 0.5)
    }

    @Test func aspectRatioWithZeroHeight() {
        let size = CGSize(width: 100, height: 0)
        #expect(size.aspectRatio == 1) // Default when height is 0
    }
}

struct CGRectExtensionTests {
    @Test func centerOfRect() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let center = rect.center

        #expect(center.x == 50)
        #expect(center.y == 50)
    }

    @Test func centerOfOffsetRect() {
        let rect = CGRect(x: 20, y: 30, width: 100, height: 200)
        let center = rect.center

        #expect(center.x == 70) // 20 + 100/2
        #expect(center.y == 130) // 30 + 200/2
    }

    @Test func aspectRatioOfSquareRect() {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        #expect(rect.aspectRatio == 1.0)
    }

    @Test func aspectRatioOfWideRect() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(rect.aspectRatio == 2.0)
    }

    @Test func aspectRatioWithZeroHeight() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 0)
        #expect(rect.aspectRatio == 1) // Default when height is 0
    }
}
