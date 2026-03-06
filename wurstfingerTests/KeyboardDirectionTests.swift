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

    @Test func boundaryAt22_5DegIsDown() {
        // Angle exactly at 22.5° should be in .down (default case, not downRight)
        // Actually: at exactly 22.5, the range 22.5..<67.5 includes 22.5, so it is downRight
        let angle = 22.5 * .pi / 180
        let dx = sin(angle) * 50
        let dy = cos(angle) * 50
        let direction = KeyboardDirection.direction(
            for: CGSize(width: dx, height: dy),
            tolerance: 10
        )
        #expect(direction == .downRight)
    }

    @Test func boundaryAt67_5DegIsRight() {
        // Angle exactly at 67.5° should be .right (start of 67.5..<112.5)
        let angle = 67.5 * .pi / 180
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
