//
//  LanguageDescriptor.swift
//  Wurstfinger
//
//  Lazy, lightweight handle to a keyboard language.
//

import Foundation

/// A lazy handle to a keyboard language.
///
/// Holds only the cheap metadata (`id`, `title`, `localeIdentifier`) eagerly.
/// The full `KeyboardDefinition` — which allocates every key, binding and grid
/// arrangement for all modes — is produced on demand via `makeDefinition()`.
///
/// This is what keeps the keyboard **extension launch** cheap: the registry can
/// list every available language and resolve the active one's metadata without
/// materialising a single layout, and only the language actually in use is ever
/// built (and then cached by `KeyboardRegistry`). Loading all layouts eagerly
/// added avoidable memory pressure under the extension's tight budget.
struct LanguageDescriptor: Identifiable {
    let id: String
    let title: String
    let localeIdentifier: String

    /// Builds the full definition. Receives the descriptor so the layout can
    /// reuse the metadata above instead of repeating the literals — keeping the
    /// id/title/locale a single source of truth.
    private let builder: @Sendable (LanguageDescriptor) -> KeyboardDefinition

    init(
        id: String,
        title: String,
        localeIdentifier: String,
        builder: @escaping @Sendable (LanguageDescriptor) -> KeyboardDefinition
    ) {
        self.id = id
        self.title = title
        self.localeIdentifier = localeIdentifier
        self.builder = builder
    }

    /// Produces the full keyboard definition. This allocates the entire layout
    /// on every call, so callers should cache the result (see `KeyboardRegistry`).
    func makeDefinition() -> KeyboardDefinition {
        builder(self)
    }
}
