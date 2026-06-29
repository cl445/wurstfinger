//
//  LanguageSettings.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Foundation

/// Manages keyboard language settings shared between host app and keyboard extension
class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()

    @Published var selectedLanguageId: String {
        didSet {
            save()
        }
    }

    private let userDefaults: UserDefaults
    private let languageKey = SettingsKey.selectedLanguageId.rawValue

    private init() {
        userDefaults = SharedDefaults.store

        // Load saved language or detect from system, then normalize
        let storedLanguageId = userDefaults.string(forKey: languageKey) ?? Self.detectSystemLanguage()
        let resolvedLanguageId = LanguageConfig.language(withId: storedLanguageId)?.id ?? LanguageConfig.english.id
        selectedLanguageId = resolvedLanguageId

        // Persist the resolved ID so other readers (e.g. KeyboardViewModel.reloadLanguage)
        // see the same normalized value
        if resolvedLanguageId != storedLanguageId {
            userDefaults.set(resolvedLanguageId, forKey: languageKey)
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

    /// Detects the system language and returns matching language ID, or English as fallback
    static func detectSystemLanguage(preferredLanguages: [String]? = nil) -> String {
        let preferredLanguages = preferredLanguages ?? Locale.preferredLanguages

        // Try to find a matching language config for the user's preferred languages
        for languageCode in preferredLanguages {
            // Extract language and region (e.g., "de-DE", "en-US", "fr")
            let locale = Locale(identifier: languageCode)
            let language = locale.language.languageCode?.identifier ?? ""
            let region = locale.region?.identifier ?? ""

            // Try exact match first (e.g., "de_DE")
            let exactId = "\(language)_\(region)"
            if let match = LanguageConfig.allLanguages.first(where: { $0.id == exactId }) {
                return match.id
            }

            // Try language-only match (e.g., any German variant for "de")
            if let match = LanguageConfig.allLanguages.first(where: {
                $0.locale.language.languageCode?.identifier == language
            }) {
                return match.id
            }
        }

        // Fallback to English
        return LanguageConfig.english.id
    }

    var selectedLanguage: LanguageConfig {
        LanguageConfig.language(withId: selectedLanguageId) ?? .english
    }

    func selectLanguage(_ language: LanguageConfig) {
        selectedLanguageId = language.id
    }

    private func save() {
        userDefaults.set(selectedLanguageId, forKey: languageKey)
    }
}
