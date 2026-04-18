//
//  ReturnSwipeResolver.swift
//  Wurstfinger
//
//  Resolver for return-swipes (swipe out and back to the start position).
//

import Foundation

/// Resolver for "return swipes" — when the finger swipes out from a key
/// and back to the start. Looks up the regular binding for that direction
/// and substitutes its `returnAction` (if any).
///
/// Returns `nil` if the binding has no `returnAction` so the chain can fall
/// back to the regular swipe action.
struct ReturnSwipeResolver: GestureResolver {
    func resolve(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyBinding? {
        guard let key = mode.key(for: keyId) else { return nil }
        // Return swipes only make sense for swipe gestures.
        guard gesture.isSwipe, key.swipeMode.allows(gesture) else { return nil }
        guard let binding = key.bindings[gesture],
              let returnAction = binding.returnAction
        else {
            return nil
        }
        return KeyBinding(
            label: binding.label,
            action: returnAction,
            category: binding.category,
            returnAction: nil,
            accessibilityLabel: binding.accessibilityLabel
        )
    }
}
