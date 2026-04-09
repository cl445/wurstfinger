//
//  KeyBinding.swift
//  Wurstfinger
//
//  What a single gesture on a key produces.
//

import Foundation

/// What a single gesture on a key produces.
struct KeyBinding: Codable, Equatable {
    /// Displayed text on the key (can differ from output, e.g. "⇧" for shift)
    let label: String

    /// What happens when triggered
    let action: KeyAction

    /// Semantic category — controls behavior like auto-shift, haptics, hint styling.
    /// nil = automatically derived from action (see resolvedCategory).
    let category: KeyCategory?

    /// Optional alternative action for return swipe (swipe out and back)
    let returnAction: KeyAction?

    /// VoiceOver label, only set when different from label (e.g. "Löschen" for "⌫")
    let accessibilityLabel: String?

    /// Category: explicit or automatically derived from the action.
    var resolvedCategory: KeyCategory {
        category ?? action.inferredCategory
    }
}
