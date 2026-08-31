//
//  SwipeBiasModelTests.swift
//  WurstfingerTests
//
//  Tests for the swipe-sector bias model (spec §14): sector geometry consistency
//  with the classifier, angle wrapping, learning/shrinkage/clamping, and the
//  corrected sector lookup.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct SwipeSectorGeometryTests {
    /// Every sector's center angle must map back to that sector through the
    /// classifier — pins `sectorCenterAngle` to `angleToGestureType`.
    @Test func sectorCentersMatchClassifier() throws {
        for sector in GestureType.directionalSwipes {
            let center = try #require(sector.sectorCenterAngle)
            #expect(KeyGestureRecognizer.angleToGestureType(CGFloat(center)) == sector)
            // Just inside both sector boundaries too (±22.5° − ε).
            let halfWidth = Double.pi / 8 - 0.001
            #expect(KeyGestureRecognizer.angleToGestureType(CGFloat(center + halfWidth)) == sector)
            #expect(KeyGestureRecognizer.angleToGestureType(CGFloat(center - halfWidth)) == sector)
        }
    }

    @Test func nonDirectionalTypesHaveNoSector() {
        #expect(GestureType.tap.sectorCenterAngle == nil)
        #expect(GestureType.circularClockwise.sectorCenterAngle == nil)
        #expect(GestureType.longPress.sectorCenterAngle == nil)
        #expect(!GestureType.tap.isDirectionalSwipe)
        #expect(GestureType.swipeUpLeft.isDirectionalSwipe)
    }

    @Test func wrappedAngleStaysInHalfOpenPi() {
        #expect(abs(SwipeBiasModel.wrappedAngle(3 * .pi) - .pi) < 1e-9)
        #expect(abs(SwipeBiasModel.wrappedAngle(-2 * .pi)) < 1e-9)
        #expect(abs(SwipeBiasModel.wrappedAngle(0.3) - 0.3) < 1e-9)
        #expect(SwipeBiasModel.wrappedAngle(-.pi) == .pi)
    }

    /// `atan2` yields swipe-up angles near −π/2 while the sector center lives at
    /// 3π/2 — the residual must wrap that distinction away.
    @Test func residualWrapsAcrossRepresentations() throws {
        let zero = try #require(SwipeBiasModel.residual(measuredAngle: -.pi / 2, sector: .swipeUp))
        #expect(abs(zero) < 1e-9)
        let drift = try #require(SwipeBiasModel.residual(measuredAngle: -.pi / 2 + 0.15, sector: .swipeUp))
        #expect(abs(drift - 0.15) < 1e-9)
        #expect(SwipeBiasModel.residual(measuredAngle: 0, sector: .tap) == nil)
    }
}

struct SwipeBiasModelTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .oneThumbRight)

    private func learnedModel(sector: GestureType, residual: Double, count: Int) -> SwipeBiasModel {
        var model = SwipeBiasModel(regime: regime)
        for _ in 0 ..< count {
            model.learn(sector: sector, residual: residual)
        }
        return model
    }

    @Test func learnsConstantResidualExactly() {
        let model = learnedModel(sector: .swipeRight, residual: 0.15, count: 40)
        #expect(abs(model.bias(for: .swipeRight) - 0.15) < 0.01)
        #expect(model.maturity == 40)
    }

    @Test func biasIsClampedBelowHalfSector() {
        // A huge (implausible) bias must never exceed the clamp, which itself
        // stays below the 22.5° half-sector width.
        let model = learnedModel(sector: .swipeRight, residual: 0.45, count: 200)
        let bias = model.bias(for: .swipeRight)
        #expect(bias <= SwipeBiasConfig.default.clampRadians + 1e-9)
        #expect(SwipeBiasConfig.default.clampRadians < .pi / 8)
    }

    /// An unseen sector borrows the regime-global bias (shrinkage prior) —
    /// a user's overall rotation transfers to sparsely used directions.
    @Test func unseenSectorBorrowsGlobalBias() {
        let model = learnedModel(sector: .swipeRight, residual: 0.2, count: 100)
        #expect(abs(model.bias(for: .swipeUp) - 0.2) < 0.02)
    }

    /// A well-sampled sector overrules a conflicting global mean as counts grow.
    @Test func sectorMeanDominatesWithEnoughSamples() {
        var model = learnedModel(sector: .swipeRight, residual: 0.2, count: 100)
        for _ in 0 ..< 100 {
            model.learn(sector: .swipeLeft, residual: -0.2)
        }
        // Global mean ≈ 0, but each sector sticks near its own residual.
        #expect(model.bias(for: .swipeRight) > 0.15)
        #expect(model.bias(for: .swipeLeft) < -0.15)
    }

    @Test func correctedGestureRescuesBoundaryMiss() {
        // Learned: swipes drift ~+12° clockwise (y-down: toward down-right).
        let model = learnedModel(sector: .swipeRight, residual: 12 * .pi / 180, count: 40)
        // A right-swipe measured at 25° lands in the down-right sector raw…
        let measured = CGFloat(25 * Double.pi / 180)
        #expect(KeyGestureRecognizer.angleToGestureType(measured) == .swipeDownRight)
        // …but the rotation pulls it back into the intended sector.
        #expect(model.correctedGesture(measuredAngle: measured) == .swipeRight)
    }

    @Test func correctedGestureIsIdentityWithoutData() {
        let model = SwipeBiasModel(regime: regime)
        for sector in GestureType.directionalSwipes {
            let center = CGFloat(sector.sectorCenterAngle ?? 0)
            #expect(model.correctedGesture(measuredAngle: center) == sector)
        }
    }

    @Test func resetClearsAllSectors() {
        var model = learnedModel(sector: .swipeRight, residual: 0.2, count: 20)
        model.reset()
        #expect(model.maturity == 0)
        #expect(abs(model.bias(for: .swipeRight)) < 1e-9)
    }
}

struct SwipeBiasStoreTests {
    private let regime = TouchRegime(orientation: .portrait, posture: .twoThumb)

    private func freshDefaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func roundTripsSnapshot() {
        let d = freshDefaults("test.swipebias.roundtrip")
        let store = SwipeBiasStore(defaults: d)

        var model = SwipeBiasModel(regime: regime)
        for _ in 0 ..< 20 {
            model.learn(sector: .swipeDown, residual: 0.1)
        }
        var snapshot = SwipeBiasSnapshot.empty(schemaVersion: SwipeBiasStore.currentSchemaVersion)
        snapshot.regimes[regime.key] = model.persistableSectors
        store.save(snapshot)

        let reloaded = SwipeBiasModel(regime: regime, snapshot: store.load())
        #expect(abs(reloaded.bias(for: .swipeDown) - model.bias(for: .swipeDown)) < 1e-9)
        #expect(reloaded.maturity == 20)
    }

    @Test func resetRegimeKeepsOthers() {
        let d = freshDefaults("test.swipebias.reset")
        let store = SwipeBiasStore(defaults: d)
        let other = TouchRegime(orientation: .portrait, posture: .oneThumbLeft)

        var snapshot = SwipeBiasSnapshot.empty(schemaVersion: SwipeBiasStore.currentSchemaVersion)
        var state = RunningOffset(spreadPrior: SwipeBiasConfig.default.spreadPrior)
        state.update(sample: 0.1, config: SwipeBiasConfig.default)
        snapshot.regimes[regime.key] = [GestureType.swipeUp.rawValue: state]
        snapshot.regimes[other.key] = [GestureType.swipeDown.rawValue: state]
        store.save(snapshot)

        store.reset(regimeKey: regime.key)
        let reloaded = store.load()
        #expect(reloaded.regimes[regime.key] == nil)
        #expect(reloaded.regimes[other.key] != nil)
    }
}
