//
//  KeyboardShowcaseLanguageResolutionTests.swift
//  wurstfingerTests
//
//  Tests for the showcase's language-id resolution seam.
//

import Testing
@testable import WurstfingerApp

struct KeyboardShowcaseLanguageResolutionTests {
    /// A `FORCE_LANGUAGE` override wins verbatim over the stored id and the
    /// system default — UI tests may force an id that is not in the registry,
    /// so it must not be routed through the registry-validating helper.
    @Test func forceLanguageOverrideWinsOverStoredAndSystem() {
        #expect(
            KeyboardShowcaseView.resolvedShowcaseLanguageId(
                forceLanguage: "ru_RU",
                storedId: "de_DE"
            ) == "ru_RU"
        )
    }

    /// Without an override, a stale/unknown stored id resolves to the detected
    /// system language (registry-validated), not passed through raw; a valid
    /// stored id passes through; a nil stored id resolves to system default.
    @Test func staleStoredIdResolvesToSystemLanguageNotPassthrough() {
        #expect(
            KeyboardShowcaseView.resolvedShowcaseLanguageId(forceLanguage: nil, storedId: "xx_XX")
                == LanguageSettings.detectSystemLanguage()
        )
        #expect(
            KeyboardShowcaseView.resolvedShowcaseLanguageId(forceLanguage: nil, storedId: "de_DE")
                == "de_DE"
        )
        #expect(
            KeyboardShowcaseView.resolvedShowcaseLanguageId(forceLanguage: nil, storedId: nil)
                == LanguageSettings.detectSystemLanguage()
        )
    }
}
