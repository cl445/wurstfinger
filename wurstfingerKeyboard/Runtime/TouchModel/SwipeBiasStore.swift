//
//  SwipeBiasStore.swift
//  Wurstfinger
//
//  Persistence for the swipe-bias model (spec §14, mirrors §7). Only aggregates
//  are stored ({m_s, n_s, s_s} per sector, per regime) — never raw angles or
//  trajectories (privacy). Kept in a separate payload from the touch-offset
//  snapshot so the two models version and reset independently.
//

import Foundation

/// The full persisted payload: per regime, a map of sector key → residual state.
struct SwipeBiasSnapshot: Codable, Equatable {
    var schemaVersion: Int
    /// `regime.key` → (`GestureType.rawValue` → state).
    var regimes: [String: [String: RunningOffset]]

    static func empty(schemaVersion: Int) -> SwipeBiasSnapshot {
        SwipeBiasSnapshot(schemaVersion: schemaVersion, regimes: [:])
    }
}

/// Loads/saves the snapshot from a `UserDefaults` (production: the App-Group
/// `SharedDefaults.store`; tests inject a throwaway suite).
final class SwipeBiasStore {
    static let currentSchemaVersion = 1
    static let storageKey = "swipeBias.snapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Loads the snapshot, or an empty one if absent / schema-incompatible /
    /// corrupt (the schema bump invalidates everything at once).
    func load() -> SwipeBiasSnapshot {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let snapshot = try? JSONDecoder().decode(SwipeBiasSnapshot.self, from: data),
            snapshot.schemaVersion == Self.currentSchemaVersion
        else {
            return .empty(schemaVersion: Self.currentSchemaVersion)
        }
        return snapshot
    }

    /// Persists the snapshot (stamping the current schema version).
    func save(_ snapshot: SwipeBiasSnapshot) {
        var stamped = snapshot
        stamped.schemaVersion = Self.currentSchemaVersion
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Clears all learned bias ("reset all").
    func resetAll() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Clears one regime ("reset current regime"), keeping the rest.
    func reset(regimeKey: String) {
        var snapshot = load()
        snapshot.regimes[regimeKey] = nil
        save(snapshot)
    }
}

extension SwipeBiasModel {
    /// Builds a model for `regime` from a persisted snapshot.
    init(regime: TouchRegime, config: SwipeBiasConfig = .default, snapshot: SwipeBiasSnapshot) {
        self.init(regime: regime, config: config, sectors: snapshot.regimes[regime.key] ?? [:])
    }

    /// The persistable per-sector states for this regime.
    var persistableSectors: [String: RunningOffset] {
        sectors
    }
}
