//
//  TouchOffsetModel.swift
//  Wurstfinger
//
//  Per-regime Empirical-Bayes touch-offset model (spec §4.2). Stores per-key
//  running offset means; the reach surface is *derived* (fitted from the means)
//  and the per-key deviation is *implicit* via shrinkage (§3.3). All spatial
//  quantities are in key-pitch fractions; the applied offset is returned as a
//  `CGVector` in the same units (P7 converts to points and feeds the cell-frame
//  resizing, §5.4/§5.5).
//

import CoreGraphics
import Foundation

/// Per-key state: both axes plus the key's normalized position in the keyboard.
struct KeyOffsetState: Codable, Equatable {
    var x: RunningOffset
    var y: RunningOffset
    /// Normalized horizontal position in the keyboard `[0,1]` (§5.2).
    var posU: Double
    /// Normalized vertical position in the keyboard `[0,1]`.
    var posV: Double

    init(spreadPrior: Double, posU: Double, posV: Double) {
        x = RunningOffset(spreadPrior: spreadPrior)
        y = RunningOffset(spreadPrior: spreadPrior)
        self.posU = posU
        self.posV = posV
    }

    /// Maturity of this key (min of the two axes' counts).
    var count: Int {
        min(x.count, y.count)
    }
}

struct TouchOffsetModel {
    let regime: TouchRegime
    let config: TouchOffsetConfig
    private(set) var keys: [String: KeyOffsetState]

    init(regime: TouchRegime, config: TouchOffsetConfig = .default, keys: [String: KeyOffsetState] = [:]) {
        self.regime = regime
        self.config = config
        self.keys = keys
    }

    // MARK: - Learning (§4.2 Step 1)

    /// Folds one accepted, interior, plausibility-gated tap into the model.
    /// `sampleX/Y` = `rawTouchdown − trueCenter(key)` in pitch fractions (§4.1).
    mutating func learn(keyId: String, posU: Double, posV: Double, sampleX: Double, sampleY: Double) {
        var state = keys[keyId] ?? KeyOffsetState(spreadPrior: config.spreadPrior, posU: posU, posV: posV)
        state.posU = posU
        state.posV = posV
        state.x.update(sample: sampleX, config: config)
        state.y.update(sample: sampleY, config: config)
        keys[keyId] = state
    }

    /// Regime maturity (Σ per-key counts) — drives the apply gate (§4.4).
    var maturity: Int {
        keys.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Application (§4.2 Step 2 + 3)

    /// Computes the clamped offset for **every** key in one pass (fits the
    /// surface(s) once). P7 calls this per layout pass to drive cell-frame
    /// resizing. Returned vectors are in pitch fractions.
    func allOffsets() -> [String: CGVector] {
        let priorX = fitSurface { $0.x.mean } weight: { $0.x.count }
        let priorY = fitSurface { $0.y.mean } weight: { $0.y.count }
        var result: [String: CGVector] = [:]
        result.reserveCapacity(keys.count)
        for (id, state) in keys {
            let px = priorX(state.posU, state.posV)
            let py = priorY(state.posU, state.posV)
            let nx = Double(state.x.count), ny = Double(state.y.count)
            let rx = px + (state.x.mean - px) * nx / (nx + config.kappa)
            let ry = py + (state.y.mean - py) * ny / (ny + config.kappa)
            result[id] = Self.clampMagnitude(CGVector(dx: rx, dy: ry), maxMagnitude: config.clampFraction)
        }
        return result
    }

    /// Offset for a single key (convenience; refits the surface). Returns `.zero`
    /// for unknown keys.
    func offset(forKeyId id: String) -> CGVector {
        allOffsets()[id] ?? .zero
    }

    // MARK: - Reset

    mutating func reset() {
        keys.removeAll()
    }

    // MARK: - Surface fitting

    /// Fits the reach surface for one axis and returns an evaluator
    /// `(posU, posV) → prior`. Handles the twoThumb left/right split (§3.2),
    /// where each half is fitted with a **half-local** `u ∈ [0,1]` (§5.2).
    private func fitSurface(
        _ mean: (KeyOffsetState) -> Double,
        weight: (KeyOffsetState) -> Int
    ) -> (Double, Double) -> Double {
        if regime.posture.usesSplitSurface {
            let basis = SurfaceBasis.linear
            var left: [SurfacePoint] = []
            var right: [SurfacePoint] = []
            for state in keys.values {
                let w = Double(weight(state))
                if state.posU < 0.5 {
                    left.append(SurfacePoint(u: state.posU * 2, v: state.posV, target: mean(state), weight: w))
                } else {
                    right.append(SurfacePoint(u: (state.posU - 0.5) * 2, v: state.posV, target: mean(state), weight: w))
                }
            }
            let surfL = ReachSurfaceFitter.fit(points: left, basis: basis, lambda: config.lambdaRidge)
            let surfR = ReachSurfaceFitter.fit(points: right, basis: basis, lambda: config.lambdaRidge)
            return { u, v in
                u < 0.5 ? surfL.evaluate(u: u * 2, v: v) : surfR.evaluate(u: (u - 0.5) * 2, v: v)
            }
        } else {
            let basis = SurfaceBasis.bilinear
            let points = keys.values.map {
                SurfacePoint(u: $0.posU, v: $0.posV, target: mean($0), weight: Double(weight($0)))
            }
            let surface = ReachSurfaceFitter.fit(points: points, basis: basis, lambda: config.lambdaRidge)
            return { u, v in surface.evaluate(u: u, v: v) }
        }
    }

    /// Scales a 2D vector down to `maxMagnitude` if it exceeds it (§4.3 clamp).
    static func clampMagnitude(_ v: CGVector, maxMagnitude: Double) -> CGVector {
        let mag = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        guard mag > maxMagnitude, mag > 0 else { return v }
        let scale = maxMagnitude / mag
        return CGVector(dx: v.dx * scale, dy: v.dy * scale)
    }
}
