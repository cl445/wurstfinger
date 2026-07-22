//
//  TouchOffsetStoreTests.swift
//  WurstfingerTests
//
//  Tests for touch-offset persistence (spec §7): round-trip, schema
//  invalidation, partial pruning, reset, model bridge.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct TouchOffsetStoreTests {
    private func freshDefaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private let regime = TouchRegime(orientation: .portrait, posture: .twoThumb)

    private func sampleSnapshot() -> TouchOffsetSnapshot {
        var model = TouchOffsetModel(regime: regime)
        for _ in 0 ..< 50 {
            model.learn(keyId: "A", posU: 0.3, posV: 0.5, sampleX: 0.1, sampleY: -0.05)
        }
        return TouchOffsetSnapshot(
            schemaVersion: TouchOffsetStore.currentSchemaVersion,
            regimes: [regime.key: model.persistableKeys]
        )
    }

    @Test func roundTripsSnapshot() {
        let store = TouchOffsetStore(defaults: freshDefaults("test.touchoffset.roundtrip"))
        let snapshot = sampleSnapshot()
        store.save(snapshot)
        #expect(store.load() == snapshot)
    }

    @Test func emptyWhenAbsent() {
        let store = TouchOffsetStore(defaults: freshDefaults("test.touchoffset.absent"))
        #expect(store.load().regimes.isEmpty)
    }

    @Test func schemaMismatchInvalidates() {
        let defaults = freshDefaults("test.touchoffset.schema")
        // Write a snapshot stamped with a wrong (future) schema version.
        var snapshot = sampleSnapshot()
        snapshot.schemaVersion = TouchOffsetStore.currentSchemaVersion + 99
        let data = try? JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: TouchOffsetStore.storageKey)

        let store = TouchOffsetStore(defaults: defaults)
        #expect(store.load().regimes.isEmpty)
    }

    @Test func resetRegimeKeepsOthers() {
        let store = TouchOffsetStore(defaults: freshDefaults("test.touchoffset.resetregime"))
        var snapshot = sampleSnapshot()
        snapshot.regimes["landscape.twoThumb"] = ["B": KeyOffsetState(spreadPrior: 0.1, posU: 0.5, posV: 0.5)]
        store.save(snapshot)

        store.reset(regimeKey: regime.key)
        let loaded = store.load()
        #expect(loaded.regimes[regime.key] == nil)
        #expect(loaded.regimes["landscape.twoThumb"] != nil)
    }

    @Test func resetAllClears() {
        let store = TouchOffsetStore(defaults: freshDefaults("test.touchoffset.resetall"))
        store.save(sampleSnapshot())
        store.resetAll()
        #expect(store.load().regimes.isEmpty)
    }

    @Test func pruneDropsUnknownKeys() {
        var snapshot = sampleSnapshot()
        snapshot.regimes[regime.key]?["STALE"] = KeyOffsetState(spreadPrior: 0.1, posU: 0.9, posV: 0.9)
        snapshot.pruneKeys(in: regime.key, keeping: ["A"])
        #expect(snapshot.regimes[regime.key]?["A"] != nil)
        #expect(snapshot.regimes[regime.key]?["STALE"] == nil)
    }

    @Test func modelBridgeReloadsState() {
        let store = TouchOffsetStore(defaults: freshDefaults("test.touchoffset.bridge"))
        // Learn → persist → rebuild model → state survives.
        var model = TouchOffsetModel(regime: regime)
        for _ in 0 ..< 100 {
            model.learn(keyId: "A", posU: 0.3, posV: 0.5, sampleX: 0.12, sampleY: 0)
        }
        store.save(TouchOffsetSnapshot(
            schemaVersion: TouchOffsetStore.currentSchemaVersion,
            regimes: [regime.key: model.persistableKeys]
        ))

        let reloaded = TouchOffsetModel(regime: regime, snapshot: store.load())
        #expect(abs(reloaded.offset(forKeyId: "A").dx - model.offset(forKeyId: "A").dx) < 1e-9)
    }
}
