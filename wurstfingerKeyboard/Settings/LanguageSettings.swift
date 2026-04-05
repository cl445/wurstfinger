//
//  LanguageSettings.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

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

    @Published var enabledLanguageIds: [String] {
        didSet {
            saveEnabledLanguages()
        }
    }

    private let userDefaults: UserDefaults
    private let languageKey = SettingsKey.selectedLanguageId.rawValue
    private let enabledKey = SettingsKey.enabledLanguageIds.rawValue

    init(userDefaults: UserDefaults? = nil) {
        let defaults = userDefaults ?? SharedDefaults.store
        self.userDefaults = defaults

        // Load saved language or detect from system, then normalize
        let storedLanguageId = defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue)
            ?? Self.detectSystemLanguage()
        let resolvedLanguageId = LanguageConfig.language(withId: storedLanguageId)?.id
            ?? LanguageConfig.english.id

        // Load enabled languages, migrating from single-language if needed
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

        selectedLanguageId = resolvedLanguageId
        enabledLanguageIds = resolvedEnabled

        // Ensure selected language is in the enabled list
        if !resolvedEnabled.contains(resolvedLanguageId) {
            enabledLanguageIds.insert(resolvedLanguageId, at: 0)
        }

        // Persist normalized values
        if resolvedLanguageId != storedLanguageId {
            defaults.set(resolvedLanguageId, forKey: SettingsKey.selectedLanguageId.rawValue)
        }
        Self.saveEnabledLanguageIds(enabledLanguageIds, to: defaults)
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
        let lang = selectedLanguage.locale.language.languageCode?.identifier ?? selectedLanguageId
        return lang.uppercased()
    }

    func selectLanguage(_ language: LanguageConfig) {
        selectedLanguageId = language.id
        if !enabledLanguageIds.contains(language.id) {
            enabledLanguageIds.append(language.id)
        }
    }

    /// Toggle a language on/off in the enabled list. Returns false if trying to
    /// disable the last remaining language (operation is rejected).
    @discardableResult
    func toggleLanguage(_ language: LanguageConfig) -> Bool {
        if let index = enabledLanguageIds.firstIndex(of: language.id) {
            guard enabledLanguageIds.count > 1 else { return false }
            enabledLanguageIds.remove(at: index)
            // If the removed language was selected, switch to the first enabled
            if selectedLanguageId == language.id {
                selectedLanguageId = enabledLanguageIds[0]
            }
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
        guard enabledLanguageIds.count > 1 else {
            return enabledLanguageIds.first ?? currentId
        }
        guard let currentIndex = enabledLanguageIds.firstIndex(of: currentId) else {
            return enabledLanguageIds[0]
        }
        let nextIndex = (currentIndex + 1) % enabledLanguageIds.count
        return enabledLanguageIds[nextIndex]
    }

    // MARK: - Persistence

    private func save() {
        userDefaults.set(selectedLanguageId, forKey: languageKey)
    }

    private func saveEnabledLanguages() {
        Self.saveEnabledLanguageIds(enabledLanguageIds, to: userDefaults)
    }

    /// Encodes the enabled language IDs as a JSON array string for UserDefaults storage.
    /// Using JSON rather than NSArray ensures clean cross-process serialization.
    static func saveEnabledLanguageIds(_ ids: [String], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(ids),
              let json = String(data: data, encoding: .utf8) else { return }
        defaults.set(json, forKey: SettingsKey.enabledLanguageIds.rawValue)
    }

    static func loadEnabledLanguageIds(from defaults: UserDefaults) -> [String]? {
        guard let json = defaults.string(forKey: SettingsKey.enabledLanguageIds.rawValue),
              let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else {
            return nil
        }
        return ids
    }
}
