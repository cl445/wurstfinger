//
//  TelemetryController.swift
//  Wurstfinger
//
//  Records gesture telemetry (§13) and the A/B proxy metric (§8) from the
//  gesture path. Correction attribution uses the last recorded gesture: a user
//  delete is charged to the most recent gesture's class (immediate correction
//  dominates, §4.1). Feature stats are recorded per gesture while the feature is
//  on (a diagnostic; the small fraction of corrected gestures is negligible and
//  separately captured by the correction counters).
//

import Foundation

final class TelemetryController {
    private let store: GestureTelemetryStore
    private let saveEvery: Int

    private(set) var snapshot: TelemetrySnapshot

    /// Whether the correction feature is active — gates P6 stats and selects the
    /// P9 A/B condition.
    var isFeatureEnabled: () -> Bool
    var currentRegime: () -> TouchRegime

    private var lastGesture: (regime: String, cls: String)?
    private var dirty = 0

    init(
        store: GestureTelemetryStore,
        saveEvery: Int = 20,
        isFeatureEnabled: @escaping () -> Bool,
        currentRegime: @escaping () -> TouchRegime
    ) {
        self.store = store
        self.saveEvery = saveEvery
        snapshot = store.load()
        self.isFeatureEnabled = isFeatureEnabled
        self.currentRegime = currentRegime
    }

    // MARK: - Input events

    func recordGesture(_ gesture: GestureType, isReturn: Bool, features: GestureFeatures?) {
        let enabled = isFeatureEnabled()
        // P9: A/B total (always, both conditions).
        if enabled { snapshot.abEnabled.total += 1 } else { snapshot.abDisabled.total += 1 }

        let regimeKey = currentRegime().key
        let cls = Self.classKey(gesture, isReturn: isReturn)
        lastGesture = (regimeKey, cls)

        // P6: per-class feature stats (only while the feature is on).
        if enabled {
            var classes = snapshot.classes[regimeKey] ?? [:]
            var telemetry = classes[cls] ?? ClassTelemetry()
            telemetry.total += 1
            if let features {
                for (name, value) in Self.featureValues(features) {
                    var stat = telemetry.features[name] ?? FeatureStat()
                    stat.add(value)
                    telemetry.features[name] = stat
                }
            }
            classes[cls] = telemetry
            snapshot.classes[regimeKey] = classes
        }
        markDirty()
    }

    func recordUserDelete() {
        let enabled = isFeatureEnabled()
        // P9: A/B corrections.
        if enabled { snapshot.abEnabled.corrections += 1 } else { snapshot.abDisabled.corrections += 1 }
        // P6: charge the correction to the last gesture's class.
        if enabled, let last = lastGesture {
            snapshot.classes[last.regime]?[last.cls]?.corrections += 1
        }
        markDirty()
    }

    func persist() {
        store.save(snapshot)
        dirty = 0
    }

    func reset() {
        snapshot = .empty(schemaVersion: GestureTelemetryStore.currentSchemaVersion)
        store.reset()
        lastGesture = nil
        dirty = 0
    }

    private func markDirty() {
        dirty += 1
        if dirty >= saveEvery { persist() }
    }

    // MARK: - Mapping

    /// Collapses a `GestureType` (+ return flag) into the telemetry class key,
    /// embedding the direction for swipes and circles (§13-C).
    static func classKey(_ gesture: GestureType, isReturn: Bool) -> String {
        if isReturn { return "return" }
        switch gesture {
        case .tap: return "tap"
        case .circularClockwise: return "circle.cw"
        case .circularCounterclockwise: return "circle.ccw"
        default: return "swipe.\(gesture.rawValue)"
        }
    }

    /// The discriminating features recorded per gesture, in the classifier's
    /// native units so they stay comparable to the thresholds (§13-A).
    static func featureValues(_ f: GestureFeatures) -> [String: Double] {
        [
            "maxDisplacement": Double(f.maxDisplacement),
            "returnRatio": Double(f.returnRatio),
            "circularity": Double(f.circularity),
            "angularSpan": Double(abs(f.angularSpan)),
            "turnConsistency": Double(f.turnConsistency),
            "orientedCompactness": Double(f.orientedCompactness),
            "dominantAngle": Double(f.dominantAngle),
        ]
    }
}
