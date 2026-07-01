//
//  GestureTelemetry.swift
//  Wurstfinger
//
//  Aggregates for two data-collection tracks, both fed from the gesture path:
//  - P6 (§13): per-(regime, gesture-class) running feature statistics + a
//    correction counter, for the future adaptive gesture-parameter track. Only
//    collected when the feature is enabled.
//  - P9 (§8): an A/B proxy metric — gestures and corrections split by whether
//    the correction feature was active, so the benefit can be measured before
//    ever defaulting the feature on. Always collected (local counts only).
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

/// A/B proxy metric for one condition (feature on / off).
struct ABMetric: Codable, Equatable {
    var total = 0
    var corrections = 0

    var correctionRate: Double {
        total > 0 ? Double(corrections) / Double(total) : 0
    }
}

struct TelemetrySnapshot: Codable, Equatable {
    var schemaVersion: Int
    /// `regimeKey` → `classKey` → telemetry (P6, feature-gated).
    var classes: [String: [String: ClassTelemetry]] = [:]
    /// P9: correction feature active.
    var abEnabled = ABMetric()
    /// P9: correction feature inactive (control).
    var abDisabled = ABMetric()

    static func empty(schemaVersion: Int) -> TelemetrySnapshot {
        TelemetrySnapshot(schemaVersion: schemaVersion)
    }
}

/// Persists the telemetry snapshot (App-Group `SharedDefaults`; tests inject a
/// throwaway suite).
final class GestureTelemetryStore {
    static let currentSchemaVersion = 1
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
