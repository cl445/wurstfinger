//
//  SwipeBiasConfig.swift
//  Wurstfinger
//
//  Hyperparameters for the swipe-sector bias model (spec §14). All angular
//  quantities are in **radians**. Defaults are starting values; final tuning
//  happens on device (§10).
//

import Foundation

struct SwipeBiasConfig: Equatable, RunningEstimatorConfig {
    // MARK: Estimator (shared shape with §4.2 Step 1)

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
    /// Initial robust spread of the angular residual (≈ 12°).
    let spreadPrior: Double

    // MARK: Shrinkage & application (§14.2)

    /// Shrinkage strength (prior pseudo-counts): a sector needs ≈ κ samples to
    /// be half-trusted vs. the regime-global bias.
    let kappa: Double
    /// Max magnitude of the applied rotation — kept well below the 22.5°
    /// half-sector width so the one-step sector lookup stays valid (§14.3).
    let clampRadians: Double
    /// Regime maturity (Σ n_s) at which the rotation starts being applied.
    let applyOn: Int

    static let `default` = SwipeBiasConfig(
        nMax: 150,
        huberC: 2.0,
        kGate: 3.5,
        betaMad: 0.05,
        warmup: 8,
        spreadPrior: 12 * .pi / 180,
        kappa: 8.0,
        clampRadians: 15 * .pi / 180,
        applyOn: 16
    )
}
