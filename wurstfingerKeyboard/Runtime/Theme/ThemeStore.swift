//
//  ThemeStore.swift
//  Wurstfinger
//
//  Theme lookup, user-theme persistence, and legacy migration.
//
//  Cross-process note: App-Group defaults do NOT deliver live updates between
//  host app and extension. The extension re-reads on every appearance (its
//  root view resolves per launch); only same-process observers (previews) are
//  live via @AppStorage.
//

import Foundation
import SwiftUI

enum ThemeStore {
    // MARK: - Persistence Format

    /// Envelope around persisted user themes. `schemaVersion` starts at 1;
    /// this format doubles as the future export wire format, so encode with
    /// sorted keys and decode tolerantly.
    struct Archive: Equatable {
        var schemaVersion: Int
        var themes: [KeyboardThemeDefinition]

        static let currentSchemaVersion = 1
    }

    /// Decodes the archive from defaults. Lossy on purpose: a corrupt entry
    /// is skipped instead of destroying all user themes, and entries claiming
    /// a built-in id are dropped (built-in status is derived, never trusted).
    static func userThemes(defaults: UserDefaults = SharedDefaults.store) -> [KeyboardThemeDefinition] {
        guard let data = defaults.data(forKey: SettingsKey.userThemes.rawValue) else {
            return []
        }
        let archive = try? JSONDecoder().decode(Archive.self, from: data)
        return archive?.themes ?? []
    }

    static func writeUserThemes(_ themes: [KeyboardThemeDefinition], defaults: UserDefaults = SharedDefaults.store) {
        let archive = Archive(schemaVersion: Archive.currentSchemaVersion, themes: themes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(archive) else { return }
        defaults.set(data, forKey: SettingsKey.userThemes.rawValue)
    }

    // MARK: - Lookup

    /// Built-ins never touch the user-theme blob, so the common case decodes
    /// nothing on extension launch.
    static func theme(id: String, defaults: UserDefaults = SharedDefaults.store) -> KeyboardThemeDefinition? {
        if let builtIn = BuiltInThemes.theme(id: id) {
            return builtIn
        }
        return userThemes(defaults: defaults).first { $0.id == id }
    }

    /// The theme for the given appearance, applying the fallback cascade:
    /// assigned slot → other slot → Classic.
    static func selectedTheme(
        for colorScheme: ColorScheme,
        defaults: UserDefaults = SharedDefaults.store
    ) -> KeyboardThemeDefinition {
        let lightId = defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) ?? BuiltInThemes.classic.id
        let darkId = defaults.string(forKey: SettingsKey.selectedThemeDark.rawValue) ?? lightId
        let (primary, secondary) = colorScheme == .dark ? (darkId, lightId) : (lightId, darkId)
        return theme(id: primary, defaults: defaults)
            ?? theme(id: secondary, defaults: defaults)
            ?? BuiltInThemes.classic
    }

    // MARK: - Migration

    /// One-time migration from the legacy `keyboardStyle` setting to the
    /// theme assignment. Idempotent and race-safe: host app and extension may
    /// both run this concurrently — both derive the same deterministic values
    /// and only write when the new keys are still absent.
    static func migrateIfNeeded(defaults: UserDefaults = SharedDefaults.store) {
        guard let legacy = defaults.string(forKey: SettingsKey.keyboardStyle.rawValue) else {
            return
        }
        if defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == nil {
            let id = switch legacy {
            case "liquidGlass": BuiltInThemes.liquidGlass.id
            case "darkGold": BuiltInThemes.darkGold.id
            default: BuiltInThemes.classic.id
            }
            defaults.set(id, forKey: SettingsKey.selectedThemeLight.rawValue)
            defaults.set(id, forKey: SettingsKey.selectedThemeDark.rawValue)
        }
        defaults.removeObject(forKey: SettingsKey.keyboardStyle.rawValue)
    }
}

extension ThemeStore.Archive: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, themes
    }

    /// Wrapper that swallows per-element decode failures.
    private struct FailableTheme: Decodable {
        let value: KeyboardThemeDefinition?

        init(from decoder: Decoder) {
            value = try? KeyboardThemeDefinition(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        let raw = try container.decodeIfPresent([FailableTheme].self, forKey: .themes) ?? []
        themes = raw.compactMap(\.value).filter { !BuiltInThemes.ids.contains($0.id) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(themes, forKey: .themes)
    }
}
