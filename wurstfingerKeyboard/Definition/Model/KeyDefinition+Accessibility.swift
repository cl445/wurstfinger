//
//  KeyDefinition+Accessibility.swift
//  Wurstfinger
//
//  What a key offers to assistive technologies, derived from its bindings.
//

import Foundation

/// One named action a key offers to assistive technologies.
struct KeyAccessibilityAction: Equatable {
    let name: String
    let gesture: GestureType
}

extension KeyDefinition {
    /// Gesture that must replace the synthesized tap when an assistive
    /// technology activates this key, or nil when the tap already does
    /// something — VoiceOver activation reaches the recognizer as a plain
    /// tap, so those keys need no override and keep one code path.
    var accessibilityActivationOverride: GestureType? {
        // Annotated so `.none` reads as the key action, not `Optional.none`.
        let tapAction: KeyAction = bindings[.tap]?.action ?? .none
        guard tapAction == .none else { return nil }
        guard let gesture = accessibilityActivationGesture,
              let binding = bindings[gesture], binding.action != .none
        else { return nil }
        return gesture
    }

    /// Order the custom actions are offered in. Fixed because dictionary
    /// iteration is seeded per process and the rotor order must not change
    /// between launches; a `static let` for the same reason
    /// `KeyView.hintGestureOrder` is one — `allCases` rebuilds its array on
    /// every access, and this list is walked per key on every render. `.tap`
    /// drops out: it is the element's own activation.
    static let accessibilityActionGestures: [GestureType] = GestureType.allCases.filter { $0 != .tap }

    /// Gestures offered as named custom actions. The activation override is
    /// excluded alongside `.tap` — it is already reachable by activating the
    /// key.
    ///
    /// A binding qualifies by carrying an `accessibilityLabel`: that label is
    /// what a VoiceOver user hears, and it doubles as the opt-in, so a letter
    /// swipe does not add eight unnamed entries to every key. Which bindings
    /// take the opt-in is a deliberate, narrow choice — the utility keys plus
    /// `, . ?` and the shift affordance; `CommonKeys.defaultSlotBindings`
    /// documents the reasoning and `AccessibilityLabelTests` pins the set.
    /// Names are deduplicated — cut-all is bound to both circle directions
    /// with one label, and two identical rotor entries read as a bug.
    var accessibilityActions: [KeyAccessibilityAction] {
        let skipped = accessibilityActivationOverride
        var seen: Set<String> = []
        var actions: [KeyAccessibilityAction] = []
        for gesture in Self.accessibilityActionGestures where gesture != skipped {
            guard let binding = bindings[gesture], binding.action != .none,
                  let name = binding.accessibilityLabel, !name.isEmpty,
                  seen.insert(name).inserted
            else { continue }
            actions.append(KeyAccessibilityAction(name: name, gesture: gesture))
        }
        return actions
    }
}
