//
//  GhostKeyResolver.swift
//  Wurstfinger
//
//  Resolver that delegates to a fallback mode (e.g. numeric layer) when the
//  primary mode has no binding for the requested gesture.
//

import Foundation

/// Resolves a gesture by delegating to a fallback `KeyboardMode` when the
/// primary mode has no binding for the requested gesture/key combination.
///
/// Inspired by Thumb-Key's "ghost keys" — letters that surface a hidden
/// numeric layer on the same key without a layer switch. The resolver is
/// constructed with the *resolved* fallback mode (rather than just a name)
/// so it can run without a `KeyboardDefinition` reference at call time.
struct GhostKeyResolver: GestureResolver {
    let fallbackMode: KeyboardMode

    func resolve(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyBinding? {
        // Only fall through if the primary mode has no *reachable* binding
        // here. A binding declared behind a swipeMode that disallows the
        // current gesture is effectively unreachable, so ghost fallback
        // must still apply.
        if let key = mode.key(for: keyId),
           key.bindings[gesture] != nil,
           !gesture.isSwipe || key.swipeMode.allows(gesture) {
            return nil
        }
        // Look up the same key id in the fallback mode.
        guard let fallbackKey = fallbackMode.key(for: keyId) else { return nil }
        if gesture.isSwipe, !fallbackKey.swipeMode.allows(gesture) {
            return nil
        }
        if let binding = fallbackKey.bindings[gesture] {
            return binding
        }
        // "Type numbers by holding": a long press with no explicit long-press
        // binding falls back to the fallback key's *tap* when that tap emits a
        // digit. This lets the numeric layer expose its digits to a hold on the
        // letter layer without mirroring every `.tap` as an identical
        // `.longPress` binding. Restricted to `.digit` so utility fallbacks
        // (return/globe/delete/back-to-alpha) are never surfaced by a hold —
        // an unresolved hold on those keeps its normal tap on release.
        if gesture == .longPress,
           let tap = fallbackKey.bindings[.tap],
           tap.category == .digit {
            return tap
        }
        return nil
    }
}
