//
//  KeyboardStateHygieneTests.swift
//  WurstfingerTests
//
//  Regression tests for keyboard state hygiene:
//  - the loaded-definition signature stays in sync after in-keyboard
//    language switches (no needless pipeline rebuild on reappearance),
//  - the keyboard reopens on the default (letters) layer,
//  - a no-op settings reload publishes no view updates.
//

import Combine
import Foundation
import Testing
@testable import WurstfingerApp

/// A view model whose shared defaults already list `enabled` languages with
/// `selected` active — the view model reads the enabled list at init, so the
/// seeding must happen before construction.
private func makeMultiLanguageViewModel(
    enabled: [String],
    selected: String
) -> KeyboardViewModel {
    let defaults = InMemoryUserDefaults()
    LanguageSettings.saveEnabledLanguageIds(enabled, to: defaults)
    defaults.set(selected, forKey: SettingsKey.selectedLanguageId.rawValue)
    let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
    vm.loadDefinition(for: selected)
    return vm
}

// MARK: - Definition signature

@Suite(.serialized)
struct DefinitionSignatureTests {
    @Test func signatureCombinesLanguageAndNumpadStyle() {
        #expect(
            KeyboardViewModel.definitionSignature(languageId: "de_DE", numpadStyle: "classic")
                == "de_DE|classic"
        )
        #expect(
            KeyboardViewModel.definitionSignature(languageId: "en_US", numpadStyle: nil)
                == "en_US|"
        )
    }

    @Test func signatureDiffersWhenAnyInputDiffers() {
        let base = KeyboardViewModel.definitionSignature(languageId: "de_DE", numpadStyle: nil)
        #expect(base != KeyboardViewModel.definitionSignature(languageId: "en_US", numpadStyle: nil))
        #expect(base != KeyboardViewModel.definitionSignature(languageId: "de_DE", numpadStyle: "classic"))
    }

    @Test func loadDefinitionRecordsSignature() {
        let (vm, _) = makeViewModel(languageId: "de_DE")
        #expect(
            vm.loadedDefinitionSignature
                == KeyboardViewModel.definitionSignature(languageId: "de_DE", numpadStyle: nil)
        )
    }

    @Test func loadDefinitionRecordsNumpadStyleInSignature() {
        let defaults = InMemoryUserDefaults()
        defaults.set(NumpadStyle.classic.rawValue, forKey: SettingsKey.numpadStyle.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        vm.loadDefinition(for: "de_DE")
        #expect(
            vm.loadedDefinitionSignature
                == KeyboardViewModel.definitionSignature(
                    languageId: "de_DE",
                    numpadStyle: NumpadStyle.classic.rawValue
                )
        )
    }

    @Test("Globe-key language switch keeps the signature in sync with the loaded definition")
    func inKeyboardLanguageSwitchKeepsSignatureInSync() {
        let vm = makeMultiLanguageViewModel(enabled: ["de_DE", "en_US"], selected: "de_DE")

        vm.switchToNextLanguage()

        #expect(vm.currentDefinition?.id == "en_US")
        // The signature must describe the definition that is actually loaded —
        // a stale "de_DE|" here forced a full pipeline rebuild on the next
        // viewWillAppear.
        #expect(
            vm.loadedDefinitionSignature
                == KeyboardViewModel.definitionSignature(languageId: "en_US", numpadStyle: nil)
        )
    }

    @Test func fallbackLoadRecordsTheActuallyLoadedLanguage() {
        let defaults = InMemoryUserDefaults()
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        vm.loadDefinition(for: "nonexistent_XX")
        // The signature reflects the English fallback, not the requested id,
        // so a later load of a valid selection is never suppressed.
        #expect(
            vm.loadedDefinitionSignature
                == KeyboardViewModel.definitionSignature(
                    languageId: LanguageConfig.english.id,
                    numpadStyle: nil
                )
        )
    }
}

// MARK: - Mode reset on appearance

@Suite(.serialized)
struct ModeResetTests {
    @Test("Reopening resets the numeric layer back to letters")
    func resetToDefaultModeLeavesNumericLayer() {
        let (vm, _) = makeViewModel()
        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)

        vm.resetToDefaultMode()

        #expect(vm.activeModeName == ModeNames.main)
        #expect(vm.currentMode?.name == ModeNames.main)
    }

    @Test func resetToDefaultModeIsPublishFreeWhenAlreadyDefault() {
        let (vm, _) = makeViewModel()
        #expect(vm.activeModeName == ModeNames.main)

        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }
        defer { cancellable.cancel() }

        vm.resetToDefaultMode()

        #expect(emissions == 0, "Resetting to an already-active mode must not re-render")
    }

    @Test func resetToDefaultModeWithoutDefinitionIsSafe() {
        let vm = KeyboardViewModel(
            userDefaults: InMemoryUserDefaults(),
            shouldPersistSettings: false
        )
        vm.resetToDefaultMode() // must not crash
        #expect(vm.currentDefinition == nil)
    }
}

// MARK: - Equality-guarded settings reload

@Suite(.serialized)
struct ReloadSettingsHygieneTests {
    @Test("A reload with unchanged defaults publishes no view updates")
    func noOpReloadDoesNotPublish() {
        let vm = makeMultiLanguageViewModel(enabled: ["de_DE", "en_US"], selected: "de_DE")

        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }
        defer { cancellable.cancel() }

        vm.reloadSettings()

        #expect(emissions == 0, "No-op reload must not trigger a full keyboard re-render")
    }

    @Test func reloadStillPublishesRealChanges() {
        let vm = makeMultiLanguageViewModel(enabled: ["de_DE", "en_US"], selected: "de_DE")
        #expect(vm.hasMultipleLanguages)

        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }
        defer { cancellable.cancel() }

        LanguageSettings.saveEnabledLanguageIds(["de_DE"], to: vm.sharedDefaults)
        vm.reloadSettings()

        #expect(emissions > 0)
        #expect(!vm.hasMultipleLanguages)
    }
}
