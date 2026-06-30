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

    @Test func holdsTapsWithinWindow() {
        let t = AcceptanceTracker(window: 2)
        #expect(t.recordTap(tap("A")).isEmpty)
        #expect(t.recordTap(tap("B")).isEmpty)
        #expect(t.pendingCount == 2)
    }

    @Test func confirmsOldestOnOverflow() {
        let t = AcceptanceTracker(window: 1)
        #expect(t.recordTap(tap("A")).isEmpty)
        let confirmed = t.recordTap(tap("B"))
        #expect(confirmed.map(\.keyId) == ["A"])
    }

    @Test func userDeleteVetoesMostRecent() {
        let t = AcceptanceTracker(window: 3)
        _ = t.recordTap(tap("A"))
        _ = t.recordTap(tap("B"))
        t.recordUserDelete()
        #expect(t.flush().map(\.keyId) == ["A"]) // B vetoed
    }

    @Test func burstDeleteVetoesSeveral() {
        let t = AcceptanceTracker(window: 5)
        ["A", "B", "C"].forEach { _ = t.recordTap(tap($0)) }
        t.recordUserDelete(count: 2)
        #expect(t.flush().map(\.keyId) == ["A"]) // B, C vetoed
    }
}

struct TouchLearningControllerTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .oneThumbLeft)

    private func freshStore(_ suite: String) -> TouchOffsetStore {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return TouchOffsetStore(defaults: d)
    }

    private func makeController(
        suite: String, enabled: Bool = true, window: Int = 1
    ) -> TouchLearningController {
        TouchLearningController(
            store: freshStore(suite),
            window: window,
            saveEvery: 1,
            isEnabled: { enabled },
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
}
