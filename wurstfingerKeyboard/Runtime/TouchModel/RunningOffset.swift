//
//  RunningOffset.swift
//  Wurstfinger
//
//  Per-(regime, key, axis) bounded-influence running-mean estimator of the
//  systematic touch offset (spec §4.2 Step 1). Unbiased running mean (no
//  constant-decay shrinkage bias), with a Huber clip for outlier/water
//  robustness and a capped count for plasticity.
//

import Foundation

/// One axis (x or y) of a key's offset estimate, in key-pitch fractions.
struct RunningOffset: Codable, Equatable {
    /// Bounded-influence running mean of the offset (`m_k`).
    private(set) var mean: Double
    /// Effective sample count, capped at `nMax` (`n_k`).
    private(set) var count: Int
    /// Robust online spread, EW-MAD (`s_k`).
    private(set) var spread: Double

    init(spreadPrior: Double) {
        mean = 0
        count = 0
        spread = spreadPrior
    }

    /// Folds one accepted, plausibility-gated sample into the estimate.
    ///
    /// - Returns: `true` if the sample was used, `false` if rejected by the
    ///   variance outlier gate (only active after `warmup`).
    @discardableResult
    mutating func update(sample s: Double, config: TouchOffsetConfig) -> Bool {
        // Variance outlier gate — only after enough samples for a stable spread.
        if count >= config.warmup, abs(s - mean) > config.kGate * spread {
            return false
        }
        // Huber clip: a single sample moves `mean` by at most c·spread/count.
        let bound = config.huberC * spread
        let delta = clamp(s - mean, -bound, bound)
        count = min(count + 1, config.nMax)
        mean += delta / Double(count)
        // Robust spread (EW-MAD) on the post-update deviation.
        spread += config.betaMad * (abs(s - mean) - spread)
        return true
    }

    /// Resets to the cold-start state.
    mutating func reset(spreadPrior: Double) {
        mean = 0
        count = 0
        spread = spreadPrior
    }
}
