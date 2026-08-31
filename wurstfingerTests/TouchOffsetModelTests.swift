//
//  TouchOffsetModelTests.swift
//  WurstfingerTests
//
//  Tests for the Empirical-Bayes touch-offset model (spec §4.2): convergence,
//  shrinkage, clamp, split surface, no-drift.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct TouchOffsetModelTests {
    private let oneThumb = TouchRegime(orientation: .portrait, posture: .oneThumbLeft)
    private let twoThumb = TouchRegime(orientation: .portrait, posture: .twoThumb)

    private func magnitude(_ v: CGVector) -> Double {
        (v.dx * v.dx + v.dy * v.dy).squareRoot()
    }

    @Test func emptyModelReturnsZero() {
        let model = TouchOffsetModel(regime: oneThumb)
        #expect(model.offset(forKeyId: "missing") == .zero)
    }

    @Test func singleSampleNearZeroStaysSmall() {
        var model = TouchOffsetModel(regime: oneThumb)
        model.learn(keyId: "A", posU: 0.5, posV: 0.5, sampleX: 0, sampleY: 0)
        #expect(magnitude(model.offset(forKeyId: "A")) < 0.01)
    }

    @Test func convergesToConstantBias() {
        var model = TouchOffsetModel(regime: oneThumb)
        for _ in 0 ..< 300 {
            model.learn(keyId: "A", posU: 0.5, posV: 0.5, sampleX: 0.15, sampleY: -0.10)
        }
        let off = model.offset(forKeyId: "A")
        #expect(abs(off.dx - 0.15) < 0.02)
        #expect(abs(off.dy - -0.10) < 0.02)
    }

    @Test func sparseKeyIsShrunkTowardSurface() {
        var model = TouchOffsetModel(regime: oneThumb)
        // One sample with a strong mean → heavily shrunk (n=1, κ=8).
        model.learn(keyId: "A", posU: 0.5, posV: 0.5, sampleX: 0.30, sampleY: 0)
        #expect(magnitude(model.offset(forKeyId: "A")) < 0.15)
    }

    @Test func offsetIsClamped() {
        var model = TouchOffsetModel(regime: oneThumb)
        for _ in 0 ..< 500 {
            model.learn(keyId: "A", posU: 0.5, posV: 0.5, sampleX: 0.5, sampleY: 0.5)
        }
        let m = magnitude(model.offset(forKeyId: "A"))
        #expect(m <= TouchOffsetConfig.default.clampFraction + 1e-6)
        #expect(m > 0.25) // it did grow substantially before clamping
    }

    @Test func clampMagnitudeStaticScalesDown() {
        let clamped = TouchOffsetModel.clampMagnitude(CGVector(dx: 0.5, dy: 0.5), maxMagnitude: 0.35)
        #expect(abs(magnitude(clamped) - 0.35) < 1e-9)
    }

    @Test func splitSurfaceKeepsHalvesIndependent() {
        var model = TouchOffsetModel(regime: twoThumb)
        for _ in 0 ..< 300 {
            model.learn(keyId: "L", posU: 0.2, posV: 0.5, sampleX: 0.20, sampleY: 0)
            model.learn(keyId: "R", posU: 0.8, posV: 0.5, sampleX: -0.20, sampleY: 0)
        }
        let offsets = model.allOffsets()
        #expect((offsets["L"]?.dx ?? 0) > 0.1)
        #expect((offsets["R"]?.dx ?? 0) < -0.1)
    }

    @Test func repeatedApplicationDoesNotDrift() {
        // Pure model learns against the supplied (fixed-geometry) sample, so a
        // constant sample converges and stays — no self-reinforcement (§4.1).
        var model = TouchOffsetModel(regime: oneThumb)
        for _ in 0 ..< 500 {
            model.learn(keyId: "A", posU: 0.5, posV: 0.5, sampleX: 0.10, sampleY: 0.10)
        }
        let off = model.offset(forKeyId: "A")
        #expect(abs(off.dx - 0.10) < 0.02)
        #expect(abs(off.dy - 0.10) < 0.02)
    }
}
