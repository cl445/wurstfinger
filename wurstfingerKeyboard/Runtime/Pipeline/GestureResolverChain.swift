//
//  GestureResolverChain.swift
//  Wurstfinger
//
//  Composes multiple GestureResolvers into a priority-ordered pipeline.
//

import Foundation

/// Composes multiple `GestureResolver`s into a priority-ordered pipeline.
///
/// Each resolver is tried in order; the first non-nil result wins. If no
/// resolver matches, the chain returns `nil` (callers typically fall back to
/// `KeyAction.none`).
struct GestureResolverChain {
    let resolvers: [GestureResolver]

    /// Returns the first matching binding, or `nil` if no resolver in the
    /// chain handles this gesture.
    func resolve(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyBinding? {
        for resolver in resolvers {
            if let binding = resolver.resolve(keyId: keyId, gesture: gesture, in: mode) {
                return binding
            }
        }
        return nil
    }
}
