//
//  TouchOffsetStore.swift
//  Wurstfinger
//
//  Persistence for the touch-offset model (spec §7). Only aggregates are stored
//  ({m_k, n_k, s_k} per key, per regime) — never raw trajectories (privacy). The
//  reach surface is *derived*, so it is not persisted. A schema version guards
//  against incompatible stored state; key-level pruning handles layout changes.
//

import Foundation

/// The full persisted payload: per regime, a map of key id → offset state.
struct TouchOffsetSnapshot: Codable, Equatable {
    var schemaVersion: Int
    /// `regime.key` → (`keyId` → state).
    var regimes: [String: [String: KeyOffsetState]]

    static func empty(schemaVersion: Int) -> TouchOffsetSnapshot {
        TouchOffsetSnapshot(schemaVersion: schemaVersion, regimes: [:])
    }

    /// Drops keys in `regimeKey` that are not in `validIds` — partial
    /// invalidation on layout change, preserving still-valid keys (§7).
    mutating func pruneKeys(in regimeKey: String, keeping validIds: Set<String>) {
        guard var keys = regimes[regimeKey] else { return }
        keys = keys.filter { validIds.contains($0.key) }
        regimes[regimeKey] = keys
    }
}

/// Loads/saves the snapshot from a `UserDefaults` (production: the App-Group
/// `SharedDefaults.store`; tests inject a throwaway suite).
final class TouchOffsetStore {
    static let currentSchemaVersion = 1
    static let storageKey = "touchModel.snapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Loads the snapshot, or an empty one if absent / schema-incompatible /
    /// corrupt (the schema bump invalidates everything at once).
    func load() -> TouchOffsetSnapshot {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let snapshot = try? JSONDecoder().decode(TouchOffsetSnapshot.self, from: data),
            snapshot.schemaVersion == Self.currentSchemaVersion
        else {
            return .empty(schemaVersion: Self.currentSchemaVersion)
        }
        return snapshot
    }

    /// Persists the snapshot (stamping the current schema version).
    func save(_ snapshot: TouchOffsetSnapshot) {
        var stamped = snapshot
        stamped.schemaVersion = Self.currentSchemaVersion
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Clears all learned correction (§6.4 "reset all").
    func resetAll() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Clears one regime (§6.4 "reset current regime"), keeping the rest.
    func reset(regimeKey: String) {
        var snapshot = load()
        snapshot.regimes[regimeKey] = nil
        save(snapshot)
    }
}

extension TouchOffsetModel {
    /// Builds a model for `regime` from a persisted snapshot.
    init(regime: TouchRegime, config: TouchOffsetConfig = .default, snapshot: TouchOffsetSnapshot) {
        self.init(regime: regime, config: config, keys: snapshot.regimes[regime.key] ?? [:])
    }

    /// The persistable per-key states for this regime.
    var persistableKeys: [String: KeyOffsetState] {
        keys
    }
}
