//
//  KeyboardRegistry.swift
//  Wurstfinger
//
//  Registry for keyboard layouts with lazy loading and caching.
//

import Foundation

/// Registry for keyboard layouts.
/// Exposes lightweight metadata via `available` and loads full definitions on demand.
enum KeyboardRegistry {
    /// All available keyboard layouts (lightweight metadata only).
    static let available: [KeyboardInfo] = LanguageDefinitions.all.map { KeyboardInfo(from: $0) }

    /// Cache for loaded definitions.
    private static var cache: [String: KeyboardDefinition] = [:]

    /// Loads the full definition for a keyboard ID, caching the result.
    static func load(id: String) -> KeyboardDefinition? {
        if let cached = cache[id] { return cached }
        guard let definition = LanguageDefinitions.all.first(where: { $0.id == id }) else {
            return nil
        }
        cache[id] = definition
        return definition
    }

    /// Removes a cached definition (e.g. on memory warning).
    static func evict(id: String) {
        cache.removeValue(forKey: id)
    }

    /// Clears the entire cache.
    static func evictAll() {
        cache.removeAll()
    }

    /// Whether a definition is currently cached (for testing).
    static func isCached(id: String) -> Bool {
        cache[id] != nil
    }
}
