//
//  GestureTrail.swift
//  Wurstfinger
//
//  Time-stamped sample buffer behind the optional swipe trail, plus the
//  age and fade math the overlay renders from.
//

import CoreGraphics
import Foundation

/// One recorded touch position together with the time it was sampled.
struct GestureTrailSample: Equatable {
    let point: CGPoint
    let time: TimeInterval
}

/// Rolling buffer of touch positions for the swipe trail.
///
/// Two independent mechanisms shorten what is drawn:
/// * while the finger is down, samples older than `visibleDuration` drop out
///   of the visible window, so the trail follows the finger as a comet tail
///   rather than painting the entire route of a long drag;
/// * once the finger lifts the shape freezes and the whole trail fades out
///   over `fadeOutDuration`.
///
/// A pure value type, so both can be unit-tested with explicit timestamps and
/// without rendering anything.
struct GestureTrail: Equatable {
    private(set) var samples: [GestureTrailSample] = []

    /// Time the finger lifted, or nil while it is still down.
    private(set) var releaseTime: TimeInterval?

    /// Touch-down position. Retained separately from `samples` so it survives
    /// the eviction of the oldest samples and tap suppression keeps measuring
    /// against the true origin of the gesture.
    private(set) var origin: CGPoint?

    /// Largest straight-line distance from `origin` seen so far. A running
    /// maximum rather than a distance to the current point, so an out-and-back
    /// return swipe still counts as movement at the moment it turns around.
    private(set) var maxDisplacement: CGFloat = 0

    var isEmpty: Bool {
        samples.isEmpty
    }

    /// Starts a fresh gesture, discarding anything recorded before.
    mutating func begin(at point: CGPoint, time: TimeInterval) {
        samples = [GestureTrailSample(point: point, time: time)]
        origin = point
        maxDisplacement = 0
        releaseTime = nil
    }

    /// Records a move of the finger.
    ///
    /// Samples closer than `minimumSpacing` to the previous one are dropped:
    /// a resting finger keeps producing positions at the display refresh rate,
    /// and storing them would evict the moving part of the path from a
    /// capacity-bounded buffer. The dropped sample still updates
    /// `maxDisplacement`, so tap suppression is unaffected by the decimation.
    mutating func extend(
        to point: CGPoint,
        time: TimeInterval,
        minimumSpacing: CGFloat = KeyboardConstants.GestureTrail.minimumSampleSpacing,
        capacity: Int = KeyboardConstants.GestureTrail.sampleCapacity
    ) {
        guard let last = samples.last else {
            begin(at: point, time: time)
            return
        }
        if let origin {
            maxDisplacement = max(maxDisplacement, hypot(point.x - origin.x, point.y - origin.y))
        }
        guard hypot(point.x - last.point.x, point.y - last.point.y) >= minimumSpacing else { return }
        samples.append(GestureTrailSample(point: point, time: time))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    /// Freezes the trail at `time` and starts its fade-out.
    mutating func release(at time: TimeInterval) {
        releaseTime = time
    }

    mutating func clear() {
        samples.removeAll()
        releaseTime = nil
        origin = nil
        maxDisplacement = 0
    }

    /// Points still inside the visible age window at `now`, oldest first.
    ///
    /// After release the window is anchored to the release time instead of
    /// `now`, so the lifted trail fades out as a whole rather than also
    /// shrinking away from its tail.
    func visiblePoints(
        at now: TimeInterval,
        visibleDuration: TimeInterval = KeyboardConstants.GestureTrail.visibleDuration
    ) -> [CGPoint] {
        let reference = releaseTime ?? now
        let cutoff = reference - visibleDuration
        // Samples are appended in time order, so the expired ones are always a
        // prefix — dropping it beats filtering the whole buffer every frame.
        return samples.drop { $0.time < cutoff }.map(\.point)
    }

    /// Overall opacity multiplier: 1 while the finger is down, ramping to 0
    /// across `fadeOutDuration` after it lifts.
    func fadeOpacity(
        at now: TimeInterval,
        fadeOutDuration: TimeInterval = KeyboardConstants.GestureTrail.fadeOutDuration
    ) -> Double {
        guard let releaseTime else { return 1 }
        guard fadeOutDuration > 0 else { return 0 }
        let remaining = 1 - (now - releaseTime) / fadeOutDuration
        return min(max(remaining, 0), 1)
    }

    /// Whether the fade-out has run out and the trail can be discarded.
    /// Always false while the finger is still down.
    func isFinished(
        at now: TimeInterval,
        fadeOutDuration: TimeInterval = KeyboardConstants.GestureTrail.fadeOutDuration
    ) -> Bool {
        guard let releaseTime else { return false }
        return now >= releaseTime + fadeOutDuration
    }
}
