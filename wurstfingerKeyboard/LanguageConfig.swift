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
    /// Compares by id only. Safe because all instances are static constants.
    static func == (lhs: LanguageConfig, rhs: LanguageConfig) -> Bool {
        lhs.id == rhs.id
    }
}

extension LanguageConfig {
    // MARK: - Language Definitions

    static let croatian = LanguageConfig(
        id: "hr_HR", name: "Hrvatski (Croatian)", locale: Locale(identifier: "hr_HR")
    )

    static let english = LanguageConfig(
        id: "en_US", name: "English", locale: Locale(identifier: "en_US")
    )

    static let estonianFinnish = LanguageConfig(
        id: "et_EE", name: "Eesti-Suomi (Estonian-Finnish)", locale: Locale(identifier: "et_EE")
    )

    static let finnish = LanguageConfig(
        id: "fi_FI", name: "Suomi (Finnish)", locale: Locale(identifier: "fi_FI")
    )

    static let french = LanguageConfig(
        id: "fr_FR", name: "Français (French)", locale: Locale(identifier: "fr_FR")
    )

    static let german = LanguageConfig(
        id: "de_DE", name: "Deutsch (German)", locale: Locale(identifier: "de_DE")
    )

    static let hebrew = LanguageConfig(
        id: "he_IL", name: "עברית (Hebrew)", locale: Locale(identifier: "he_IL")
    )

    static let italian = LanguageConfig(
        id: "it_IT", name: "Italiano (Italian)", locale: Locale(identifier: "it_IT")
    )

    static let polish = LanguageConfig(
        id: "pl_PL", name: "Polski (Polish)", locale: Locale(identifier: "pl_PL")
    )

    static let russian = LanguageConfig(
        id: "ru_RU", name: "Русский (Russian)", locale: Locale(identifier: "ru_RU")
    )

    static let spanishCatalan = LanguageConfig(
        id: "ca_ES", name: "Español-Català (Spanish-Catalan)", locale: Locale(identifier: "ca_ES")
    )

    static let spanish = LanguageConfig(
        id: "es_ES", name: "Español (Spanish)", locale: Locale(identifier: "es_ES")
    )

    static let swedish = LanguageConfig(
        id: "sv_SE", name: "Svenska (Swedish)", locale: Locale(identifier: "sv_SE")
    )

    static let tagalog = LanguageConfig(
        id: "tl_PH", name: "Tagalog (Filipino)", locale: Locale(identifier: "tl_PH")
    )

    static let vietnamese = LanguageConfig(
        id: "vi_VN", name: "Tiếng Việt (Vietnamese-Telex)", locale: Locale(identifier: "vi_VN")
    )

    // MARK: - Language Registry

    /// All supported languages sorted alphabetically by name
    static let allLanguages: [LanguageConfig] = [
        .spanishCatalan,
        .croatian,
        .english,
        .estonianFinnish,
        .finnish,
        .french,
        .german,
        .hebrew,
        .italian,
        .polish,
        .russian,
        .spanish,
        .swedish,
        .tagalog,
        .vietnamese,
    ].sorted { $0.name < $1.name }

    /// Get language config by ID
    static func language(withId id: String) -> LanguageConfig? {
        allLanguages.first { $0.id == id }
    }
}
