//
//  LanguageSettingsTests.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct LanguageSettingsTests {
    @Test("Detects German with exact match")
    func detectGermanExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["de-DE"])
        #expect(result == "de_DE")
    }

    @Test("Detects German with language-only match")
    func detectGermanLanguageOnly() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["de-AT"])
        #expect(result == "de_DE")
    }

    @Test("Detects French with exact match")
    func detectFrenchExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["fr-FR"])
        #expect(result == "fr_FR")
    }

    @Test("Detects Spanish with exact match")
    func detectSpanishExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["es-ES"])
        #expect(result == "es_ES")
    }

    @Test("Detects Italian with exact match")
    func detectItalianExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["it-IT"])
        #expect(result == "it_IT")
    }

    @Test("Detects Polish with exact match")
    func detectPolishExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["pl-PL"])
        #expect(result == "pl_PL")
    }

    @Test("Detects Russian with exact match")
    func detectRussianExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["ru-RU"])
        #expect(result == "ru_RU")
    }

    @Test("Detects Swedish with exact match")
    func detectSwedishExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["sv-SE"])
        #expect(result == "sv_SE")
    }

    @Test("Detects Finnish with exact match")
    func detectFinnishExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["fi-FI"])
        #expect(result == "fi_FI")
    }

    @Test("Detects Croatian with exact match")
    func detectCroatianExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["hr-HR"])
        #expect(result == "hr_HR")
    }

    @Test("Detects Hebrew with exact match")
    func detectHebrewExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["he-IL"])
        #expect(result == "he_IL")
    }

    @Test("Detects Tagalog with exact match")
    func detectTagalogExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["tl-PH"])
        #expect(result == "tl_PH")
    }

    @Test("Falls back to English for unsupported language")
    func fallbackToEnglish() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["ja-JP"])
        #expect(result == "en_US")
    }

    @Test("Falls back to English when no languages provided")
    func fallbackToEnglishEmpty() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: [])
        #expect(result == "en_US")
    }

    @Test("Prefers first matching language in list")
    func prefersFirstMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["fr-FR", "de-DE", "en-US"])
        #expect(result == "fr_FR")
    }

    @Test("Skips unsupported and picks first supported")
    func skipsUnsupportedPicksSupported() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["ja-JP", "de-DE", "en-US"])
        #expect(result == "de_DE")
    }

    @Test("Detects Spanish-Catalan with exact match")
    func detectSpanishCatalanExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["ca-ES"])
        #expect(result == "ca_ES")
    }

    @Test("Detects Estonian-Finnish with exact match")
    func detectEstonianFinnishExactMatch() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["et-EE"])
        #expect(result == "et_EE")
    }

    @Test("Matches English variants to en_US")
    func matchesEnglishVariants() {
        let resultGB = LanguageSettings.detectSystemLanguage(preferredLanguages: ["en-GB"])
        #expect(resultGB == "en_US")

        let resultAU = LanguageSettings.detectSystemLanguage(preferredLanguages: ["en-AU"])
        #expect(resultAU == "en_US")

        let resultCA = LanguageSettings.detectSystemLanguage(preferredLanguages: ["en-CA"])
        #expect(resultCA == "en_US")
    }

    @Test("Matches French variants to fr_FR")
    func matchesFrenchVariants() {
        let result = LanguageSettings.detectSystemLanguage(preferredLanguages: ["fr-CA"])
        #expect(result == "fr_FR")
    }

    @Test("Matches Spanish variants to es_ES")
    func matchesSpanishVariants() {
        let resultMX = LanguageSettings.detectSystemLanguage(preferredLanguages: ["es-MX"])
        #expect(resultMX == "es_ES")

        let resultAR = LanguageSettings.detectSystemLanguage(preferredLanguages: ["es-AR"])
        #expect(resultAR == "es_ES")
    }

    // MARK: - Language ID Normalization Tests

    @Test("Unknown language ID resolves to English via LanguageConfig")
    func unknownLanguageIdResolvesToEnglish() {
        // If a stale or unknown language ID is stored, LanguageConfig.language(withId:) returns nil
        let unknownId = "zz_ZZ"
        let resolved = LanguageConfig.language(withId: unknownId)?.id ?? LanguageConfig.english.id
        #expect(resolved == "en_US")
    }

    @Test("Valid language ID resolves to itself")
    func validLanguageIdResolvesToItself() {
        let validId = "de_DE"
        let resolved = LanguageConfig.language(withId: validId)?.id ?? LanguageConfig.english.id
        #expect(resolved == "de_DE")
    }

    @Test("All known language IDs resolve correctly")
    func allKnownLanguageIdsResolve() {
        for language in LanguageConfig.allLanguages {
            let resolved = LanguageConfig.language(withId: language.id)
            #expect(resolved != nil, "Language \(language.id) should resolve")
            #expect(resolved?.id == language.id)
        }
    }
}

// MARK: - Primary Language Resolution Tests

/// Tests the logic that resolves a language ID from UserDefaults into a locale identifier,
/// matching the primaryLanguage getter in KeyboardViewController.
struct PrimaryLanguageResolutionTests {
    /// Helper that mirrors the primaryLanguage getter logic:
    /// read language ID from UserDefaults → resolve to LanguageConfig → return locale identifier
    private func resolvePrimaryLanguage(from defaults: UserDefaults) -> String {
        let languageId = defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue)
        let config = languageId.flatMap { LanguageConfig.language(withId: $0) } ?? .english
        return config.locale.identifier
    }

    private func createTestDefaults() -> (UserDefaults, String) {
        let suiteName = "test.primaryLanguage.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    @Test("Returns German locale when German is selected")
    func resolveGerman() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "de_DE")
    }

    @Test("Returns French locale when French is selected")
    func resolveFrench() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("fr_FR", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "fr_FR")
    }

    @Test("Returns Russian locale when Russian is selected")
    func resolveRussian() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("ru_RU", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "ru_RU")
    }

    @Test("Falls back to English when no language is stored")
    func fallbackWhenNoLanguageStored() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Don't set any value — should fall back to English
        #expect(resolvePrimaryLanguage(from: defaults) == "en_US")
    }

    @Test("Falls back to English for unknown language ID")
    func fallbackForUnknownLanguageId() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("xx_XX", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "en_US")
    }

    @Test("Picks up language change from UserDefaults without restart")
    func picksUpLanguageChange() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "de_DE")

        // Simulate host app changing language
        defaults.set("fr_FR", forKey: SettingsKey.selectedLanguageId.rawValue)
        #expect(resolvePrimaryLanguage(from: defaults) == "fr_FR")
    }

    @Test("All supported languages resolve to valid locale identifiers")
    func allLanguagesResolveToValidLocale() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        for language in LanguageConfig.allLanguages {
            defaults.set(language.id, forKey: SettingsKey.selectedLanguageId.rawValue)
            let resolved = resolvePrimaryLanguage(from: defaults)
            #expect(
                resolved == language.locale.identifier,
                "Language \(language.name) (\(language.id)) should resolve to \(language.locale.identifier), got \(resolved)"
            )
        }
    }
}

// MARK: - Multi-Language Settings Tests

struct MultiLanguageSettingsTests {
    private func createTestDefaults() -> (UserDefaults, String) {
        let suiteName = "test.multiLang.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private func createSettings(defaults: UserDefaults, selectedId: String = "en_US", enabledIds: [String]? = nil) -> LanguageSettings {
        defaults.set(selectedId, forKey: SettingsKey.selectedLanguageId.rawValue)
        if let enabledIds {
            LanguageSettings.saveEnabledLanguageIds(enabledIds, to: defaults)
        }
        return LanguageSettings(userDefaults: defaults)
    }

    @Test("Migration: no enabled list seeds from selected language")
    func migrationSeedsFromSelected() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "de_DE")
        #expect(settings.enabledLanguageIds == ["de_DE"])
        #expect(settings.selectedLanguageId == "de_DE")
    }

    @Test("Loads existing enabled list from UserDefaults")
    func loadsEnabledList() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU", "de_DE"])
        #expect(settings.enabledLanguageIds == ["en_US", "ru_RU", "de_DE"])
    }

    @Test("Toggle enables a language")
    func toggleEnablesLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        settings.toggleLanguage(.russian)
        #expect(settings.enabledLanguageIds.contains("ru_RU"))
        #expect(settings.enabledLanguageIds.count == 2)
    }

    @Test("Toggle disables an enabled language")
    func toggleDisablesLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU", "de_DE"])
        let result = settings.toggleLanguage(.russian)
        #expect(result == true)
        #expect(!settings.enabledLanguageIds.contains("ru_RU"))
        #expect(settings.enabledLanguageIds.count == 2)
    }

    @Test("Cannot disable last remaining language")
    func cannotDisableLastLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        let result = settings.toggleLanguage(.english)
        #expect(result == false)
        #expect(settings.enabledLanguageIds == ["en_US"])
    }

    @Test("Disabling selected language switches to first enabled")
    func disablingSelectedSwitchesToFirst() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "ru_RU", enabledIds: ["en_US", "ru_RU", "de_DE"])
        settings.toggleLanguage(.russian)
        #expect(settings.selectedLanguageId == "en_US")
    }

    @Test("Selecting a language adds it to enabled if not present")
    func selectAddsToEnabled() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        settings.selectLanguage(.russian)
        #expect(settings.selectedLanguageId == "ru_RU")
        #expect(settings.enabledLanguageIds.contains("ru_RU"))
    }

    @Test("Next language cycles through enabled list with 2 languages")
    func nextLanguageCyclesTwoLanguages() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        #expect(settings.nextLanguageId(after: "en_US") == "ru_RU")
        #expect(settings.nextLanguageId(after: "ru_RU") == "en_US")
    }

    @Test("Next language cycles through enabled list with 3 languages")
    func nextLanguageCyclesThreeLanguages() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU", "de_DE"])
        #expect(settings.nextLanguageId(after: "en_US") == "ru_RU")
        #expect(settings.nextLanguageId(after: "ru_RU") == "de_DE")
        #expect(settings.nextLanguageId(after: "de_DE") == "en_US")
    }

    @Test("Next language cycles through many enabled languages")
    func nextLanguageCyclesManyLanguages() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let ids = ["en_US", "ru_RU", "de_DE", "fr_FR", "es_ES"]
        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ids)
        for i in 0 ..< ids.count {
            let next = settings.nextLanguageId(after: ids[i])
            let expectedIndex = (i + 1) % ids.count
            #expect(next == ids[expectedIndex], "After \(ids[i]) expected \(ids[expectedIndex]), got \(next)")
        }
    }

    @Test("Next language returns same when only one enabled")
    func nextLanguageSingleLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        #expect(settings.nextLanguageId(after: "en_US") == "en_US")
    }

    @Test("Next language falls back to first when current not in list")
    func nextLanguageFallsBackWhenNotInList() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        #expect(settings.nextLanguageId(after: "de_DE") == "en_US")
    }

    @Test("hasMultipleLanguages reflects enabled count")
    func hasMultipleLanguagesFlag() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let single = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        #expect(single.hasMultipleLanguages == false)

        let multi = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        #expect(multi.hasMultipleLanguages == true)
    }

    @Test("currentLanguageLabel returns uppercase language code")
    func languageLabelUppercase() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let enSettings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US"])
        #expect(enSettings.currentLanguageLabel == "EN")

        let ruSettings = createSettings(defaults: defaults, selectedId: "ru_RU", enabledIds: ["ru_RU"])
        #expect(ruSettings.currentLanguageLabel == "RU")

        let deSettings = createSettings(defaults: defaults, selectedId: "de_DE", enabledIds: ["de_DE"])
        #expect(deSettings.currentLanguageLabel == "DE")
    }

    @Test("enabledLanguages returns resolved LanguageConfig objects")
    func enabledLanguagesResolved() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU", "de_DE"])
        let configs = settings.enabledLanguages
        #expect(configs.count == 3)
        #expect(configs[0].id == "en_US")
        #expect(configs[1].id == "ru_RU")
        #expect(configs[2].id == "de_DE")
    }

    @Test("Stale IDs in enabled list are filtered out on load")
    func staleIdsFiltered() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "zz_ZZ", "ru_RU"])
        #expect(settings.enabledLanguageIds == ["en_US", "ru_RU"])
    }

    @Test("Init reselects the first enabled language when selected is not enabled")
    func selectedNotEnabledReselectsFirstEnabled() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Selected is ru_RU but enabled list only has en_US — this state arises
        // when the language was disabled elsewhere; the disable must win, so the
        // selection falls back instead of re-enabling ru_RU.
        let settings = createSettings(defaults: defaults, selectedId: "ru_RU", enabledIds: ["en_US"])
        #expect(settings.selectedLanguageId == "en_US")
        #expect(settings.enabledLanguageIds == ["en_US"])
        // The corrected selection is persisted for the keyboard extension.
        #expect(defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) == "en_US")
    }

    @Test("Enabled list persistence round-trips through JSON")
    func enabledListPersistence() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let ids = ["en_US", "ru_RU", "de_DE", "fr_FR"]
        LanguageSettings.saveEnabledLanguageIds(ids, to: defaults)
        let loaded = LanguageSettings.loadEnabledLanguageIds(from: defaults)
        #expect(loaded == ids)
    }

    @Test("isLanguageEnabled reflects enabled state")
    func isLanguageEnabledCheck() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        #expect(settings.isLanguageEnabled(.english) == true)
        #expect(settings.isLanguageEnabled(.russian) == true)
        #expect(settings.isLanguageEnabled(.german) == false)
    }
}

// MARK: - Pinned Default Language Tests

struct PinnedLanguageTests {
    private func createTestDefaults() -> (UserDefaults, String) {
        let suiteName = "test.pinned.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private func createSettings(
        defaults: UserDefaults,
        selectedId: String = "en_US",
        enabledIds: [String],
        pinnedId: String? = nil
    ) -> LanguageSettings {
        defaults.set(selectedId, forKey: SettingsKey.selectedLanguageId.rawValue)
        LanguageSettings.saveEnabledLanguageIds(enabledIds, to: defaults)
        defaults.set(pinnedId, forKey: SettingsKey.pinnedLanguageId.rawValue)
        return LanguageSettings(userDefaults: defaults)
    }

    @Test("Pin a language sets pinnedLanguageId")
    func pinSetsId() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"])
        settings.pinLanguage(.russian)
        #expect(settings.pinnedLanguageId == "ru_RU")
    }

    @Test("Unpin by tapping the same language")
    func unpinSameLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        settings.pinLanguage(.russian)
        #expect(settings.pinnedLanguageId == nil)
    }

    @Test("Pin a different language replaces the previous pin")
    func pinDifferentLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"], pinnedId: "en_US")
        settings.pinLanguage(.russian)
        #expect(settings.pinnedLanguageId == "ru_RU")
    }

    @Test("Pinning a disabled language enables it first")
    func pinDisabledLanguageEnablesIt() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US"])
        settings.pinLanguage(.russian)
        #expect(settings.pinnedLanguageId == "ru_RU")
        #expect(settings.enabledLanguageIds.contains("ru_RU"))
    }

    @Test("Disabling the pinned language clears the pin")
    func disablingPinnedLanguageClearsPin() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        settings.toggleLanguage(.russian)
        #expect(settings.pinnedLanguageId == nil)
    }

    @Test("startupLanguageId returns pinned when set")
    func startupReturnsPinned() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        #expect(settings.startupLanguageId == "ru_RU")
    }

    @Test("startupLanguageId returns selectedLanguageId when no pin")
    func startupReturnsSelectedWhenNoPin() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        #expect(settings.startupLanguageId == "en_US")
    }

    @Test("applyStartupLanguage makes the pinned language the active selection")
    func applyStartupHonorsPin() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        settings.applyStartupLanguage()

        // The cold-start selection — and the persisted value the extension reads —
        // now reflect the pin, so the keyboard boots in the pinned language.
        #expect(settings.selectedLanguageId == "ru_RU")
        #expect(defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) == "ru_RU")
    }

    @Test("applyStartupLanguage leaves the selection unchanged when no pin")
    func applyStartupNoPinKeepsSelection() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, selectedId: "en_US", enabledIds: ["en_US", "ru_RU"])
        settings.applyStartupLanguage()

        #expect(settings.selectedLanguageId == "en_US")
    }

    @Test("Stale pinned ID is cleared on load")
    func stalePinnedIdCleared() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"], pinnedId: "zz_ZZ")
        #expect(settings.pinnedLanguageId == nil)
    }

    @Test("Pinned ID not in enabled list is cleared on load")
    func pinnedNotInEnabledCleared() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US"], pinnedId: "ru_RU")
        #expect(settings.pinnedLanguageId == nil)
    }

    @Test("pinnedLanguage returns resolved LanguageConfig")
    func pinnedLanguageResolved() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        #expect(settings.pinnedLanguage?.id == "ru_RU")
    }

    @Test("pinnedLanguage is nil when no pin")
    func pinnedLanguageNilWhenNoPin() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"])
        #expect(settings.pinnedLanguage == nil)
    }

    @Test("Pin persists to UserDefaults")
    func pinPersists() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"])
        settings.pinLanguage(.russian)
        let stored = defaults.string(forKey: SettingsKey.pinnedLanguageId.rawValue)
        #expect(stored == "ru_RU")
    }

    @Test("Unpin persists nil to UserDefaults")
    func unpinPersistsNil() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = createSettings(defaults: defaults, enabledIds: ["en_US", "ru_RU"], pinnedId: "ru_RU")
        settings.pinLanguage(.russian)
        let stored = defaults.string(forKey: SettingsKey.pinnedLanguageId.rawValue)
        #expect(stored == nil)
    }

    @Test("KeyboardViewModel boots with pinned language, not selected")
    func viewModelBootsWithPinnedLanguage() {
        let (defaults, suite) = createTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("en_US", forKey: SettingsKey.selectedLanguageId.rawValue)
        LanguageSettings.saveEnabledLanguageIds(["en_US", "ru_RU"], to: defaults)
        defaults.set("ru_RU", forKey: SettingsKey.pinnedLanguageId.rawValue)

        let viewModel = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        let target = MockTextTarget()
        viewModel.bindTextInputTarget(target)
        viewModel.bindViewControllerActions(advanceToNextInputMode: {}, dismissKeyboard: {})

        let startupId = LanguageSettings(userDefaults: defaults).startupLanguageId
        viewModel.loadDefinition(for: startupId)

        #expect(
            viewModel.pipelineLocale?.identifier == "ru_RU",
            "ViewModel should boot with pinned language ru_RU, not selected en_US"
        )
    }
}

// MARK: - Info.plist PrimaryLanguage Tests

struct InfoPlistLanguageTests {
    @Test("Keyboard extension Info.plist has PrimaryLanguage set to mul")
    func primaryLanguageIsMul() throws {
        // Read the keyboard extension's Info.plist directly from the source tree
        // This catches accidental changes before they ship
        let testFile = URL(fileURLWithPath: #filePath)
        let projectDir = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let plistURL = projectDir.appendingPathComponent("wurstfingerKeyboard/Info.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dict = try #require(plist as? [String: Any])
        let extensionDict = try #require(dict["NSExtension"] as? [String: Any])
        let attributes = try #require(extensionDict["NSExtensionAttributes"] as? [String: Any])
        let primaryLanguage = try #require(attributes["PrimaryLanguage"] as? String)
        #expect(
            primaryLanguage == "mul",
            "PrimaryLanguage should be 'mul' (multi-language), not a single language code"
        )
    }
}

// MARK: - resolvedLanguageId

struct ResolvedLanguageIdTests {
    @Test("Keeps a valid stored id")
    func keepsValidId() {
        #expect(LanguageSettings.resolvedLanguageId("de_DE") == "de_DE")
    }

    @Test("Falls back for a stale/unknown id")
    func fallsBackForUnknownId() {
        // Contract: stale/unknown → detected system language (not just "any valid id").
        #expect(LanguageSettings.resolvedLanguageId("xx_XX") == LanguageSettings.detectSystemLanguage())
    }

    @Test("Falls back for nil")
    func fallsBackForNil() {
        #expect(LanguageSettings.resolvedLanguageId(nil) == LanguageSettings.detectSystemLanguage())
    }
}

// MARK: - normalizedEnabledLanguageIds

struct NormalizedEnabledLanguageIdsTests {
    private func makeDefaults(selected: String, enabled: [String]?) -> (UserDefaults, String) {
        let suite = "test.normalized.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(selected, forKey: SettingsKey.selectedLanguageId.rawValue)
        if let enabled {
            LanguageSettings.saveEnabledLanguageIds(enabled, to: defaults)
        }
        return (defaults, suite)
    }

    @Test("Filters out stale/unknown enabled IDs")
    func filtersStaleIds() {
        let (defaults, suite) = makeDefaults(selected: "de_DE", enabled: ["de_DE", "zz_ZZ", "en_US"])
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(LanguageSettings.normalizedEnabledLanguageIds(from: defaults) == ["de_DE", "en_US"])
    }

    @Test("Falls back to the selected language when the stored list is empty")
    func emptyFallsBackToSelected() {
        let (defaults, suite) = makeDefaults(selected: "ru_RU", enabled: [])
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(LanguageSettings.normalizedEnabledLanguageIds(from: defaults) == ["ru_RU"])
    }

    @Test("Does not re-add a selected language missing from the stored list")
    func doesNotReAddSelectedWhenAbsent() {
        // selected = de_DE with de_DE absent from the enabled list means the
        // host app disabled German after the keyboard selected it — treating it
        // as enabled again would resurrect a language the user turned off.
        let (defaults, suite) = makeDefaults(selected: "de_DE", enabled: ["en_US"])
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(LanguageSettings.normalizedEnabledLanguageIds(from: defaults) == ["en_US"])
    }

    @Test("Does not persist — leaves the stored list untouched")
    func doesNotPersist() {
        let (defaults, suite) = makeDefaults(selected: "de_DE", enabled: ["de_DE", "zz_ZZ"])
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = LanguageSettings.normalizedEnabledLanguageIds(from: defaults)
        #expect(LanguageSettings.loadEnabledLanguageIds(from: defaults) == ["de_DE", "zz_ZZ"])
    }
}

// MARK: - Cross-Process Staleness

/// The host app holds `LanguageSettings.shared` for its whole lifetime while
/// the keyboard extension writes `selectedLanguageId` on every globe-key
/// language cycle. These tests simulate that cross-process drift by writing to
/// the injected in-memory store externally between init and the mutating call.
struct LanguageSettingsStalenessTests {
    /// Store seeded with `selected = en_US`, `enabled = [en_US, de_DE]`.
    private func makeStore() -> InMemoryUserDefaults {
        let defaults = InMemoryUserDefaults()
        defaults.set("en_US", forKey: SettingsKey.selectedLanguageId.rawValue)
        LanguageSettings.saveEnabledLanguageIds(["en_US", "de_DE"], to: defaults)
        return defaults
    }

    @Test("Disabling the externally-selected language reselects a remaining one")
    func toggleRefreshesBeforeDisabling() {
        let defaults = makeStore()
        let settings = LanguageSettings(userDefaults: defaults)

        // The keyboard extension cycles to German while the app is backgrounded.
        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)

        // Back in the app, the user disables German.
        let result = settings.toggleLanguage(.german)

        #expect(result == true)
        #expect(settings.selectedLanguageId == "en_US")
        #expect(settings.enabledLanguageIds == ["en_US"])
        // The store ends consistent: the selection is enabled, German is gone.
        #expect(defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) == "en_US")
        #expect(LanguageSettings.loadEnabledLanguageIds(from: defaults) == ["en_US"])
    }

    @Test("A disabled language stays disabled across a fresh init")
    func disabledLanguageDoesNotResurrect() {
        let defaults = makeStore()
        let settings = LanguageSettings(userDefaults: defaults)

        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)
        settings.toggleLanguage(.german)

        // The next app launch re-reads the store — German must not come back.
        let relaunched = LanguageSettings(userDefaults: defaults)
        #expect(relaunched.enabledLanguageIds == ["en_US"])
        #expect(relaunched.selectedLanguageId == "en_US")
    }

    @Test("Init with an inconsistent store reselects the first enabled language")
    func initNormalizesInconsistentStore() {
        // selected = de_DE while de_DE is not enabled: the state an external
        // writer (or the pre-fix toggle path) can leave behind.
        let defaults = InMemoryUserDefaults()
        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)
        LanguageSettings.saveEnabledLanguageIds(["en_US"], to: defaults)

        let settings = LanguageSettings(userDefaults: defaults)

        #expect(settings.selectedLanguageId == "en_US")
        #expect(settings.enabledLanguageIds == ["en_US"])
        #expect(defaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) == "en_US")
    }

    @Test("reloadFromStore picks up an external language cycle")
    func reloadPicksUpExternalSelection() {
        let defaults = makeStore()
        let settings = LanguageSettings(userDefaults: defaults)

        defaults.set("de_DE", forKey: SettingsKey.selectedLanguageId.rawValue)
        settings.reloadFromStore()

        #expect(settings.selectedLanguageId == "de_DE")
        #expect(settings.enabledLanguageIds == ["en_US", "de_DE"])
    }

    @Test("Pinning an externally-disabled language re-enables and pins it")
    func pinReEnablesExternallyDisabledLanguage() {
        // Deliberate asymmetry to the disable-wins invariant above: a pin is
        // an explicit "use this language" request, so pin implies enabled —
        // even when another process disabled the language in the meantime.
        let defaults = makeStore()
        let settings = LanguageSettings(userDefaults: defaults)

        LanguageSettings.saveEnabledLanguageIds(["en_US"], to: defaults)
        settings.pinLanguage(.german)

        #expect(settings.enabledLanguageIds.contains("de_DE"))
        #expect(settings.pinnedLanguageId == "de_DE")
    }
}
