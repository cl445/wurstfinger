//
//  LanguageMetadata.swift
//  Wurstfinger
//
//  Lightweight metadata for one keyboard language.
//

import Foundation

/// Lightweight metadata for one keyboard language: everything the language
/// list, the settings UI and the startup lookup need, without materialising a
/// layout. The layouts themselves are declared in `LanguageDefinitions.swift`
/// and built on demand by `KeyboardRegistry`.
///
/// This is the value half of the language model, `LanguageDescriptor` the
/// authoring half. The descriptor additionally carries the builder that
/// produces a `KeyboardDefinition`, so it only exists where a layout is
/// declared; metadata carries no builder and is therefore constructible
/// anywhere. That is what the settings API needs: `LanguageSettings` hands
/// languages out by value and has to be able to name the `english` fallback
/// without going through the registry.
struct LanguageMetadata: Identifiable {
    let id: String
    let title: String
    let localeIdentifier: String

    /// The locale this language types in. Derived, so the identifier stays the
    /// single source of truth.
    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    init(id: String, title: String, localeIdentifier: String) {
        self.id = id
        self.title = title
        self.localeIdentifier = localeIdentifier
    }

    /// Builds metadata from a descriptor without materialising its layout.
    init(from descriptor: LanguageDescriptor) {
        id = descriptor.id
        title = descriptor.title
        localeIdentifier = descriptor.localeIdentifier
    }
}

extension LanguageMetadata: Equatable {
    /// Compares by id only. IDs are unique across `KeyboardRegistry.available`.
    static func == (lhs: LanguageMetadata, rhs: LanguageMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

extension LanguageMetadata {
    // MARK: - Derived from KeyboardRegistry

    /// English fallback (hardcoded ID only; the full metadata comes from the registry).
    static let english = LanguageMetadata(
        id: "en_US", title: "English", localeIdentifier: "en_US"
    )

    /// All supported languages, derived from `KeyboardRegistry.available` and
    /// sorted by display title. This is the single source of truth --
    /// adding a new `KeyboardDefinition` to `LanguageDefinitions.all`
    /// automatically surfaces it here.
    ///
    /// Computed on every access so callers always see the current registry
    /// state (important for tests that mutate `KeyboardRegistry`).
    static var allLanguages: [LanguageMetadata] {
        sortedByTitle(KeyboardRegistry.available)
    }

    /// Display order for the language list: `localizedStandardCompare` puts the
    /// titles where the user's locale expects them (case- and diacritic-aware,
    /// Finder-style), which a bare `<` — a UTF-16 code-unit comparison — does not.
    static func sortedByTitle(_ languages: [LanguageMetadata]) -> [LanguageMetadata] {
        languages.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Get language metadata by ID.
    static func language(withId id: String) -> LanguageMetadata? {
        allLanguages.first { $0.id == id }
    }
}
