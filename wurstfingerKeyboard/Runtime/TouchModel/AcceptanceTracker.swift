//
//  AcceptanceTracker.swift
//  Wurstfinger
//
//  Self-labeling acceptance filter (spec §4.1): holds recently committed
//  samples in a small veto window. A user delete vetoes the most recent pending
//  sample(s) (immediate + short-burst correction); samples that age out of the
//  window are "accepted" and returned for learning. Only user deletes (the
//  `.deleteBackward` KeyAction in the pipeline) reach this — compose/Telex
//  internal deletes bypass the pipeline and are correctly ignored.
//
//  Taps (§4.1) and directional swipes (§14.1) share **one** window so a delete
//  vetoes the most recent commit regardless of kind — a delete after
//  tap-then-swipe must not veto the innocent tap.
//

import CoreGraphics
import Foundation

/// A committed tap awaiting acceptance confirmation.
struct PendingTap: Equatable {
    let keyId: String
    /// Touchdown normalized to the key frame (`[0,1]²`, 0.5 = center).
    let touchdown: CGPoint
    let regime: TouchRegime
}

/// A committed directional swipe awaiting acceptance confirmation (§14.1).
struct PendingSwipe: Equatable {
    /// The final classified sector — the intent label under self-labeling.
    let sector: GestureType
    /// Angular residual `measuredAngle − sectorCenter(sector)`, radians,
    /// wrapped to (−π, π]. Measured from the *raw* angle so the learned mean
    /// stays the raw bias even while a correction is being applied.
    let residual: Double
    let regime: TouchRegime
}

/// A committed sample of either kind, sharing the acceptance window.
enum PendingSample: Equatable {
    case tap(PendingTap)
    case swipe(PendingSwipe)
}

/// Ring of pending samples with a veto window. Not thread-safe (main-thread use).
final class AcceptanceTracker<Sample> {
    /// How many of the most recent samples remain vetoable. Older samples are
    /// confirmed (returned for learning) on the next record.
    private let window: Int
    private var pending: [Sample] = []

    init(window: Int = 3) {
        self.window = max(1, window)
    }

    /// Records a sample and returns any samples that just aged out of the veto
    /// window (now accepted → learn them).
    func record(_ sample: Sample) -> [Sample] {
        pending.append(sample)
        guard pending.count > window else { return [] }
        let overflow = pending.count - window
        let confirmed = Array(pending.prefix(overflow))
        pending.removeFirst(overflow)
        return confirmed
    }

    /// A user delete: veto the most recent `count` pending samples (a burst
    /// deletes several). They were corrected, so they are never learned.
    func recordUserDelete(count: Int = 1) {
        pending.removeLast(min(max(count, 0), pending.count))
    }

    /// Confirms and returns everything still pending (e.g. on teardown).
    func flush() -> [Sample] {
        defer { pending.removeAll() }
        return pending
    }

    /// Number of samples currently awaiting confirmation (for tests/diagnostics).
    var pendingCount: Int {
        pending.count
    }
}
