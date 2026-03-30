//
//  KeyboardDirectionTests.swift
//  WurstfingerTests
//
//  Tests for KeyboardDirection.direction(for:tolerance:aspectRatio:)
//

import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardDirectionTests {
    // MARK: - Cardinal Directions

    @Test func centerWhenBelowThreshold() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 3, height: 3),
            tolerance: 10
        )
        #expect(direction == .center)
    }

    @Test func downDirection() {
        // atan2(dx=0, dy=50) = 0° → down
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 0, height: 50),
            tolerance: 10
        )
        #expect(direction == .down)
    }

    @Test func upDirection() {
        // atan2(dx=0, dy=-50) = 180° → up
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 0, height: -50),
            tolerance: 10
        )
        #expect(direction == .up)
    }

    @Test func rightDirection() {
        // atan2(dx=50, dy=0) = 90° → right
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 50, height: 0),
            tolerance: 10
        )
        #expect(direction == .right)
    }

    @Test func leftDirection() {
        // atan2(dx=-50, dy=0) = 270° → left
        let direction = KeyboardDirection.direction(
            for: CGSize(width: -50, height: 0),
            tolerance: 10
        )
        #expect(direction == .left)
    }

    // MARK: - Diagonal Directions

    @Test func downRightDirection() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 50, height: 50),
            tolerance: 10
        )
        #expect(direction == .downRight)
    }

    @Test func upRightDirection() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 50, height: -50),
            tolerance: 10
        )
        #expect(direction == .upRight)
    }

    @Test func downLeftDirection() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: -50, height: 50),
            tolerance: 10
        )
        #expect(direction == .downLeft)
    }

    @Test func upLeftDirection() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: -50, height: -50),
            tolerance: 10
        )
        #expect(direction == .upLeft)
    }

    // MARK: - Boundary Values (half-open ranges)

    @Test func justBelow22_5DegIsDown() {
        // Just below the 22.5° boundary stays in the .down bucket (0..<22.5)
        let epsilon: CGFloat = 1e-4
        let angle = (22.5 - epsilon) * .pi / 180
        let dx = sin(angle) * 50
        let dy = cos(angle) * 50
        let direction = KeyboardDirection.direction(
            for: CGSize(width: dx, height: dy),
            tolerance: 10
        )
        #expect(direction == .down)
    }

    @Test func justAbove22_5DegIsDownRight() {
        // Just above the 22.5° boundary enters the .downRight bucket (22.5..<67.5)
        let epsilon: CGFloat = 1e-4
        let angle = (22.5 + epsilon) * .pi / 180
        let dx = sin(angle) * 50
        let dy = cos(angle) * 50
        let direction = KeyboardDirection.direction(
            for: CGSize(width: dx, height: dy),
            tolerance: 10
        )
        #expect(direction == .downRight)
    }

    @Test func justBelow67_5DegIsDownRight() {
        // Just below the 67.5° boundary stays in the .downRight bucket
        let epsilon: CGFloat = 1e-4
        let angle = (67.5 - epsilon) * .pi / 180
        let dx = sin(angle) * 50
        let dy = cos(angle) * 50
        let direction = KeyboardDirection.direction(
            for: CGSize(width: dx, height: dy),
            tolerance: 10
        )
        #expect(direction == .downRight)
    }

    @Test func justAbove67_5DegIsRight() {
        // Just above the 67.5° boundary enters the .right bucket (67.5..<112.5)
        let epsilon: CGFloat = 1e-4
        let angle = (67.5 + epsilon) * .pi / 180
        let dx = sin(angle) * 50
        let dy = cos(angle) * 50
        let direction = KeyboardDirection.direction(
            for: CGSize(width: dx, height: dy),
            tolerance: 10
        )
        #expect(direction == .right)
    }

    // MARK: - Aspect Ratio Compensation

    @Test func aspectRatioCompensation() {
        // With aspect ratio > 1 (wider keys), horizontal movement is divided
        // This means a 45° swipe becomes more vertical → direction changes
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 30, height: 30),
            tolerance: 10,
            aspectRatio: 3.0
        )
        // dx is divided by 3, so effective movement is (10, 30)
        // atan2(10, 30) ≈ 18.4° → falls in .down sector (0..<22.5)
        #expect(direction == .down)
    }

    @Test func squareAspectRatioPreserves45DegAngle() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 30, height: 30),
            tolerance: 10,
            aspectRatio: 1.0
        )
        #expect(direction == .downRight)
    }

    // MARK: - Tolerance Threshold

    @Test func exactlyAtToleranceIsCenter() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 10, height: 0),
            tolerance: 10
        )
        #expect(direction == .center)
    }

    @Test func justAboveToleranceIsNotCenter() {
        let direction = KeyboardDirection.direction(
            for: CGSize(width: 11, height: 0),
            tolerance: 10
        )
        #expect(direction != .center)
    }
}
