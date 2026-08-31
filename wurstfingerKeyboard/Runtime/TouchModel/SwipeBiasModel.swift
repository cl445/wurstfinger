//
//  SwipeBiasModel.swift
//  Wurstfinger
//
//  Per-regime Empirical-Bayes model of the systematic **angular bias** of
//  directional swipes (spec §14). Analogous to `TouchOffsetModel`, but 1D and
//  per swipe *sector* instead of per key: an accepted swipe's classified sector
//  is its intent label (§4.1 self-labeling), and the sample is the angular
//  residual `measuredAngle − sectorCenter`. The applied correction rotates the
//  measured angle by the learned bias before the sector lookup, recentering
//  swipes in their sectors and rescuing near-boundary misses.
//
//  Residuals live in (−22.5°, 22.5°] plus a clamped correction — far from the
//  ±180° wrap — so plain (non-circular) means are exact.
//

import CoreGraphics
import Foundation

// MARK: - Sector geometry

extension GestureType {
    /// The eight directional swipe types, ordered by sector center angle in the
    /// classifier's coordinate system (`atan2`, y down): index × 45°, starting
    /// at 0° = right. Matches `KeyGestureRecognizer.angleToGestureType`.
    static let directionalSwipes: [GestureType] = [
        .swipeRight, .swipeDownRight, .swipeDown, .swipeDownLeft,
        .swipeLeft, .swipeUpLeft, .swipeUp, .swipeUpRight,
    ]

    var isDirectionalSwipe: Bool {
        Self.directionalSwipes.contains(self)
    }

    /// Center angle of this swipe's 45° sector, radians in [0, 2π).
    /// `nil` for non-directional gesture types.
    var sectorCenterAngle: Double? {
        guard let index = Self.directionalSwipes.firstIndex(of: self) else { return nil }
        return Double(index) * .pi / 4
    }
}

// MARK: - Model

struct SwipeBiasModel {
    let regime: TouchRegime
    let config: SwipeBiasConfig
    /// `GestureType.rawValue` of the sector → running residual estimate.
    private(set) var sectors: [String: RunningOffset]

    init(regime: TouchRegime, config: SwipeBiasConfig = .default, sectors: [String: RunningOffset] = [:]) {
        self.regime = regime
        self.config = config
        self.sectors = sectors
    }

    // MARK: - Angle helpers

    /// Wraps an angle to (−π, π].
    static func wrappedAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a <= -.pi { a += 2 * .pi }
        if a > .pi { a -= 2 * .pi }
        return a
    }

    /// Angular residual of a measured swipe angle relative to `sector`'s center,
    /// wrapped to (−π, π]. `nil` for non-directional sectors.
    static func residual(measuredAngle: Double, sector: GestureType) -> Double? {
        guard let center = sector.sectorCenterAngle else { return nil }
        return wrappedAngle(measuredAngle - center)
    }

    // MARK: - Learning (§14.1)

    /// Folds one accepted swipe's angular residual into the model.
    mutating func learn(sector: GestureType, residual: Double) {
        guard sector.isDirectionalSwipe else { return }
        var state = sectors[sector.rawValue] ?? RunningOffset(spreadPrior: config.spreadPrior)
        state.update(sample: residual, config: config)
        sectors[sector.rawValue] = state
    }

    /// Regime maturity (Σ per-sector counts) — drives the apply gate.
    var maturity: Int {
        sectors.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Application (§14.2 / §14.3)

    /// Count-weighted mean residual across all sectors — the shrinkage prior.
    /// A user's global "rotation" shows up here first, so sparse sectors borrow
    /// strength from well-sampled ones.
    var globalBias: Double {
        let total = sectors.values.reduce(0) { $0 + $1.count }
        guard total > 0 else { return 0 }
        let weighted = sectors.values.reduce(0.0) { $0 + $1.mean * Double($1.count) }
        return weighted / Double(total)
    }

    /// The clamped angular bias to subtract for `sector`: the per-sector mean
    /// shrunk toward the regime-global bias by κ pseudo-counts.
    func bias(for sector: GestureType) -> Double {
        let g = globalBias
        let raw: Double
        if let state = sectors[sector.rawValue] {
            let n = Double(state.count)
            raw = g + (state.mean - g) * n / (n + config.kappa)
        } else {
            raw = g
        }
        return clamp(raw, -config.clampRadians, config.clampRadians)
    }

    /// Rotates a measured swipe angle by the learned bias and returns the
    /// corrected sector. The bias of the *measured* sector is used; since the
    /// correction is clamped well below the 22.5° half-sector width, a single
    /// lookup step is exact enough (§14.3). Non-directional results pass through.
    func correctedGesture(measuredAngle: CGFloat) -> GestureType {
        let raw = KeyGestureRecognizer.angleToGestureType(measuredAngle)
        guard raw.isDirectionalSwipe else { return raw }
        let corrected = measuredAngle - CGFloat(bias(for: raw))
        return KeyGestureRecognizer.angleToGestureType(corrected)
    }

    // MARK: - Reset

    mutating func reset() {
        sectors.removeAll()
    }
}
