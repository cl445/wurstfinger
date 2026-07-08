//
//  TouchLearningController.swift
//  Wurstfinger
//
//  Orchestrates touch learning (spec §4.1, §5, §14): records taps with their
//  touchdown and directional swipes with their angular residual, applies the
//  shared acceptance filter (veto on user delete), computes the samples and
//  folds them into the per-regime models (offset per key, bias per sector),
//  persisting periodically. Each track is inert unless its feature is enabled.
//  Regime, key position and enabled-states are injected so the controller is
//  testable without a view model.
//

import CoreGraphics
import Foundation

final class TouchLearningController {
    private let store: TouchOffsetStore
    private let swipeStore: SwipeBiasStore
    private let config: TouchOffsetConfig
    private let swipeConfig: SwipeBiasConfig
    private let tracker: AcceptanceTracker<PendingSample>
    private let saveEvery: Int

    /// In-memory model state (persisted debounced). `private(set)` for tests.
    private(set) var snapshot: TouchOffsetSnapshot
    private(set) var swipeSnapshot: SwipeBiasSnapshot

    /// Master toggle for tap-offset learning (§6.1) — inert when `false`.
    var isEnabled: () -> Bool
    /// Toggle for swipe-bias learning (§14.4) — inert when `false`.
    var isSwipeBiasEnabled: () -> Bool
    /// The active regime at the moment of a tap.
    var currentRegime: () -> TouchRegime
    /// Normalized key position in the keyboard `[0,1]²` (surface-fit input);
    /// `nil` if unknown (then the tap is not learned).
    var keyPosition: (String) -> CGPoint?

    private var dirtyCount = 0

    init(
        store: TouchOffsetStore,
        swipeStore: SwipeBiasStore,
        config: TouchOffsetConfig = .default,
        swipeConfig: SwipeBiasConfig = .default,
        window: Int = 3,
        saveEvery: Int = 8,
        isEnabled: @escaping () -> Bool,
        isSwipeBiasEnabled: @escaping () -> Bool = { false },
        currentRegime: @escaping () -> TouchRegime,
        keyPosition: @escaping (String) -> CGPoint?
    ) {
        self.store = store
        self.swipeStore = swipeStore
        self.config = config
        self.swipeConfig = swipeConfig
        tracker = AcceptanceTracker(window: window)
        self.saveEvery = saveEvery
        snapshot = store.load()
        swipeSnapshot = swipeStore.load()
        self.isEnabled = isEnabled
        self.isSwipeBiasEnabled = isSwipeBiasEnabled
        self.currentRegime = currentRegime
        self.keyPosition = keyPosition
    }

    // MARK: - Input events

    /// Records an accepted-so-far tap (a non-slide tap with a touchdown).
    func recordTap(keyId: String, touchdown: CGPoint) {
        guard isEnabled() else { return }
        confirm(tracker.record(.tap(
            PendingTap(keyId: keyId, touchdown: touchdown, regime: currentRegime())
        )))
    }

    /// Records an accepted-so-far directional swipe (§14.1). The residual is
    /// computed from the *raw* measured angle against the final sector's center
    /// so the learned mean estimates the uncorrected bias.
    func recordSwipe(sector: GestureType, measuredAngle: Double) {
        guard isSwipeBiasEnabled(),
              let residual = SwipeBiasModel.residual(measuredAngle: measuredAngle, sector: sector)
        else { return }
        confirm(tracker.record(.swipe(
            PendingSwipe(sector: sector, residual: residual, regime: currentRegime())
        )))
    }

    /// A user delete (`.deleteBackward` in the pipeline) — vetoes recent samples.
    func recordUserDelete() {
        guard isEnabled() || isSwipeBiasEnabled() else { return }
        tracker.recordUserDelete()
    }

    private func confirm(_ samples: [PendingSample]) {
        for sample in samples {
            switch sample {
            case let .tap(tap): learn(tap)
            case let .swipe(swipe): learn(swipe)
            }
        }
    }

    // MARK: - Model access (for UI / P7 application)

    func model(for regime: TouchRegime) -> TouchOffsetModel {
        TouchOffsetModel(regime: regime, config: config, keys: snapshot.regimes[regime.key] ?? [:])
    }

    func swipeModel(for regime: TouchRegime) -> SwipeBiasModel {
        SwipeBiasModel(regime: regime, config: swipeConfig, sectors: swipeSnapshot.regimes[regime.key] ?? [:])
    }

    func resetAll() {
        snapshot = .empty(schemaVersion: TouchOffsetStore.currentSchemaVersion)
        swipeSnapshot = .empty(schemaVersion: SwipeBiasStore.currentSchemaVersion)
        store.resetAll()
        swipeStore.resetAll()
        dirtyCount = 0
    }

    func reset(regime: TouchRegime) {
        snapshot.regimes[regime.key] = nil
        swipeSnapshot.regimes[regime.key] = nil
        store.reset(regimeKey: regime.key)
        swipeStore.reset(regimeKey: regime.key)
    }

    /// Forces a persist (call on background/teardown).
    func persist() {
        store.save(snapshot)
        swipeStore.save(swipeSnapshot)
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
        markDirty()
    }

    private func learn(_ swipe: PendingSwipe) {
        var model = swipeModel(for: swipe.regime)
        model.learn(sector: swipe.sector, residual: swipe.residual)
        swipeSnapshot.regimes[swipe.regime.key] = model.persistableSectors
        markDirty()
    }

    private func markDirty() {
        dirtyCount += 1
        if dirtyCount >= saveEvery { persist() }
    }
}
