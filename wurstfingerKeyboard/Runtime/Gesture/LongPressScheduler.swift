//
//  LongPressScheduler.swift
//  Wurstfinger
//
//  Shared long-press timer + touch-consumption bookkeeping extracted from
//  KeyGestureRecognizer and SlideGestureHandler. Only the DispatchWorkItem
//  lifecycle and the consumed-touch flag are shared; each recognizer keeps
//  its own distinct fire-guard predicate (passed as the `fire` closure).
//

import Foundation

/// Owns the long-press `DispatchWorkItem` lifecycle and the consumed-touch
/// flag for a gesture recognizer.
///
/// A reference type so it can live in `@State` and mutate in place across
/// SwiftUI body re-evaluations (the same reason the recognizers previously
/// held two `@State` values directly). The recognizer supplies its fire guard
/// as the `fire` closure, evaluated at fire time exactly as the old
/// `fireLongPress()` read live `@State` — so extracting this changes no
/// timing or staleness behavior.
final class LongPressScheduler {
    private var pending: DispatchWorkItem?

    /// True once a fired long press dispatched an action and thereby consumed
    /// the touch, so the release must not also produce a tap or slide end.
    private(set) var consumedTouch = false

    /// Whether a long-press timer is currently armed.
    var isScheduled: Bool {
        pending != nil
    }

    /// Arms the long-press timer, cancelling any previously armed one. `fire`
    /// is the recognizer's guard predicate, evaluated when the timer fires;
    /// returning `true` marks the touch consumed.
    func schedule(
        after delay: TimeInterval = KeyboardConstants.LongPress.duration,
        fire: @escaping () -> Bool
    ) {
        cancel()
        let item = DispatchWorkItem { [weak self] in self?.runFire(fire) }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Cancels any armed timer without touching `consumedTouch`.
    func cancel() {
        pending?.cancel()
        pending = nil
    }

    /// Evaluates the fire guard synchronously and records touch consumption.
    /// Not private so it can be unit-tested without a real 0.7 s timer.
    func runFire(_ fire: () -> Bool) {
        pending = nil
        if fire() { consumedTouch = true }
    }

    /// Clears the consumed-touch flag before the next touch sequence.
    func clearConsumed() {
        consumedTouch = false
    }
}
