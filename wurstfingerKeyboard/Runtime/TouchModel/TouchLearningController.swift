//
//  TouchLearningController.swift
//  Wurstfinger
//
//  Orchestrates touch-offset learning (spec §4.1, §5): records taps with their
//  touchdown, applies the acceptance filter (veto on user delete) and the
//  interior gate, computes the sample `e = touchdown − center` and folds it into
//  the per-regime model, persisting periodically. Inert unless the feature is
//  enabled. Regime, key position and enabled-state are injected so the
//  controller is testable without a view model.
//

import CoreGraphics
import Foundation

final class TouchLearningController {
    private let store: TouchOffsetStore
    private let config: TouchOffsetConfig
    private let tracker: AcceptanceTracker
    private let saveEvery: Int

    /// In-memory model state (persisted debounced). `private(set)` for tests.
    private(set) var snapshot: TouchOffsetSnapshot

    /// Master toggle (§6.1) — learning is inert when this returns `false`.
    var isEnabled: () -> Bool
    /// The active regime at the moment of a tap.
    var currentRegime: () -> TouchRegime
    /// Normalized key position in the keyboard `[0,1]²` (surface-fit input);
    /// `nil` if unknown (then the tap is not learned).
    var keyPosition: (String) -> CGPoint?

    private var dirtyCount = 0

    init(
        store: TouchOffsetStore,
        config: TouchOffsetConfig = .default,
        window: Int = 3,
        saveEvery: Int = 8,
        isEnabled: @escaping () -> Bool,
        currentRegime: @escaping () -> TouchRegime,
        keyPosition: @escaping (String) -> CGPoint?
    ) {
        self.store = store
        self.config = config
        tracker = AcceptanceTracker(window: window)
        self.saveEvery = saveEvery
        snapshot = store.load()
        self.isEnabled = isEnabled
        self.currentRegime = currentRegime
        self.keyPosition = keyPosition
    }

    // MARK: - Input events

    /// Records an accepted-so-far tap (a non-slide tap with a touchdown).
    func recordTap(keyId: String, touchdown: CGPoint) {
        guard isEnabled() else { return }
        let confirmed = tracker.recordTap(
            PendingTap(keyId: keyId, touchdown: touchdown, regime: currentRegime())
        )
        confirmed.forEach(learn)
    }

    /// A user delete (`.deleteBackward` in the pipeline) — vetoes recent taps.
    func recordUserDelete() {
        guard isEnabled() else { return }
        tracker.recordUserDelete()
    }

    // MARK: - Model access (for UI / P7 application)

    func model(for regime: TouchRegime) -> TouchOffsetModel {
        TouchOffsetModel(regime: regime, config: config, keys: snapshot.regimes[regime.key] ?? [:])
    }

    func resetAll() {
        snapshot = .empty(schemaVersion: TouchOffsetStore.currentSchemaVersion)
        store.resetAll()
        dirtyCount = 0
    }

    func reset(regime: TouchRegime) {
        snapshot.regimes[regime.key] = nil
        store.reset(regimeKey: regime.key)
    }

    /// Forces a persist (call on background/teardown).
    func persist() {
        store.save(snapshot)
        dirtyCount = 0
    }

    // MARK: - Learning

    private func learn(_ tap: PendingTap) {
        // Interior gate (§4.1): only learn from taps comfortably inside the key,
        // measured against the *true* (unshifted) frame. Doubles as anti-drift.
        let m = config.interiorMargin
        guard tap.touchdown.x >= m, tap.touchdown.x <= 1 - m,
              tap.touchdown.y >= m, tap.touchdown.y <= 1 - m,
              let pos = keyPosition(tap.keyId)
        else { return }

        // e = touchdown − center, in pitch fractions (frame ≈ pitch).
        let ex = Double(tap.touchdown.x) - 0.5
        let ey = Double(tap.touchdown.y) - 0.5

        var model = model(for: tap.regime)
        model.learn(
            keyId: tap.keyId,
            posU: Double(pos.x),
            posV: Double(pos.y),
            sampleX: ex,
            sampleY: ey
        )
        snapshot.regimes[tap.regime.key] = model.persistableKeys

        dirtyCount += 1
        if dirtyCount >= saveEvery { persist() }
    }
}
