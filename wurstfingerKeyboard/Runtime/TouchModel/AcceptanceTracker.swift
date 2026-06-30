//
//  AcceptanceTracker.swift
//  Wurstfinger
//
//  Self-labeling acceptance filter (spec §4.1): holds recently committed taps
//  in a small veto window. A user delete vetoes the most recent pending tap(s)
//  (immediate + short-burst correction); taps that age out of the window are
//  "accepted" and returned for learning. Only user deletes (the `.deleteBackward`
//  KeyAction in the pipeline) reach this — compose/Telex internal deletes bypass
//  the pipeline and are correctly ignored.
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

/// Ring of pending taps with a veto window. Not thread-safe (main-thread use).
final class AcceptanceTracker {
    /// How many of the most recent taps remain vetoable. Older taps are
    /// confirmed (returned for learning) on the next tap.
    private let window: Int
    private var pending: [PendingTap] = []

    init(window: Int = 3) {
        self.window = max(1, window)
    }

    /// Records a tap and returns any taps that just aged out of the veto window
    /// (now accepted → learn them).
    func recordTap(_ tap: PendingTap) -> [PendingTap] {
        pending.append(tap)
        guard pending.count > window else { return [] }
        let overflow = pending.count - window
        let confirmed = Array(pending.prefix(overflow))
        pending.removeFirst(overflow)
        return confirmed
    }

    /// A user delete: veto the most recent `count` pending taps (a burst deletes
    /// several). They were corrected, so they are never learned.
    func recordUserDelete(count: Int = 1) {
        pending.removeLast(min(max(count, 0), pending.count))
    }

    /// Confirms and returns everything still pending (e.g. on teardown).
    func flush() -> [PendingTap] {
        defer { pending.removeAll() }
        return pending
    }

    /// Number of taps currently awaiting confirmation (for tests/diagnostics).
    var pendingCount: Int {
        pending.count
    }
}
