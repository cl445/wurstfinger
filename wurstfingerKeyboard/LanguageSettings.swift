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
    private let languageKey = "selectedLanguageId"
    private let appGroupId = "group.de.akator.wurstfinger.shared"

    init() {
        // Use App Group for sharing between app and extension
        if let groupDefaults = UserDefaults(suiteName: appGroupId) {
            self.userDefaults = groupDefaults
        } else {
            self.userDefaults = UserDefaults.standard
            print("Warning: Could not access App Group UserDefaults")
        }

        // Load saved language or detect from system
        self.selectedLanguageId = userDefaults.string(forKey: languageKey) ?? Self.detectSystemLanguage()
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
        LanguageConfig.language(withId: selectedLanguageId) ?? .german
    }

    func selectLanguage(_ language: LanguageConfig) {
        selectedLanguageId = language.id
    }

    private func save() {
        userDefaults.set(selectedLanguageId, forKey: languageKey)
        userDefaults.synchronize()
    }
}
