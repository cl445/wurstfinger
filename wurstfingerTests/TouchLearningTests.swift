//
//  TouchLearningTests.swift
//  WurstfingerTests
//
//  Tests for the acceptance filter and the learning controller (spec §4.1, §5).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct AcceptanceTrackerTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .twoThumb)
    private func tap(_ id: String) -> PendingTap {
        PendingTap(keyId: id, touchdown: CGPoint(x: 0.5, y: 0.5), regime: regime)
    }

    private func swipe(_ sector: GestureType) -> PendingSwipe {
        PendingSwipe(sector: sector, residual: 0.1, regime: regime)
    }

    @Test func holdsTapsWithinWindow() {
        let t = AcceptanceTracker<PendingTap>(window: 2)
        #expect(t.record(tap("A")).isEmpty)
        #expect(t.record(tap("B")).isEmpty)
        #expect(t.pendingCount == 2)
    }

    @Test func confirmsOldestOnOverflow() {
        let t = AcceptanceTracker<PendingTap>(window: 1)
        #expect(t.record(tap("A")).isEmpty)
        let confirmed = t.record(tap("B"))
        #expect(confirmed.map(\.keyId) == ["A"])
    }

    @Test func userDeleteVetoesMostRecent() {
        let t = AcceptanceTracker<PendingTap>(window: 3)
        _ = t.record(tap("A"))
        _ = t.record(tap("B"))
        t.recordUserDelete()
        #expect(t.flush().map(\.keyId) == ["A"]) // B vetoed
    }

    @Test func burstDeleteVetoesSeveral() {
        let t = AcceptanceTracker<PendingTap>(window: 5)
        ["A", "B", "C"].forEach { _ = t.record(tap($0)) }
        t.recordUserDelete(count: 2)
        #expect(t.flush().map(\.keyId) == ["A"]) // B, C vetoed
    }

    /// Taps and swipes share one window (§14.1): a delete vetoes the most
    /// recent commit regardless of kind — here the swipe, not the earlier tap.
    @Test func mixedWindowVetoesMostRecentKind() {
        let t = AcceptanceTracker<PendingSample>(window: 3)
        _ = t.record(.tap(tap("A")))
        _ = t.record(.swipe(swipe(.swipeUp)))
        t.recordUserDelete()
        #expect(t.flush() == [.tap(tap("A"))]) // swipe vetoed, tap survives
    }
}

struct TouchLearningControllerTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .oneThumbLeft)

    private func freshDefaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func makeController(
        suite: String, enabled: Bool = true, swipeEnabled: Bool = false, window: Int = 1
    ) -> TouchLearningController {
        let d = freshDefaults(suite)
        return TouchLearningController(
            store: TouchOffsetStore(defaults: d),
            swipeStore: SwipeBiasStore(defaults: d),
            window: window,
            saveEvery: 1,
            isEnabled: { enabled },
            isSwipeBiasEnabled: { swipeEnabled },
            currentRegime: { regime },
            keyPosition: { _ in CGPoint(x: 0.5, y: 0.5) }
        )
    }

    private func magnitude(_ v: CGVector) -> Double {
        (v.dx * v.dx + v.dy * v.dy).squareRoot()
    }

    @Test func learnsInteriorTapOffset() {
        let c = makeController(suite: "test.learn.interior")
        // Repeated tap landing right-of-center → learns a rightward offset.
        for _ in 0 ..< 60 {
            c.recordTap(keyId: "A", touchdown: CGPoint(x: 0.65, y: 0.5))
        }
        let off = c.model(for: regime).offset(forKeyId: "A")
        #expect(abs(off.dx - 0.15) < 0.03)
        #expect(abs(off.dy) < 0.02)
    }

    @Test func disabledLearnsNothing() {
        let c = makeController(suite: "test.learn.disabled", enabled: false)
        for _ in 0 ..< 60 {
            c.recordTap(keyId: "A", touchdown: CGPoint(x: 0.65, y: 0.5))
        }
        #expect(magnitude(c.model(for: regime).offset(forKeyId: "A")) < 1e-9)
    }

    @Test func nonInteriorTapIsExcluded() {
        let c = makeController(suite: "test.learn.edge")
        // Touchdown near the left edge (< interiorMargin 0.10) → not learned.
        for _ in 0 ..< 60 {
            c.recordTap(keyId: "A", touchdown: CGPoint(x: 0.03, y: 0.5))
        }
        #expect(magnitude(c.model(for: regime).offset(forKeyId: "A")) < 1e-9)
    }

    @Test func vetoedTapIsNotLearned() {
        let c = makeController(suite: "test.learn.veto", window: 1)
        // Tap X, then a user delete vetoes it before it can be confirmed.
        c.recordTap(keyId: "X", touchdown: CGPoint(x: 0.7, y: 0.5))
        c.recordUserDelete()
        // Now many taps on Y confirm/learn; X must never be learned.
        for _ in 0 ..< 60 {
            c.recordTap(keyId: "Y", touchdown: CGPoint(x: 0.65, y: 0.5))
        }
        let model = c.model(for: regime)
        #expect(magnitude(model.offset(forKeyId: "X")) < 1e-9)
        #expect(model.offset(forKeyId: "Y").dx > 0.1)
    }

    @Test func persistsAcrossReload() throws {
        let suite = "test.learn.persist"
        let c = makeController(suite: suite)
        for _ in 0 ..< 60 {
            c.recordTap(keyId: "A", touchdown: CGPoint(x: 0.65, y: 0.5))
        }
        c.persist()
        // A fresh controller on the same store sees the learned offset.
        let d = try #require(UserDefaults(suiteName: suite))
        let reloaded = TouchOffsetModel(regime: regime, snapshot: TouchOffsetStore(defaults: d).load())
        #expect(abs(reloaded.offset(forKeyId: "A").dx - 0.15) < 0.03)
    }

    // MARK: - Swipe-bias learning (§14.1)

    @Test func learnsSwipeResidual() {
        let c = makeController(suite: "test.swipe.learn", swipeEnabled: true)
        // Swipes meant as "up" drift +0.15 rad past the sector center.
        for _ in 0 ..< 40 {
            c.recordSwipe(sector: .swipeUp, measuredAngle: -.pi / 2 + 0.15)
        }
        #expect(abs(c.swipeModel(for: regime).bias(for: .swipeUp) - 0.15) < 0.01)
    }

    @Test func swipeLearningDisabledLearnsNothing() {
        let c = makeController(suite: "test.swipe.disabled", swipeEnabled: false)
        for _ in 0 ..< 40 {
            c.recordSwipe(sector: .swipeUp, measuredAngle: -.pi / 2 + 0.15)
        }
        #expect(c.swipeModel(for: regime).maturity == 0)
    }

    @Test func vetoedSwipeIsNotLearned() {
        let c = makeController(suite: "test.swipe.veto", swipeEnabled: true)
        // A swipe followed by a user delete is vetoed and never learned.
        c.recordSwipe(sector: .swipeDown, measuredAngle: .pi / 2 + 0.2)
        c.recordUserDelete()
        for _ in 0 ..< 40 {
            c.recordSwipe(sector: .swipeUp, measuredAngle: -.pi / 2 + 0.1)
        }
        let model = c.swipeModel(for: regime)
        #expect(model.sectors[GestureType.swipeDown.rawValue] == nil)
        #expect(abs(model.bias(for: .swipeUp) - 0.1) < 0.02)
    }

    @Test func swipeBiasPersistsAcrossReload() throws {
        let suite = "test.swipe.persist"
        let c = makeController(suite: suite, swipeEnabled: true)
        for _ in 0 ..< 40 {
            c.recordSwipe(sector: .swipeRight, measuredAngle: 0.12)
        }
        c.persist()
        let d = try #require(UserDefaults(suiteName: suite))
        let reloaded = SwipeBiasModel(regime: regime, snapshot: SwipeBiasStore(defaults: d).load())
        #expect(abs(reloaded.bias(for: .swipeRight) - 0.12) < 0.01)
    }

    @Test func resetAllClearsSwipeModelToo() {
        let c = makeController(suite: "test.swipe.resetall", swipeEnabled: true)
        for _ in 0 ..< 40 {
            c.recordSwipe(sector: .swipeRight, measuredAngle: 0.12)
        }
        c.resetAll()
        #expect(c.swipeModel(for: regime).maturity == 0)
    }
}

/// End-to-end through the real view model (gesture path + regime + key position).
@Suite(.serialized)
struct TouchLearningViewModelTests {
    private func magnitude(_ v: CGVector) -> Double {
        (v.dx * v.dx + v.dy * v.dy).squareRoot()
    }

    @Test func learnsFromTapsThroughViewModel() {
        let (vm, _) = makeViewModel()
        vm.sharedDefaults.set(true, forKey: SettingsKey.touchOffsetEnabled.rawValue)
        for _ in 0 ..< 60 {
            vm.handleGesture(
                .tap, keyId: GridSlot.topLeft, isReturn: false,
                touchdown: CGPoint(x: 0.66, y: 0.5)
            )
        }
        let off = vm.touchLearning.model(for: vm.currentTouchRegime).offset(forKeyId: GridSlot.topLeft)
        #expect(abs(off.dx - 0.16) < 0.04)
        #expect(abs(off.dy) < 0.03)
    }

    @Test func disabledToggleLearnsNothing() {
        let (vm, _) = makeViewModel() // toggle off by default
        for _ in 0 ..< 60 {
            vm.handleGesture(
                .tap, keyId: GridSlot.topLeft, isReturn: false,
                touchdown: CGPoint(x: 0.66, y: 0.5)
            )
        }
        let off = vm.touchLearning.model(for: vm.currentTouchRegime).offset(forKeyId: GridSlot.topLeft)
        #expect(magnitude(off) < 1e-9)
    }

    /// Straight-line features at `angle` (radians) — only `maxDisplacementAngle`
    /// matters for the sector correction.
    private func swipeFeatures(angle: Double) -> GestureFeatures {
        GestureFeatures.extract(from: [
            .zero,
            CGPoint(x: 40 * cos(angle), y: 40 * sin(angle)),
        ])
    }

    /// The swipe apply-gate (§14.3): the rotation is applied only when enabled
    /// AND the regime has matured, and then re-maps boundary misses.
    @Test func swipeCorrectionGateAndRemap() {
        let (vm, _) = makeViewModel()
        let drift = 12 * Double.pi / 180
        let boundaryMiss = swipeFeatures(angle: 25 * Double.pi / 180)

        // Off: identity even with (hypothetical) data.
        #expect(vm.correctedSwipeGesture(.swipeDownRight, features: boundaryMiss) == .swipeDownRight)

        vm.sharedDefaults.set(true, forKey: SettingsKey.swipeBiasEnabled.rawValue)
        // Enabled but immature: still identity.
        #expect(vm.correctedSwipeGesture(.swipeDownRight, features: boundaryMiss) == .swipeDownRight)

        // Learn a consistent clockwise drift on right-swipes.
        for _ in 0 ..< 40 {
            vm.touchLearning.recordSwipe(sector: .swipeRight, measuredAngle: drift)
        }
        // Mature: the 25° measurement is pulled back into the intended sector.
        #expect(vm.correctedSwipeGesture(.swipeDownRight, features: boundaryMiss) == .swipeRight)
        // Non-swipes and missing features pass through untouched.
        #expect(vm.correctedSwipeGesture(.tap, features: boundaryMiss) == .tap)
        #expect(vm.correctedSwipeGesture(.swipeDownRight, features: nil) == .swipeDownRight)
    }

    /// The gesture path feeds swipe learning with the resolved sector (§14.1).
    @Test func learnsFromSwipesThroughViewModel() {
        let (vm, _) = makeViewModel()
        vm.sharedDefaults.set(true, forKey: SettingsKey.swipeBiasEnabled.rawValue)
        let angle = -Double.pi / 2 + 0.15
        for _ in 0 ..< 40 {
            vm.handleGesture(
                .swipeUp, keyId: GridSlot.center, isReturn: false,
                features: swipeFeatures(angle: angle)
            )
        }
        let bias = vm.touchLearning.swipeModel(for: vm.currentTouchRegime).bias(for: .swipeUp)
        #expect(abs(bias - 0.15) < 0.02)
    }

    /// The apply-gate (§4.4): correction is exposed only when enabled AND the
    /// regime has matured.
    @Test func applyGateRequiresEnabledAndMature() {
        let (vm, _) = makeViewModel()
        #expect(vm.currentTouchCorrectionOffsets().isEmpty) // off

        vm.sharedDefaults.set(true, forKey: SettingsKey.touchOffsetEnabled.rawValue)
        #expect(vm.currentTouchCorrectionOffsets().isEmpty) // enabled but no data

        for _ in 0 ..< 60 {
            vm.handleGesture(
                .tap, keyId: GridSlot.topLeft, isReturn: false,
                touchdown: CGPoint(x: 0.66, y: 0.5)
            )
        }
        let offsets = vm.currentTouchCorrectionOffsets()
        #expect(!offsets.isEmpty)
        #expect((offsets[GridSlot.topLeft]?.dx ?? 0) > 0.05)
    }
}
