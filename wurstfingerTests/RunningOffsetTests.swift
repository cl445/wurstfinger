//
//  RunningOffsetTests.swift
//  WurstfingerTests
//
//  Tests for the bounded-influence running-mean estimator (spec §4.2 Step 1).
//

import Foundation
import Testing
@testable import WurstfingerApp

struct RunningOffsetTests {
    private let cfg = TouchOffsetConfig.default

    @Test func convergesUnbiasedToConstantBias() {
        var o = RunningOffset(spreadPrior: cfg.spreadPrior)
        for _ in 0 ..< 300 {
            o.update(sample: 0.12, config: cfg)
        }
        #expect(abs(o.mean - 0.12) < 0.005)
    }

    @Test func huberClipBoundsSingleSampleInfluence() {
        var o = RunningOffset(spreadPrior: cfg.spreadPrior)
        // First sample is huge but should be clipped to ±c·spread, not jump to 5.
        o.update(sample: 5.0, config: cfg)
        #expect(o.mean <= cfg.huberC * cfg.spreadPrior + 1e-9)
    }

    @Test func outlierGateRejectsAfterWarmup() {
        var o = RunningOffset(spreadPrior: cfg.spreadPrior)
        for _ in 0 ..< cfg.warmup {
            o.update(sample: 0.0, config: cfg)
        }
        let before = o.mean
        let used = o.update(sample: 5.0, config: cfg)
        #expect(used == false)
        #expect(o.mean == before)
    }

    @Test func gateInactiveBeforeWarmup() {
        var o = RunningOffset(spreadPrior: cfg.spreadPrior)
        // First sample (count < warmup) is never gated, only clipped.
        let used = o.update(sample: 5.0, config: cfg)
        #expect(used == true)
    }

    @Test func nMaxGivesPlasticity() {
        // Small nMax → behaves like an EMA, old state gets overwritten.
        let plastic = TouchOffsetConfig(
            nMax: 5, huberC: 100, kGate: 100, betaMad: 0.05, warmup: 100,
            spreadPrior: 1.0, kappa: 8, clampFraction: 0.35, lambdaRidge: 8,
            interiorMargin: 0.10, applyOn: 12, applyOff: 6
        )
        var o = RunningOffset(spreadPrior: plastic.spreadPrior)
        for _ in 0 ..< 20 {
            o.update(sample: 0.0, config: plastic)
        }
        #expect(abs(o.mean) < 0.01)
        for _ in 0 ..< 50 {
            o.update(sample: 1.0, config: plastic)
        }
        #expect(o.mean > 0.9) // overwritten toward the new value
    }
}
