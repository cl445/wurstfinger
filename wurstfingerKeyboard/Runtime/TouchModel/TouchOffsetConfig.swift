//
//  TouchOffsetConfig.swift
//  Wurstfinger
//
//  Hyperparameters for the touch-offset model (spec §4.2, §10). All spatial
//  quantities are in **key-pitch fractions** (dx/width, dy/height). Defaults
//  are the spec's starting values; final tuning happens on device (§10).
//

import Foundation

struct TouchOffsetConfig: Equatable {
    // MARK: Estimator (§4.2 Step 1)

    /// Plasticity cap: above this the running mean behaves like an EMA with
    /// α = 1/nMax (recency / self-healing), decoupled from shrinkage.
    let nMax: Int
    /// Huber clip factor (× spread): bounds a single sample's influence.
    let huberC: Double
    /// Outlier-gate threshold (× spread); rejects samples beyond it after warmup.
    let kGate: Double
    /// EW-MAD rate for the robust spread estimate.
    let betaMad: Double
    /// Samples before the variance-based outlier gate becomes active.
    let warmup: Int
    /// Initial robust spread (≈ FFitts σ_a ≈ 0.10 pitch).
    let spreadPrior: Double

    // MARK: Shrinkage & application (§4.2 Step 3, §4.3)

    /// Shrinkage strength (prior pseudo-counts): a key needs ≈ κ samples to be
    /// half-trusted vs. the reach-surface prior.
    let kappa: Double
    /// Max magnitude of the applied 2D correction vector, as a pitch fraction.
    let clampFraction: Double
    /// Ridge regularization for the reach-surface fit (§4.2 Step 2).
    let lambdaRidge: Double

    // MARK: Learning gate & application gate (used by P5/P7)

    /// Interior margin (pitch fraction from the *true* key edge) required for a
    /// tap to be used for learning — bias/variance knob & anti-drift (§4.1).
    let interiorMargin: Double
    /// Regime maturity (Σ n_k) at which correction starts being applied (§4.4).
    let applyOn: Int
    /// Regime maturity below which correction is suspended again (hysteresis).
    let applyOff: Int

    static let `default` = TouchOffsetConfig(
        nMax: 150,
        huberC: 2.0,
        kGate: 3.5,
        betaMad: 0.05,
        warmup: 8,
        spreadPrior: 0.10,
        kappa: 8.0,
        clampFraction: 0.35,
        lambdaRidge: 8.0,
        interiorMargin: 0.10,
        applyOn: 12,
        applyOff: 6
    )
}

/// Clamps `value` into `[lower, upper]`.
@inline(__always)
func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
