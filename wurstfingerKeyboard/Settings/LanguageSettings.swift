//
//  LanguageSettings.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Combine
import Foundation

/// Manages keyboard language settings shared between host app and keyboard extension.
/// Supports multiple enabled languages with in-keyboard cycling.
class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()

    @Published var selectedLanguageId: String {
        didSet {
            save()
        }
    }

    @Published private(set) var enabledLanguageIds: [String] {
        didSet {
            saveEnabledLanguages()
            if let pinned = pinnedLanguageId, !enabledLanguageIds.contains(pinned) {
                pinnedLanguageId = nil
            }
        }
    }

    /// Optional pinned default language. When set, the keyboard always opens
    /// with this language. When nil, it opens with the last-used language.
    /// `private(set)` so writes funnel through `pinLanguage(_:)`, preserving the
    /// "pin implies enabled" invariant.
    @Published private(set) var pinnedLanguageId: String? {
        didSet {
            userDefaults.set(pinnedLanguageId, forKey: SettingsKey.pinnedLanguageId.rawValue)
        }
    }

    private let userDefaults: UserDefaults
    private let languageKey = SettingsKey.selectedLanguageId.rawValue
    private let enabledKey = SettingsKey.enabledLanguageIds.rawValue

    init(userDefaults: UserDefaults? = nil) {
        let defaults = userDefaults ?? SharedDefaults.store
        self.userDefaults = defaults

        // Normalize the saved language through the shared resolver (stale/nil →
        // system language → English) so the host app and the keyboard extension
        // always resolve the same active language.
        let resolvedLanguageId = Self.resolvedLanguageId(
            defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue)
        )

        // Load enabled languages, migrating from a single-language setup if needed
        let storedEnabled = Self.loadEnabledLanguageIds(from: defaults)
        let resolvedEnabled: [String]
        if let stored = storedEnabled, !stored.isEmpty {
            // Filter out any stale/unknown IDs
            let valid = stored.filter { LanguageConfig.language(withId: $0) != nil }
            resolvedEnabled = valid.isEmpty ? [resolvedLanguageId] : valid
        } else {
            // Migration: no enabled list stored yet, seed with current selection
            resolvedEnabled = [resolvedLanguageId]
        }

        // Load pinned language (before enabledLanguageIds didSet can fire)
        let storedPinned = defaults.string(forKey: SettingsKey.pinnedLanguageId.rawValue)

        selectedLanguageId = resolvedLanguageId
        enabledLanguageIds = resolvedEnabled
        pinnedLanguageId = storedPinned

        // Ensure selected language is in the enabled list
        if !resolvedEnabled.contains(resolvedLanguageId) {
            enabledLanguageIds.insert(resolvedLanguageId, at: 0)
        }

        // Clear stale pinned ID
        if let pinned = pinnedLanguageId {
            if !enabledLanguageIds.contains(pinned) || LanguageConfig.language(withId: pinned) == nil {
                pinnedLanguageId = nil
            }
        }

        // Persist normalized values
        if resolvedLanguageId != defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) {
            defaults.set(resolvedLanguageId, forKey: SettingsKey.selectedLanguageId.rawValue)
        }
        Self.saveEnabledLanguageIds(enabledLanguageIds, to: defaults)
        // Clearing a stale pin above happened inside `init`, where `didSet` does
        // not fire — so remove the now-invalid key from storage explicitly,
        // otherwise it would be re-read on the next launch.
        if pinnedLanguageId == nil {
            defaults.removeObject(forKey: SettingsKey.pinnedLanguageId.rawValue)
        }
    }

    /// Resolves a raw/stored language id to one guaranteed to exist in the
    /// registry. If the stored value is missing or stale (e.g. a language
    /// removed in a later version), falls back to the detected system language
    /// — which itself falls back to English. Callers therefore always receive a
    /// renderable language id, so the keyboard never comes up blank.
    static func resolvedLanguageId(_ storedId: String?) -> String {
        if let storedId, LanguageConfig.language(withId: storedId) != nil {
            return storedId
        }
        return detectSystemLanguage()
    }

    // MARK: - Public API

    /// Detects the system language and returns matching language ID, or English as fallback
    static func detectSystemLanguage(preferredLanguages: [String]? = nil) -> String {
        let preferredLanguages = preferredLanguages ?? Locale.preferredLanguages

        for languageCode in preferredLanguages {
            let locale = Locale(identifier: languageCode)
            let language = locale.language.languageCode?.identifier ?? ""
            let region = locale.region?.identifier ?? ""

            let exactId = "\(language)_\(region)"
            if let match = LanguageConfig.allLanguages.first(where: { $0.id == exactId }) {
                return match.id
            }

            if let match = LanguageConfig.allLanguages.first(where: {
                $0.locale.language.languageCode?.identifier == language
            }) {
                return match.id
            }
        }

        return LanguageConfig.english.id
    }

    var selectedLanguage: LanguageConfig {
        LanguageConfig.language(withId: selectedLanguageId) ?? .english
    }

    /// Resolved LanguageConfig objects for enabled IDs, preserving order
    var enabledLanguages: [LanguageConfig] {
        enabledLanguageIds.compactMap { LanguageConfig.language(withId: $0) }
    }

    var hasMultipleLanguages: Bool {
        enabledLanguageIds.count > 1
    }

    /// Short uppercase label for the current language, e.g. "EN", "RU", "DE"
    var currentLanguageLabel: String {
        Self.label(for: selectedLanguage.locale, fallback: selectedLanguageId)
    }

    /// Locale-aware short uppercase label (e.g. "EN", "DE") for a locale.
    /// Centralised so every call site uses the same casing rules (German de_DE,
    /// Turkish dotted/dotless i, …) instead of recreating the casing drift that
    /// caused the original label bug.
    static func label(for locale: Locale, fallback: String = "") -> String {
        let lang = locale.language.languageCode?.identifier ?? fallback
        return lang.uppercased(with: locale)
    }

    var pinnedLanguage: LanguageConfig? {
        pinnedLanguageId.flatMap { LanguageConfig.language(withId: $0) }
    }

    /// Returns the language the keyboard should open with: pinned if set and
    /// valid, otherwise the last-used selected language.
    var startupLanguageId: String {
        if let pinned = pinnedLanguageId, enabledLanguageIds.contains(pinned),
           LanguageConfig.language(withId: pinned) != nil {
            return pinned
        }
        return selectedLanguageId
    }

    /// Applies the startup language preference to the active selection. The
    /// keyboard extension calls this on cold start so a pinned language always
    /// wins; in-keyboard cycling afterwards updates the selection normally.
    func applyStartupLanguage() {
        let startup = startupLanguageId
        if startup != selectedLanguageId {
            selectedLanguageId = startup
        }
    }

    /// Pin a language as the default startup language. If already pinned, unpin it.
    func pinLanguage(_ language: LanguageConfig) {
        if pinnedLanguageId == language.id {
            pinnedLanguageId = nil
        } else {
            if !enabledLanguageIds.contains(language.id) {
                enabledLanguageIds.append(language.id)
            }
            pinnedLanguageId = language.id
        }
    }

    func selectLanguage(_ language: LanguageConfig) {
        if !enabledLanguageIds.contains(language.id) {
            enabledLanguageIds.append(language.id)
        }
        selectedLanguageId = language.id
    }

    /// Toggle a language on/off in the enabled list. Returns false if trying to
    /// disable the last remaining language (operation is rejected).
    @discardableResult
    func toggleLanguage(_ language: LanguageConfig) -> Bool {
        if let index = enabledLanguageIds.firstIndex(of: language.id) {
            guard enabledLanguageIds.count > 1 else { return false }
            if selectedLanguageId == language.id {
                let fallbackId = enabledLanguageIds[index == 0 ? 1 : 0]
                selectedLanguageId = fallbackId
            }
            enabledLanguageIds.remove(at: index)
        } else {
            enabledLanguageIds.append(language.id)
        }
        return true
    }

    func isLanguageEnabled(_ language: LanguageConfig) -> Bool {
        enabledLanguageIds.contains(language.id)
    }

    /// Returns the next language ID after the current one, wrapping around.
    /// If only one language is enabled, returns that same language.
    func nextLanguageId(after currentId: String) -> String {
        Self.nextLanguageId(after: currentId, in: enabledLanguageIds)
    }

    static func nextLanguageId(after currentId: String, in enabledIds: [String]) -> String {
        guard enabledIds.count > 1 else {
            return enabledIds.first ?? currentId
        }
        guard let currentIndex = enabledIds.firstIndex(of: currentId) else {
            return enabledIds[0]
        }
        let nextIndex = (currentIndex + 1) % enabledIds.count
        return enabledIds[nextIndex]
    }

    // MARK: - Persistence

    private func save() {
        userDefaults.set(selectedLanguageId, forKey: languageKey)
    }

    private func saveEnabledLanguages() {
        Self.saveEnabledLanguageIds(enabledLanguageIds, to: userDefaults)
    }

    static func saveEnabledLanguageIds(_ ids: [String], to defaults: UserDefaults) {
        defaults.set(ids, forKey: SettingsKey.enabledLanguageIds.rawValue)
    }

    static func loadEnabledLanguageIds(from defaults: UserDefaults) -> [String]? {
        defaults.stringArray(forKey: SettingsKey.enabledLanguageIds.rawValue)
    }

    /// Returns the enabled language IDs filtered to known languages, guaranteed
    /// non-empty and with the active language included — mirroring the
    /// normalisation the initializer performs, but **without persisting**. Safe
    /// to call repeatedly (e.g. from the keyboard extension's `reloadSettings`)
    /// so a stale or empty stored list can never leave the runtime cycling to an
    /// unknown id.
    static func normalizedEnabledLanguageIds(from defaults: UserDefaults) -> [String] {
        let selected = resolvedLanguageId(defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue))
        let stored = loadEnabledLanguageIds(from: defaults) ?? []
        let valid = stored.filter { LanguageConfig.language(withId: $0) != nil }
        if valid.isEmpty { return [selected] }
        return valid.contains(selected) ? valid : [selected] + valid
    }
}
