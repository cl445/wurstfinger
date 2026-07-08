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

        let state = Self.loadNormalizedState(from: defaults)
        selectedLanguageId = state.selected
        enabledLanguageIds = state.enabled
        // Initialize the backing wrapper directly: the Optional property gets
        // an implicit `nil` default, so a plain assignment here would run the
        // setter — and its `didSet` persists to the app group on every
        // construction, even when nothing changed.
        _pinnedLanguageId = Published(initialValue: state.pinned)

        // `didSet` does not fire inside `init`, so persist the normalized
        // values explicitly — otherwise a corrected inconsistency (e.g. a
        // reselected language) would be re-read in its broken form next launch.
        // Every write is change-guarded: an unguarded app-group write fires
        // `UserDefaults.didChangeNotification` on each construction, which
        // makes the keyboard's observer reload settings for nothing.
        if state.selected != defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) {
            defaults.set(state.selected, forKey: SettingsKey.selectedLanguageId.rawValue)
        }
        if state.enabled != Self.loadEnabledLanguageIds(from: defaults) {
            Self.saveEnabledLanguageIds(state.enabled, to: defaults)
        }
        if state.pinned == nil,
           defaults.string(forKey: SettingsKey.pinnedLanguageId.rawValue) != nil {
            defaults.removeObject(forKey: SettingsKey.pinnedLanguageId.rawValue)
        }
    }

    /// Snapshot of the persisted language state after normalization.
    private struct NormalizedState {
        let selected: String
        let enabled: [String]
        let pinned: String?
    }

    /// Reads and normalizes the persisted language state.
    ///
    /// Invariant: the selected language is always a member of the non-empty,
    /// known-languages-only enabled list. When the stored selection is not in
    /// the enabled list — e.g. the keyboard extension cycled to a language that
    /// the host app subsequently disabled — the selection falls back to the
    /// first enabled language instead of re-inserting the disabled one, so an
    /// explicit disable is never silently undone.
    private static func loadNormalizedState(from defaults: UserDefaults) -> NormalizedState {
        // Normalize the saved language through the shared resolver (stale/nil →
        // system language → English) so the host app and the keyboard extension
        // always resolve the same active language.
        let resolvedSelected = resolvedLanguageId(
            defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue)
        )

        // Load enabled languages (filtering stale/unknown IDs), migrating from
        // a single-language setup by seeding with the current selection.
        let stored = loadEnabledLanguageIds(from: defaults) ?? []
        let valid = stored.filter { LanguageConfig.language(withId: $0) != nil }
        let enabled = valid.isEmpty ? [resolvedSelected] : valid

        let selected = enabled.contains(resolvedSelected) ? resolvedSelected : enabled[0]

        // A pin is only valid while its language is enabled and known.
        let storedPinned = defaults.string(forKey: SettingsKey.pinnedLanguageId.rawValue)
        let pinned = storedPinned.flatMap { pin in
            enabled.contains(pin) && LanguageConfig.language(withId: pin) != nil ? pin : nil
        }

        return NormalizedState(selected: selected, enabled: enabled, pinned: pinned)
    }

    /// Re-reads the language state from the backing store, resolving
    /// cross-process drift: the keyboard extension persists `selectedLanguageId`
    /// on every in-keyboard language cycle, so a long-lived instance (the host
    /// app singleton) must refresh before acting on its in-memory copy. Called
    /// automatically before every mutating API and when the app foregrounds.
    func reloadFromStore() {
        let state = Self.loadNormalizedState(from: userDefaults)
        // Only reassign on change so @Published does not emit spurious updates.
        if enabledLanguageIds != state.enabled {
            enabledLanguageIds = state.enabled
        }
        if selectedLanguageId != state.selected {
            selectedLanguageId = state.selected
        }
        if pinnedLanguageId != state.pinned {
            pinnedLanguageId = state.pinned
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
        reloadFromStore()
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
        reloadFromStore()
        if !enabledLanguageIds.contains(language.id) {
            enabledLanguageIds.append(language.id)
        }
        selectedLanguageId = language.id
    }

    /// Toggle a language on/off in the enabled list. Returns false if trying to
    /// disable the last remaining language (operation is rejected).
    @discardableResult
    func toggleLanguage(_ language: LanguageConfig) -> Bool {
        reloadFromStore()
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
    /// non-empty — mirroring the normalisation the initializer performs, but
    /// **without persisting**. Safe to call repeatedly (e.g. from the keyboard
    /// extension's `reloadSettings`) so a stale or empty stored list can never
    /// leave the runtime cycling to an unknown id. A stored selection that is
    /// not in the enabled list is deliberately **not** added back: that state
    /// means the host app disabled the language after the keyboard selected it,
    /// and re-adding it would resurrect a language the user turned off.
    static func normalizedEnabledLanguageIds(from defaults: UserDefaults) -> [String] {
        loadNormalizedState(from: defaults).enabled
    }
}
