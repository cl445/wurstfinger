//
//  GestureTelemetry.swift
//  Wurstfinger
//
//  Aggregates for two data-collection tracks, both fed from the gesture path:
//  - P6 (§13): per-(regime, gesture-class) running feature statistics + a
//    correction counter, for the future adaptive gesture-parameter track. Only
//    collected when the feature is enabled.
//  - P9 (§8): a **counterfactual** benefit metric. For each tap where the
//    applied correction changed which key was hit (a "flip"), whether the
//    changed key was kept (a likely caught error) or deleted (a likely caused
//    one). Self-populating while the feature is on — no A/B toggle dance — since
//    the uncorrected outcome is recoverable from geometry (§8 counterfactual).
//
//  Only aggregates are stored — never raw trajectories (privacy, §7).
//

import Foundation

/// Online mean/variance (Welford) of one feature.
struct FeatureStat: Codable, Equatable {
    private(set) var count = 0
    private(set) var mean = 0.0
    private(set) var m2 = 0.0

    mutating func add(_ value: Double) {
        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        m2 += delta * (value - mean)
    }

    var variance: Double {
        count > 1 ? m2 / Double(count - 1) : 0
    }

    var stdDev: Double {
        variance.squareRoot()
    }
}

/// Feature stats + correction count for one gesture class in one regime.
struct ClassTelemetry: Codable, Equatable {
    var features: [String: FeatureStat] = [:]
    /// Total gestures of this class recorded.
    var total = 0
    /// How many were corrected (a user delete followed).
    var corrections = 0

    var correctionRate: Double {
        total > 0 ? Double(corrections) / Double(total) : 0
    }
}

/// Counterfactual benefit of the correction (§8). For every resolved tap we know
/// the observed outcome (kept / deleted) and — when the correction changed which
/// key was hit (a "flip") — what the uncorrected outcome would have been. From
/// `caught` (flip kept → error the correction prevented) and `caused` (flip
/// deleted → error it introduced) plus the raw tap/delete counts, both **error
/// rates** follow: the observed one (correction on) and the counterfactual one
/// (had no correction been applied). Self-labeled via the same acceptance window
/// as learning (§4.1) — not ground truth, but it isolates exactly the taps the
/// correction actually touched, which the toggle-based A/B could not.
struct CounterfactualMetric: Codable, Equatable {
    /// Total resolved taps (confirmed or vetoed) recorded with correction on.
    var taps = 0
    /// Taps the user deleted — the observed error signal with correction on.
    var deletes = 0
    /// Flip kept → an error the correction prevented (error only without it).
    var caught = 0
    /// Flip deleted → an error the correction introduced (error only with it).
    var caused = 0

    /// Observed backspace rate with the correction on.
    var errorRateWith: Double {
        taps > 0 ? Double(deletes) / Double(taps) : 0
    }

    /// Counterfactual backspace rate had no correction been applied: caught
    /// flips would have been errors, caused flips would not (§8).
    var errorRateWithout: Double {
        taps > 0 ? Double(deletes + caught - caused) / Double(taps) : 0
    }

    var net: Int {
        caught - caused
    }
}

struct TelemetrySnapshot: Codable, Equatable {
    var schemaVersion: Int
    /// `regimeKey` → `classKey` → telemetry (P6, feature-gated).
    var classes: [String: [String: ClassTelemetry]] = [:]
    /// P9: counterfactual correction benefit per `regimeKey`.
    var counterfactual: [String: CounterfactualMetric] = [:]

    static func empty(schemaVersion: Int) -> TelemetrySnapshot {
        TelemetrySnapshot(schemaVersion: schemaVersion)
    }
}

/// Persists the telemetry snapshot (App-Group `SharedDefaults`; tests inject a
/// throwaway suite).
final class GestureTelemetryStore {
    static let currentSchemaVersion = 3
    static let storageKey = "gestureTelemetry.snapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> TelemetrySnapshot {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: data),
            snapshot.schemaVersion == Self.currentSchemaVersion
        else {
            return .empty(schemaVersion: Self.currentSchemaVersion)
        }
        return snapshot
    }

    func save(_ snapshot: TelemetrySnapshot) {
        var stamped = snapshot
        stamped.schemaVersion = Self.currentSchemaVersion
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
