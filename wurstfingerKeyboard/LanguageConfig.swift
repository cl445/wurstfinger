//
//  LanguageConfig.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Foundation

/// Lightweight language metadata. The actual key layout is defined in
/// `LanguageDefinitions.swift` and loaded via `KeyboardRegistry`.
struct LanguageConfig: Identifiable {
    let id: String
    let name: String
    let locale: Locale
}

extension LanguageConfig: Equatable {
    /// Compares by id only. IDs are unique across `KeyboardRegistry.available`.
    static func == (lhs: LanguageConfig, rhs: LanguageConfig) -> Bool {
        lhs.id == rhs.id
    }
}

extension LanguageConfig {
    // MARK: - Derived from KeyboardRegistry

    /// English fallback (hardcoded ID only; the full config comes from the registry).
    static let english = LanguageConfig(
        id: "en_US", name: "English", locale: Locale(identifier: "en_US")
    )

    /// All supported languages, derived from `KeyboardRegistry.available` and
    /// sorted alphabetically by name. This is the single source of truth --
    /// adding a new `KeyboardDefinition` to `LanguageDefinitions.all`
    /// automatically surfaces it here.
    ///
    /// Computed on every access so callers always see the current registry
    /// state (important for tests that mutate `KeyboardRegistry`).
    static var allLanguages: [LanguageConfig] {
        KeyboardRegistry.available.map { info in
            LanguageConfig(
                id: info.id,
                name: info.title,
                locale: Locale(identifier: info.localeIdentifier)
            )
        }.sorted { $0.name < $1.name }
    }

    /// Get language config by ID.
    static func language(withId id: String) -> LanguageConfig? {
        allLanguages.first { $0.id == id }
    }
}
