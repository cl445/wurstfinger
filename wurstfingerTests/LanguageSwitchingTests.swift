//
//  LanguageSwitchingTests.swift
//  wurstfingerTests
//
//  Integration tests for in-keyboard language switching: pressing the language
//  key (globe, swipe-right → `.switchToNextLanguage`) must cycle the active
//  definition through the enabled languages, honour the count > 1 guard, and
//  emit no text. The `LanguageSettings` model itself — detection, enabled list,
//  pinning, the pure cycling logic — is covered by `LanguageSettingsTests`.
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct LanguageSwitchingTests {
    /// A view model whose shared defaults already list `enabled` languages with
    /// `selected` active — the view model loads the enabled list at init, so the
    /// seeding must happen before construction.
    private func makeViewModel(enabled: [String], selected: String) -> (KeyboardViewModel, MockTextTarget) {
        let defaults = InMemoryUserDefaults()
        LanguageSettings.saveEnabledLanguageIds(enabled, to: defaults)
        defaults.set(selected, forKey: SettingsKey.selectedLanguageId.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        let target = MockTextTarget()
        vm.bindTextInputTarget(target)
        vm.loadDefinition(for: selected)
        return (vm, target)
    }

    @Test("Language key cycles the active definition to the next enabled language")
    func switchKeyCyclesToNextLanguage() {
        let (vm, target) = makeViewModel(enabled: ["de_DE", "en_US"], selected: "de_DE")
        #expect(vm.currentDefinition?.id == "de_DE")

        vm.handleGesture(.swipeRight, keyId: UtilitySlot.globe, isReturn: false)

        // The active definition advanced to the next enabled language…
        #expect(vm.currentDefinition?.id == "en_US")
        // …and the selection was persisted so the next launch resumes there.
        #expect(vm.sharedDefaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) == "en_US")
        // Switching languages must never type anything.
        #expect(target.events.isEmpty)
    }

    @Test("Language key wraps from the last enabled language back to the first")
    func switchKeyWrapsAround() {
        let (vm, _) = makeViewModel(enabled: ["de_DE", "en_US"], selected: "en_US")

        vm.handleGesture(.swipeRight, keyId: UtilitySlot.globe, isReturn: false)

        #expect(vm.currentDefinition?.id == "de_DE")
    }

    @Test("Language key is inert when only one language is enabled")
    func switchKeyNoOpWithSingleLanguage() {
        let (vm, target) = makeViewModel(enabled: ["de_DE"], selected: "de_DE")

        vm.handleGesture(.swipeRight, keyId: UtilitySlot.globe, isReturn: false)

        #expect(vm.currentDefinition?.id == "de_DE")
        #expect(target.events.isEmpty)
    }
}
