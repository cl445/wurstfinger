//
//  PrimaryResolver.swift
//  Wurstfinger
//
//  Default resolver: looks up the binding directly on the requested key.
//

import Foundation

/// Default resolver — returns the binding the key declares for the gesture.
///
/// `swipeMode` is consulted only for swipe gestures so that taps, long
/// presses and circular gestures aren't accidentally filtered out by a key
/// that declares e.g. `.twoWayHorizontal` for its drag behavior.
struct PrimaryResolver: GestureResolver {
    func resolve(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyBinding? {
        guard let key = mode.key(for: keyId) else { return nil }
        if gesture.isSwipe, !key.swipeMode.allows(gesture) {
            return nil
        }
        return key.bindings[gesture]
    }
}
