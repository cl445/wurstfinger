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
    // Pass descriptors and build inside each test so the argument list doesn't
    // materialize every layout up front (keeps peak test memory aligned with
    // the lazy-loading contract this PR introduces).
    @Test(arguments: LanguageDefinitions.all)
    func layoutValidatesWithoutErrors(descriptor: LanguageDescriptor) {
        let layout = descriptor.makeDefinition()
        let errors = layout.validate()
        #expect(errors.isEmpty, "Validation errors for \(layout.id): \(errors)")
    }

    @Test(arguments: LanguageDefinitions.all)
    func layoutHasRequiredModes(descriptor: LanguageDescriptor) {
        let layout = descriptor.makeDefinition()
        #expect(layout.modes[ModeNames.main] != nil, "\(layout.id) missing main mode")
        #expect(layout.modes[ModeNames.shifted] != nil, "\(layout.id) missing shifted mode")
        #expect(layout.modes[ModeNames.capsLock] != nil, "\(layout.id) missing capsLock mode")
        #expect(layout.modes[ModeNames.numeric] != nil, "\(layout.id) missing numeric mode")
    }

    @Test func allLanguagesAreResolvableViaLanguageConfig() {
        // LanguageConfig.allLanguages is now derived from KeyboardRegistry.available.
        // Verify every definition is resolvable via the lookup helper.
        for definition in LanguageDefinitions.all {
            let config = LanguageConfig.language(withId: definition.id)
            #expect(config != nil, "LanguageConfig.language(withId:) cannot resolve \(definition.id)")
            #expect(
                config?.id == definition.id,
                "ID mismatch for \(definition.id)"
            )
        }
    }
}

// MARK: - German Layout Tests

struct GermanLayoutTests {
    static let german = LanguageDefinitions.german.makeDefinition()

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

    @Test func utilityLeftKeepsGermanLetterOrder() throws {
        // "Utility Keys on Left" must not mirror the letter grid:
        // the letters still read a n i / h d r / t e s left-to-right.
        let main = try #require(Self.german.modes[ModeNames.main])
        let arrangement = try #require(main.arrangements[.portraitUtilityLeft])
        let letterRows = arrangement.rows.map { row in
            row.compactMap { main.keys[$0.keyId]?.bindings[.tap]?.action }
                .compactMap { action -> String? in
                    if case let .commitText(text) = action { return text }
                    return nil
                }
        }
        #expect(letterRows[0] == ["a", "n", "i"])
        #expect(letterRows[1] == ["h", "d", "r"])
        #expect(letterRows[2] == ["t", "e", "s"])
    }
}

// MARK: - NumericLayouts Tests

struct NumericLayoutTests {
    @Test func phoneFirstRowIs123() {
        let phone = NumericLayouts.phone()
        #expect(phone.keys[GridSlot.topLeft]?.bindings[.tap]?.action == .commitText("1"))
        #expect(phone.keys[GridSlot.topCenter]?.bindings[.tap]?.action == .commitText("2"))
        #expect(phone.keys[GridSlot.topRight]?.bindings[.tap]?.action == .commitText("3"))
    }

    @Test func classicFirstRowIs789() {
        let classic = NumericLayouts.classic()
        #expect(classic.keys[GridSlot.topLeft]?.bindings[.tap]?.action == .commitText("7"))
        #expect(classic.keys[GridSlot.topCenter]?.bindings[.tap]?.action == .commitText("8"))
        #expect(classic.keys[GridSlot.topRight]?.bindings[.tap]?.action == .commitText("9"))
    }

    @Test func phoneValidates() {
        // Build a minimal definition to validate the numeric mode
        let errors = NumericLayouts.phone().validate()
        #expect(errors.isEmpty, "Validation errors: \(errors)")
    }

    @Test func classicValidates() {
        let errors = NumericLayouts.classic().validate()
        #expect(errors.isEmpty, "Validation errors: \(errors)")
    }

    @Test func symbolsKeySwitchesToMain() {
        let phone = NumericLayouts.phone()
        #expect(phone.keys[UtilitySlot.symbols]?.bindings[.tap]?.action == .switchMode(ModeNames.main))
    }

    @Test func zeroKeyIsStandaloneDigit() {
        let phone = NumericLayouts.phone()
        #expect(phone.keys[GridSlot.zero]?.bindings[.tap]?.action == .commitText("0"))
    }

    @Test func spaceKeyIsSpace() {
        let phone = NumericLayouts.phone()
        #expect(phone.keys[UtilitySlot.space]?.bindings[.tap]?.action == .space)
    }

    @Test func hasSymbolSwipes() {
        let phone = NumericLayouts.phone()
        // Spot-check symbol swipes inherited from CommonKeys.defaultSlotBindings
        #expect(phone.keys[GridSlot.bottomCenter]?.bindings[.swipeDown]?.action == .commitText("."))
        #expect(phone.keys[GridSlot.bottomCenter]?.bindings[.swipeDownLeft]?.action == .commitText(","))
    }

    @Test func phoneHasAllGridAndUtilityKeys() {
        let phone = NumericLayouts.phone()
        let expectedKeys = Set(
            GridSlot.allSlots.flatMap(\.self) + [
                GridSlot.zero,
                UtilitySlot.globe,
                UtilitySlot.delete,
                UtilitySlot.return,
                UtilitySlot.symbols,
                UtilitySlot.space,
            ]
        )
        #expect(Set(phone.keys.keys) == expectedKeys)
    }

    @Test func defaultBackToAlphaLabelIsLatinAbc() {
        let phone = NumericLayouts.phone()
        #expect(phone.keys[UtilitySlot.symbols]?.bindings[.tap]?.label == "abc")
    }

    @Test func customBackToAlphaLabelIsRespected() {
        let phone = NumericLayouts.phone(backToAlphaLabel: "אבג")
        #expect(phone.keys[UtilitySlot.symbols]?.bindings[.tap]?.label == "אבג")
    }

    @Test func hebrewLayoutUsesHebrewBackToAlphaLabel() throws {
        let hebrew = LanguageDefinitions.hebrew.makeDefinition()
        let numeric = try #require(hebrew.modes[ModeNames.numeric])
        #expect(numeric.keys[UtilitySlot.symbols]?.bindings[.tap]?.label == "אבג")
    }

    @Test func russianLayoutUsesCyrillicBackToAlphaLabel() throws {
        let russian = LanguageDefinitions.russian.makeDefinition()
        let numeric = try #require(russian.modes[ModeNames.numeric])
        #expect(numeric.keys[UtilitySlot.symbols]?.bindings[.tap]?.label == "абв")
    }
}
