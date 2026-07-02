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
    ///
    /// Reads descriptor metadata only — no `KeyboardDefinition` is built, so
    /// listing languages (and the extension's `primaryLanguage` lookup) stays
    /// cheap at launch.
    static let available: [KeyboardInfo] = LanguageDefinitions.all.map { KeyboardInfo(from: $0) }

    /// Precomputed index for O(1) descriptor lookup by id. Holds descriptors
    /// (metadata + lazy builders), not built definitions.
    private static let descriptorsByID: [String: LanguageDescriptor] =
        LanguageDefinitions.all.reduce(into: [:]) { dict, descriptor in
            dict[descriptor.id] = descriptor
        }

    /// Cache for loaded definitions. Only languages actually loaded via
    /// `load(id:)` are built and held here.
    ///
    /// Guarded by `cacheLock`: the extension only touches the registry from
    /// the main thread, but tests (and any future background use) may call it
    /// concurrently — an unsynchronized dictionary crashes with SIGSEGV in
    /// `Dictionary._Variant.setValue` under parallel access.
    private static var cache: [String: KeyboardDefinition] = [:]
    private static let cacheLock = NSLock()

    /// Loads the full definition for a keyboard ID, building it lazily on first
    /// use and caching the result.
    static func load(id: String) -> KeyboardDefinition? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[id] { return cached }
        guard let descriptor = descriptorsByID[id] else {
            return nil
        }
        let definition = descriptor.makeDefinition()
        cache[id] = definition
        return definition
    }

    /// Removes a cached definition (e.g. on memory warning).
    static func evict(id: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: id)
    }

    /// Clears the entire cache. Active definitions are rebuilt lazily on next
    /// `load(id:)`.
    static func evictAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    /// Evicts every cached definition except the given id. Used on memory
    /// warnings to free inactive layouts while keeping the active one resident.
    static func evictAll(except keepID: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache = cache.filter { $0.key == keepID }
    }

    /// Whether a definition is currently cached (for testing).
    static func isCached(id: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[id] != nil
    }
}
