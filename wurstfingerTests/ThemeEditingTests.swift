//
//  ThemeEditingTests.swift
//  WurstfingerTests
//
//  The editing rules the style screen and the theme editor are built on:
//  built-ins are immutable templates, glass is a reversible per-surface
//  switch, and a duplicate only becomes real when it is saved.
//

import SwiftUI
import Testing
@testable import WurstfingerApp

// MARK: - Row affordances

struct ThemeRowActionTests {
    @Test func builtInOffersNeitherEditNorDelete() {
        for theme in BuiltInThemes.all {
            let actions = StyleSettingsView.rowActions(for: theme)
            #expect(actions == [.select, .duplicate])
            #expect(!actions.contains(.edit))
            #expect(!actions.contains(.delete))
        }
    }

    @Test func userThemeOffersEveryAction() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        #expect(StyleSettingsView.rowActions(for: theme) == [.select, .duplicate, .edit, .delete])
    }
}

// MARK: - Glass switches

/// The editor's two glass toggles write nothing but the surface style, which
/// is what makes them losslessly reversible and lets the editor work without a
/// shadow copy of the palette.
struct ThemeGlassToggleTests {
    /// Mirrors the editor's binding setter, so the test exercises the same
    /// write the toggle performs.
    private func setGlassKeys(_ isOn: Bool, on theme: inout KeyboardThemeDefinition) {
        theme.keySurface = isOn ? .glass : .color
    }

    private func setGlassBoard(_ isOn: Bool, on theme: inout KeyboardThemeDefinition) {
        theme.boardSurface = isOn ? .glass : .color
    }

    @Test func togglingGlassKeysKeepsTheKeyColors() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        let original = theme

        setGlassKeys(true, on: &theme)
        #expect(theme.keySurface == .glass)
        #expect(theme.keyColor == original.keyColor)
        #expect(theme.keyColorActive == original.keyColorActive)
        #expect(theme.boardColor == original.boardColor)

        setGlassKeys(false, on: &theme)
        #expect(theme == original)
    }

    @Test func togglingGlassBackgroundKeepsTheBoardColor() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        let original = theme

        setGlassBoard(true, on: &theme)
        #expect(theme.boardSurface == .glass)
        #expect(theme.boardColor == original.boardColor)
        #expect(theme.keyColor == original.keyColor)
        #expect(theme.keyColorActive == original.keyColorActive)

        setGlassBoard(false, on: &theme)
        #expect(theme == original)
    }

    /// A copy of the glass built-in has to survive the same round trip, since
    /// its colors are the fallbacks the toggle restores.
    @Test func glassBuiltInCopyRestoresItsColorsWhenGlassIsSwitchedOff() {
        var theme = BuiltInThemes.liquidGlass
        theme.id = UUID().uuidString
        let original = theme

        setGlassKeys(false, on: &theme)
        setGlassBoard(false, on: &theme)
        #expect(theme.keyColor == original.keyColor)
        #expect(theme.boardColor == original.boardColor)
        #expect(!theme.resolved().hasGlassKeys)

        setGlassKeys(true, on: &theme)
        setGlassBoard(true, on: &theme)
        #expect(theme == original)
    }
}

// MARK: - Duplicate → edit → save

struct ThemeEditingFlowTests {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "theme-editing-flow-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Cancelling the editor must leave no orphaned "… Copy": duplicating only
    /// builds the copy in memory, and nothing writes it until Save.
    @Test func cancelledNewThemeIsNotPersisted() throws {
        let defaults = try isolatedDefaults()
        let copy = ThemeStore.duplicate(BuiltInThemes.darkGold, existing: ThemeStore.userThemes(defaults: defaults))

        #expect(ThemeStore.userThemes(defaults: defaults).isEmpty)
        #expect(ThemeStore.theme(id: copy.id, defaults: defaults) == nil)
    }

    @Test func savedNewThemeIsPersisted() throws {
        let defaults = try isolatedDefaults()
        let copy = ThemeStore.duplicate(BuiltInThemes.darkGold, existing: ThemeStore.userThemes(defaults: defaults))

        ThemeStore.saveUserTheme(copy, defaults: defaults)

        #expect(ThemeStore.userThemes(defaults: defaults).map(\.id) == [copy.id])
    }

    @Test func savingANewThemeSelectsIt() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-new",
            isNewTheme: true,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.classic.id,
            separateDarkSlot: false,
            editingAppearance: .light
        )
        #expect(slots.light == "user-new")
        #expect(slots.dark == "user-new")
    }

    @Test func savingAnEditLeavesTheSelectionAlone() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-edited",
            isNewTheme: false,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            separateDarkSlot: true,
            editingAppearance: .light
        )
        #expect(slots.light == BuiltInThemes.classic.id)
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }

    /// A new theme lands in the slot the gallery is editing, not in both, once
    /// the two slots are allowed to diverge.
    @Test func savingANewThemeWhileEditingDarkTouchesOnlyTheDarkSlot() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-new",
            isNewTheme: true,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            separateDarkSlot: true,
            editingAppearance: .dark
        )
        #expect(slots.light == BuiltInThemes.classic.id)
        #expect(slots.dark == "user-new")
    }

    @Test func selectingWritesBothSlotsWhileTheyShareOneSelection() {
        let slots = StyleSettingsView.slots(
            selecting: BuiltInThemes.darkGold.id,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.classic.id,
            separateDarkSlot: false,
            editingAppearance: .light
        )
        #expect(slots.light == BuiltInThemes.darkGold.id)
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }
}
