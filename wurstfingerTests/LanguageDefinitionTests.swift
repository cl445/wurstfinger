//
//  LanguageDefinitionTests.swift
//  WurstfingerTests
//
//  Tests for LanguageDefinitions and NumericLayouts.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - All Layouts Validate

struct LanguageDefinitionValidationTests {
    @Test(arguments: LanguageDefinitions.all)
    func layoutValidatesWithoutErrors(layout: KeyboardDefinition) {
        let errors = layout.validate()
        #expect(errors.isEmpty, "Validation errors for \(layout.id): \(errors)")
    }

    @Test(arguments: LanguageDefinitions.all)
    func layoutHasRequiredModes(layout: KeyboardDefinition) {
        #expect(layout.modes[ModeNames.main] != nil, "\(layout.id) missing main mode")
        #expect(layout.modes[ModeNames.shifted] != nil, "\(layout.id) missing shifted mode")
        #expect(layout.modes[ModeNames.numeric] != nil, "\(layout.id) missing numeric mode")
    }

    @Test func allLanguagesCount() {
        #expect(LanguageDefinitions.all.count == 14)
    }
}

// MARK: - German Layout Tests

struct GermanLayoutTests {
    static let german = LanguageDefinitions.german

    @Test func centerCharacters() throws {
        let main = try #require(Self.german.modes[ModeNames.main])
        #expect(main.keys[GridSlot.topLeft]?.bindings[.tap]?.action == .commitText("a"))
        #expect(main.keys[GridSlot.topCenter]?.bindings[.tap]?.action == .commitText("n"))
        #expect(main.keys[GridSlot.topRight]?.bindings[.tap]?.action == .commitText("i"))
        #expect(main.keys[GridSlot.midLeft]?.bindings[.tap]?.action == .commitText("h"))
        #expect(main.keys[GridSlot.center]?.bindings[.tap]?.action == .commitText("d"))
        #expect(main.keys[GridSlot.midRight]?.bindings[.tap]?.action == .commitText("r"))
        #expect(main.keys[GridSlot.bottomLeft]?.bindings[.tap]?.action == .commitText("t"))
        #expect(main.keys[GridSlot.bottomCenter]?.bindings[.tap]?.action == .commitText("e"))
        #expect(main.keys[GridSlot.bottomRight]?.bindings[.tap]?.action == .commitText("s"))
    }

    @Test func umlauts() throws {
        let main = try #require(Self.german.modes[ModeNames.main])
        #expect(main.keys[GridSlot.topLeft]?.bindings[.swipeDown]?.action == .commitText("ä"))
        #expect(main.keys[GridSlot.midLeft]?.bindings[.swipeUp]?.action == .commitText("ü"))
        #expect(main.keys[GridSlot.midLeft]?.bindings[.swipeDown]?.action == .commitText("ö"))
    }

    @Test func eszett() throws {
        let main = try #require(Self.german.modes[ModeNames.main])
        #expect(main.keys[GridSlot.bottomLeft]?.bindings[.swipeDown]?.action == .commitText("ß"))
    }

    @Test func shiftedUmlauts() throws {
        let shifted = try #require(Self.german.modes[ModeNames.shifted])
        #expect(shifted.keys[GridSlot.topLeft]?.bindings[.swipeDown]?.action == .commitText("Ä"))
        #expect(shifted.keys[GridSlot.midLeft]?.bindings[.swipeUp]?.action == .commitText("Ü"))
        #expect(shifted.keys[GridSlot.midLeft]?.bindings[.swipeDown]?.action == .commitText("Ö"))
    }

    @Test func localeIsGerman() {
        #expect(Self.german.localeIdentifier == "de_DE")
    }
}

// MARK: - NumericLayouts Tests

struct NumericLayoutTests {
    @Test func phoneFirstRowIs123() {
        let phone = NumericLayouts.phone
        #expect(phone.keys[GridSlot.topLeft]?.bindings[.tap]?.action == .commitText("1"))
        #expect(phone.keys[GridSlot.topCenter]?.bindings[.tap]?.action == .commitText("2"))
        #expect(phone.keys[GridSlot.topRight]?.bindings[.tap]?.action == .commitText("3"))
    }

    @Test func classicFirstRowIs789() {
        let classic = NumericLayouts.classic
        #expect(classic.keys[GridSlot.topLeft]?.bindings[.tap]?.action == .commitText("7"))
        #expect(classic.keys[GridSlot.topCenter]?.bindings[.tap]?.action == .commitText("8"))
        #expect(classic.keys[GridSlot.topRight]?.bindings[.tap]?.action == .commitText("9"))
    }

    @Test func phoneValidates() {
        // Build a minimal definition to validate the numeric mode
        let errors = NumericLayouts.phone.validate()
        #expect(errors.isEmpty, "Validation errors: \(errors)")
    }

    @Test func classicValidates() {
        let errors = NumericLayouts.classic.validate()
        #expect(errors.isEmpty, "Validation errors: \(errors)")
    }

    @Test func symbolsKeySwitchesToMain() {
        let phone = NumericLayouts.phone
        #expect(phone.keys[UtilitySlot.symbols]?.bindings[.tap]?.action == .switchMode(ModeNames.main))
    }

    @Test func spaceKeyOutputsZero() {
        let phone = NumericLayouts.phone
        #expect(phone.keys[UtilitySlot.space]?.bindings[.tap]?.action == .commitText("0"))
    }

    @Test func hasSymbolSwipes() {
        let phone = NumericLayouts.phone
        // Spot-check a few symbol swipes
        #expect(phone.keys[GridSlot.bottomCenter]?.bindings[.swipeDown]?.action == .commitText("."))
        #expect(phone.keys[GridSlot.bottomCenter]?.bindings[.swipeLeft]?.action == .commitText(","))
    }

    @Test func phoneHasAllGridAndUtilityKeys() {
        let phone = NumericLayouts.phone
        // 9 grid slots + 5 utility keys = 14
        #expect(phone.keys.count == 14)
    }
}
