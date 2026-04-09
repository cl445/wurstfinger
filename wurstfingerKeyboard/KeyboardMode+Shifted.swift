//
//  KeyboardMode+Shifted.swift
//  Wurstfinger
//
//  Automatic shifted layer generation from a main mode.
//

import Foundation

extension KeyboardMode {
    /// Generates the shifted layer from this mode.
    /// - Letter bindings are uppercased using the given locale
    /// - Arrangements are reused as-is (same key IDs)
    /// - Overrides allow manual corrections (e.g. ß → ẞ)
    func generateShifted(
        locale: Locale,
        overrides: [String: KeyConfig] = [:]
    ) -> KeyboardMode {
        let shiftedKeys = keys.mapValues { key in
            overrides[key.id] ?? key.autoShifted(locale: locale)
        }
        return KeyboardMode(
            name: ModeNames.shifted,
            keys: shiftedKeys,
            arrangements: arrangements,
            autoTransitions: [:],
            doubleTapMode: nil
        )
    }
}

extension KeyConfig {
    /// Creates an uppercase variant of this key.
    /// Only bindings with resolvedCategory == .letter are uppercased.
    func autoShifted(locale: Locale) -> KeyConfig {
        let shiftedBindings = bindings.mapValues { binding -> KeyBinding in
            guard binding.resolvedCategory == .letter else { return binding }
            let upper = binding.label.uppercased(with: locale)
            return KeyBinding(
                label: upper,
                action: .commitText(upper),
                category: binding.category,
                returnAction: binding.returnAction,
                accessibilityLabel: binding.accessibilityLabel
            )
        }
        return KeyConfig(
            id: id, bindings: shiftedBindings, swipeMode: swipeMode,
            slideType: slideType, style: style, tapCycleActions: tapCycleActions
        )
    }
}
