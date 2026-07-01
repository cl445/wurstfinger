//
//  TelemetryTests.swift
//  WurstfingerTests
//
//  Tests for gesture telemetry (§13) and the counterfactual benefit metric (§8).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct FeatureStatTests {
    @Test func welfordMeanAndStdDev() {
        var s = FeatureStat()
        [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0].forEach { s.add($0) }
        #expect(s.count == 8)
        #expect(abs(s.mean - 5.0) < 1e-9)
        // Sample std dev of that classic set is ~2.138 (variance 32/7).
        #expect(abs(s.stdDev - (32.0 / 7.0).squareRoot()) < 1e-9)
    }

    @Test func classKeyMapping() {
        #expect(TelemetryController.classKey(.tap, isReturn: false) == "tap")
        #expect(TelemetryController.classKey(.swipeUp, isReturn: false) == "swipe.swipeUp")
        #expect(TelemetryController.classKey(.tap, isReturn: true) == "return")
        #expect(TelemetryController.classKey(.circularClockwise, isReturn: false) == "circle.cw")
        #expect(TelemetryController.classKey(.circularCounterclockwise, isReturn: false) == "circle.ccw")
    }
}

struct FlipDetectionTests {
    @Test func centeredTapWithNoOffsetIsNotAFlip() {
        #expect(!TelemetryController.isFlip(touchdown: CGPoint(x: 0.5, y: 0.5), offset: .zero))
    }

    @Test func offsetPushingPastEdgeIsAFlip() {
        // touchdown + offset leaves [0,1] → an unshifted neighbor owned the tap.
        #expect(TelemetryController.isFlip(touchdown: CGPoint(x: 0.9, y: 0.5), offset: CGVector(dx: 0.2, dy: 0)))
        #expect(TelemetryController.isFlip(touchdown: CGPoint(x: 0.1, y: 0.5), offset: CGVector(dx: -0.2, dy: 0)))
        #expect(TelemetryController.isFlip(touchdown: CGPoint(x: 0.5, y: 0.95), offset: CGVector(dx: 0, dy: 0.1)))
    }

    @Test func offsetStayingInsideIsNotAFlip() {
        #expect(!TelemetryController.isFlip(touchdown: CGPoint(x: 0.6, y: 0.6), offset: CGVector(dx: 0.1, dy: 0.1)))
    }
}

struct TelemetryControllerTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .twoThumb)

    private func make(_ suite: String, enabled: Bool, window: Int = 3) -> TelemetryController {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return TelemetryController(
            store: GestureTelemetryStore(defaults: d),
            saveEvery: 1,
            window: window,
            isFeatureEnabled: { enabled },
            currentRegime: { regime }
        )
    }

    // MARK: - Per-class feature stats (§13)

    @Test func recordsClassStatsWhenEnabled() {
        let c = make("test.telemetry.enabled", enabled: true)
        c.recordGesture(.tap, isReturn: false, features: .empty())
        c.recordGesture(.tap, isReturn: false, features: .empty())
        let tap = c.snapshot.classes[regime.key]?["tap"]
        #expect(tap?.total == 2)
        #expect(tap?.features["maxDisplacement"]?.count == 2)
    }

    @Test func disabledSkipsClassStats() {
        let c = make("test.telemetry.disabled", enabled: false)
        c.recordGesture(.swipeUp, isReturn: false, features: .empty())
        #expect(c.snapshot.classes.isEmpty)
    }

    @Test func deleteChargesLastClass() {
        let c = make("test.telemetry.delete", enabled: true)
        c.recordGesture(.swipeUp, isReturn: false, features: .empty())
        c.recordUserDelete()
        #expect(c.snapshot.classes[regime.key]?["swipe.swipeUp"]?.corrections == 1)
    }

    @Test func classCorrectionRateComputes() {
        let c = make("test.telemetry.rate", enabled: true)
        for _ in 0 ..< 10 {
            c.recordGesture(.tap, isReturn: false, features: .empty())
        }
        c.recordUserDelete()
        #expect(abs((c.snapshot.classes[regime.key]?["tap"]?.correctionRate ?? 0) - 1.0 / 10.0) < 1e-9)
    }

    // MARK: - Counterfactual benefit (§8)

    @Test func keptFlipCountsAsCaught() {
        let c = make("test.telemetry.caught", enabled: true, window: 1)
        c.recordTapOutcome(regimeKey: regime.key, isFlip: true)
        // A later tap ages the flipped one out of the veto window (unvetoed).
        c.recordTapOutcome(regimeKey: regime.key, isFlip: false)
        let m = c.snapshot.counterfactual[regime.key]
        #expect(m?.taps == 1)
        #expect(m?.caught == 1)
        #expect(m?.caused == 0)
        #expect(m?.deletes == 0)
    }

    @Test func vetoedFlipCountsAsCaused() {
        let c = make("test.telemetry.caused", enabled: true, window: 1)
        c.recordTapOutcome(regimeKey: regime.key, isFlip: true)
        c.recordUserDelete() // vetoes the still-pending flip
        let m = c.snapshot.counterfactual[regime.key]
        #expect(m?.taps == 1)
        #expect(m?.deletes == 1)
        #expect(m?.caused == 1)
        #expect(m?.caught == 0)
    }

    @Test func nonFlipKeptTapCountsButAddsNoError() {
        let c = make("test.telemetry.noflip", enabled: true, window: 1)
        c.recordTapOutcome(regimeKey: regime.key, isFlip: false)
        c.recordTapOutcome(regimeKey: regime.key, isFlip: false) // ages the first out
        let m = c.snapshot.counterfactual[regime.key]
        #expect(m?.taps == 1)
        #expect(m?.deletes == 0)
        #expect(m?.caught == 0)
        #expect(m?.caused == 0)
    }

    // MARK: - Error-rate math (§8)

    @Test func errorRatesReflectCounterfactual() {
        var m = CounterfactualMetric()
        m.taps = 10
        m.deletes = 3 // observed backspaces with correction on
        m.caught = 2 // would-have-been errors the correction prevented
        m.caused = 1 // errors the correction introduced
        #expect(abs(m.errorRateWith - 0.3) < 1e-9) // 3 / 10
        #expect(abs(m.errorRateWithout - 0.4) < 1e-9) // (3 + 2 - 1) / 10
        #expect(m.net == 1)
    }

    @Test func emptyMetricHasZeroRates() {
        let m = CounterfactualMetric()
        #expect(m.errorRateWith == 0)
        #expect(m.errorRateWithout == 0)
    }

    // MARK: - Persistence

    @Test func persistsAcrossReload() throws {
        let suite = "test.telemetry.persist"
        let c = make(suite, enabled: true, window: 1)
        c.recordGesture(.tap, isReturn: false, features: .empty())
        c.recordTapOutcome(regimeKey: regime.key, isFlip: true)
        c.recordTapOutcome(regimeKey: regime.key, isFlip: false) // flush → caught
        c.persist()
        let d = try #require(UserDefaults(suiteName: suite))
        let reloaded = GestureTelemetryStore(defaults: d).load()
        #expect(reloaded.classes[regime.key]?["tap"]?.total == 1)
        #expect(reloaded.counterfactual[regime.key]?.caught == 1)
        #expect(reloaded.counterfactual[regime.key]?.taps == 1)
    }
}
