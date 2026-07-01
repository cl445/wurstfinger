//
//  TelemetryTests.swift
//  WurstfingerTests
//
//  Tests for gesture telemetry (§13) and the A/B proxy metric (§8).
//

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

struct TelemetryControllerTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .twoThumb)

    private func make(_ suite: String, enabled: Bool) -> TelemetryController {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return TelemetryController(
            store: GestureTelemetryStore(defaults: d),
            saveEvery: 1,
            isFeatureEnabled: { enabled },
            currentRegime: { regime }
        )
    }

    @Test func recordsClassStatsAndABWhenEnabled() {
        let c = make("test.telemetry.enabled", enabled: true)
        c.recordGesture(.tap, isReturn: false, features: .empty())
        c.recordGesture(.tap, isReturn: false, features: .empty())
        let tap = c.snapshot.classes[regime.key]?["tap"]
        #expect(tap?.total == 2)
        #expect(tap?.features["maxDisplacement"]?.count == 2)
        #expect(c.snapshot.abEnabled.total == 2)
        #expect(c.snapshot.abDisabled.total == 0)
    }

    @Test func disabledSkipsClassStatsButCountsAB() {
        let c = make("test.telemetry.disabled", enabled: false)
        c.recordGesture(.swipeUp, isReturn: false, features: .empty())
        #expect(c.snapshot.classes.isEmpty)
        #expect(c.snapshot.abDisabled.total == 1)
        #expect(c.snapshot.abEnabled.total == 0)
    }

    @Test func deleteChargesLastClassAndAB() {
        let c = make("test.telemetry.delete", enabled: true)
        c.recordGesture(.swipeUp, isReturn: false, features: .empty())
        c.recordUserDelete()
        #expect(c.snapshot.classes[regime.key]?["swipe.swipeUp"]?.corrections == 1)
        #expect(c.snapshot.abEnabled.corrections == 1)
    }

    @Test func correctionRateComputes() {
        let c = make("test.telemetry.rate", enabled: true)
        for _ in 0 ..< 10 {
            c.recordGesture(.tap, isReturn: false, features: .empty())
        }
        c.recordUserDelete()
        #expect(abs((c.snapshot.abEnabled.correctionRate) - 1.0 / 10.0) < 1e-9)
    }

    @Test func persistsAcrossReload() throws {
        let suite = "test.telemetry.persist"
        let c = make(suite, enabled: true)
        c.recordGesture(.tap, isReturn: false, features: .empty())
        c.persist()
        let d = try #require(UserDefaults(suiteName: suite))
        let reloaded = GestureTelemetryStore(defaults: d).load()
        #expect(reloaded.classes[regime.key]?["tap"]?.total == 1)
    }
}
