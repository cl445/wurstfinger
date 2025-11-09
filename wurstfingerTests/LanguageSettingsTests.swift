//
//  LanguageSettingsTests.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

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
}
