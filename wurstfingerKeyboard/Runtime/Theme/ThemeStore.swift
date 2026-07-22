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

    /// Resolves the theme for the given appearance from two explicit slot ids,
    /// applying the fallback cascade: assigned slot → other slot → Classic.
    /// This is the single source of truth for slot selection; both the live
    /// keyboard (`DataDrivenKeyboardRootView`) and `selectedTheme(for:)` call it
    /// so the tested path is the rendered path.
    static func theme(
        lightId: String,
        darkId: String,
        for colorScheme: ColorScheme,
        defaults: UserDefaults = SharedDefaults.store
    ) -> KeyboardThemeDefinition {
        let (primary, secondary) = colorScheme == .dark ? (darkId, lightId) : (lightId, darkId)
        return theme(id: primary, defaults: defaults)
            ?? theme(id: secondary, defaults: defaults)
            ?? BuiltInThemes.classic
    }

    /// The theme for the given appearance, reading the slot ids from defaults.
    /// An unset dark slot follows the light slot (both slots track one
    /// selection until the gallery adds separate assignment in M2).
    static func selectedTheme(
        for colorScheme: ColorScheme,
        defaults: UserDefaults = SharedDefaults.store
    ) -> KeyboardThemeDefinition {
        let lightId = defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) ?? BuiltInThemes.classic.id
        let darkId = defaults.string(forKey: SettingsKey.selectedThemeDark.rawValue) ?? lightId
        return theme(lightId: lightId, darkId: darkId, for: colorScheme, defaults: defaults)
    }

    // MARK: - Editing

    /// A user-owned copy of any theme: a fresh UUID id, an un-taken " Copy"
    /// name, and the source's colors. Built-in status is derived from the id,
    /// so the copy is automatically editable and deletable.
    static func duplicate(
        _ source: KeyboardThemeDefinition,
        existing: [KeyboardThemeDefinition]
    ) -> KeyboardThemeDefinition {
        var copy = source
        copy.id = UUID().uuidString
        copy.name = uniqueCopyName(base: source.displayName, existing: existing)
        return copy
    }

    /// "<name> Copy", disambiguated with a numeric suffix if that name is
    /// already taken, so duplicating twice never yields two identical names.
    private static func uniqueCopyName(base: String, existing: [KeyboardThemeDefinition]) -> String {
        let taken = Set(existing.map(\.name))
        let first = String(format: String(localized: "%@ Copy"), base)
        guard taken.contains(first) else { return first }
        var index = 2
        while taken.contains(String(format: String(localized: "%@ Copy %lld"), base, index)) {
            index += 1
        }
        return String(format: String(localized: "%@ Copy %lld"), base, index)
    }

    /// Replaces the theme with the same id, or appends it. Built-in ids are
    /// rejected (they can never become user themes).
    static func upsert(
        _ theme: KeyboardThemeDefinition,
        into list: [KeyboardThemeDefinition]
    ) -> [KeyboardThemeDefinition] {
        guard !BuiltInThemes.ids.contains(theme.id) else { return list }
        var list = list
        if let index = list.firstIndex(where: { $0.id == theme.id }) {
            list[index] = theme
        } else {
            list.append(theme)
        }
        return list
    }

    /// Inserts or updates a user theme in defaults.
    static func saveUserTheme(_ theme: KeyboardThemeDefinition, defaults: UserDefaults = SharedDefaults.store) {
        writeUserThemes(upsert(theme, into: userThemes(defaults: defaults)), defaults: defaults)
    }

    /// Removes a user theme and repoints any slot that selected it back to
    /// Classic, so a deleted theme never leaves a slot resolving to nothing.
    static func deleteUserTheme(id: String, defaults: UserDefaults = SharedDefaults.store) {
        writeUserThemes(userThemes(defaults: defaults).filter { $0.id != id }, defaults: defaults)
        let slots = [SettingsKey.selectedThemeLight, SettingsKey.selectedThemeDark]
        for key in slots where defaults.string(forKey: key.rawValue) == id {
            defaults.set(BuiltInThemes.classic.id, forKey: key.rawValue)
        }
    }

    // MARK: - Migration

    /// One-time migration from the legacy `keyboardStyle` setting to the
    /// light/dark theme assignment. Idempotent for sequential runs (host app
    /// and extension both run it); the derived values are deterministic, so a
    /// second run is a no-op. A concurrent first run has a narrow theoretical
    /// TOCTOU window, but it only opens on the very first launch before any
    /// theme is stored, so it is not reachable in practice.
    static func migrateIfNeeded(defaults: UserDefaults = SharedDefaults.store) {
        guard let legacy = defaults.string(forKey: SettingsKey.keyboardStyle.rawValue) else {
            return
        }
        // Only seed the slots if no selection exists yet; if another run (or the
        // user) already set one, leave it and just drop the stale legacy key.
        if defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == nil {
            let id = switch legacy {
            case "liquidGlass": BuiltInThemes.liquidGlass.id
            // "darkGold" never shipped as a keyboardStyle value; kept so an
            // unreleased dev build's stored value still migrates sensibly.
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
