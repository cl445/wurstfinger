//
//  TelemetryController.swift
//  Wurstfinger
//
//  Records gesture telemetry (§13) and the counterfactual benefit metric (§8)
//  from the gesture path. Per-class correction attribution uses the last
//  recorded gesture: a user delete is charged to the most recent gesture's class
//  (immediate correction dominates, §4.1). The counterfactual metric mirrors the
//  learning acceptance window (§4.1): a tap whose applied correction changed the
//  key ("flip") is credited as `caught` when it ages out unvetoed, or `caused`
//  when a user delete vetoes it. Feature stats + counterfactual are collected
//  only while the feature is on.
//

import CoreGraphics
import Foundation

final class TelemetryController {
    private let store: GestureTelemetryStore
    private let saveEvery: Int
    /// Acceptance veto window — must match the learning controller's so a tap is
    /// labeled identically for learning and for the counterfactual metric (§4.1).
    private let window: Int

    private(set) var snapshot: TelemetrySnapshot

    /// Whether the correction feature is active — gates P6 stats and the
    /// counterfactual metric.
    var isFeatureEnabled: () -> Bool
    var currentRegime: () -> TouchRegime

    private var lastGesture: (regime: String, cls: String)?
    /// Pending flipped/unflipped taps awaiting acceptance (mirrors the learning
    /// controller's `AcceptanceTracker`, but only needs the flip flag + regime).
    private var pendingTaps: [(regime: String, isFlip: Bool)] = []
    private var dirty = 0

    init(
        store: GestureTelemetryStore,
        saveEvery: Int = 20,
        window: Int = 3,
        isFeatureEnabled: @escaping () -> Bool,
        currentRegime: @escaping () -> TouchRegime
    ) {
        self.store = store
        self.saveEvery = saveEvery
        self.window = max(1, window)
        snapshot = store.load()
        self.isFeatureEnabled = isFeatureEnabled
        self.currentRegime = currentRegime
    }

    // MARK: - Input events

    func recordGesture(_ gesture: GestureType, isReturn: Bool, features: GestureFeatures?) {
        let regimeKey = currentRegime().key
        let cls = Self.classKey(gesture, isReturn: isReturn)
        lastGesture = (regimeKey, cls)

        // P6: per-class feature stats (only while the feature is on).
        guard isFeatureEnabled() else { return }
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
        markDirty()
    }

    /// Records a tap's counterfactual outcome (§8): `isFlip` = the applied
    /// correction changed which key was hit. Taps aging out of the veto window
    /// unvetoed are credited as `caught` (a kept flip = likely prevented error).
    func recordTapOutcome(regimeKey: String, isFlip: Bool) {
        pendingTaps.append((regimeKey, isFlip))
        guard pendingTaps.count > window else { return }
        let overflow = pendingTaps.count - window
        let confirmed = pendingTaps.prefix(overflow)
        pendingTaps.removeFirst(overflow)
        for tap in confirmed where tap.isFlip {
            snapshot.counterfactual[tap.regime, default: CounterfactualMetric()].caught += 1
            markDirty()
        }
    }

    func recordUserDelete() {
        // Counterfactual: veto the most recent pending tap. A vetoed flip means
        // the correction changed the key to one the user rejected → caused (§8).
        if let vetoed = pendingTaps.popLast(), vetoed.isFlip {
            snapshot.counterfactual[vetoed.regime, default: CounterfactualMetric()].caused += 1
        }
        // P6: charge the correction to the last gesture's class.
        if isFeatureEnabled(), let last = lastGesture {
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
        pendingTaps.removeAll()
        dirty = 0
    }

    private func markDirty() {
        dirty += 1
        if dirty >= saveEvery { persist() }
    }

    // MARK: - Counterfactual geometry

    /// Whether the applied correction changed which key a tap landed on. The
    /// touch cell was shifted by `offset` (pitch fractions) and `touchdown` is
    /// normalized within that **shifted** cell, so the uncorrected position is
    /// `touchdown + offset`; if it leaves `[0,1]` on either axis an unshifted
    /// neighbor would have owned the tap (§8). Smooth-field approximation: uses
    /// the key's own offset for both cell edges (exact when neighbors share the
    /// offset — the dominant reach component; slightly off at discontinuities).
    static func isFlip(touchdown: CGPoint, offset: CGVector) -> Bool {
        let px = Double(touchdown.x) + Double(offset.dx)
        let py = Double(touchdown.y) + Double(offset.dy)
        return px < 0 || px > 1 || py < 0 || py > 1
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
