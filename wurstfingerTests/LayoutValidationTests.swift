//
//  LayoutValidationTests.swift
//  WurstfingerTests
//
//  Validates all language definitions have correct structure
//  via KeyboardRegistry / KeyboardDefinition.
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct LayoutValidationTests {
    // MARK: - Registry & Loading

    @Test func allLanguagesLoadSuccessfully() {
        for info in KeyboardRegistry.available {
            let definition = KeyboardRegistry.load(id: info.id)
            #expect(definition != nil, "Failed to load \(info.id)")
        }
    }

    @Test func allLanguagesHaveUniqueIds() {
        let ids = KeyboardRegistry.available.map(\.id)
        let uniqueIds = Set(ids)
        #expect(
            ids.count == uniqueIds.count,
            "Duplicate language IDs found"
        )
    }

    // MARK: - Structure Validation

    @Test func allLanguagesHaveMainMode() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load \(info.id)")
                continue
            }
            #expect(
                definition.mode(ModeNames.main) != nil,
                "Language \(info.id) missing main mode"
            )
        }
    }

    @Test func allLanguagesHaveShiftedMode() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load \(info.id)")
                continue
            }
            #expect(
                definition.mode(ModeNames.shifted) != nil,
                "Language \(info.id) missing shifted mode"
            )
        }
    }

    @Test func allLanguagesHaveNumericMode() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load \(info.id)")
                continue
            }
            #expect(
                definition.mode(ModeNames.numeric) != nil,
                "Language \(info.id) missing numeric mode"
            )
        }
    }

    @Test func allLanguagesDefaultToMainMode() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load \(info.id)")
                continue
            }
            #expect(
                definition.defaultMode == ModeNames.main,
                "Language \(info.id) defaultMode is '\(definition.defaultMode)', expected 'main'"
            )
        }
    }

    // MARK: - Grid Structure (9 grid keys present)

    @Test func allLanguagesHaveNineGridKeysInMainMode() {
        let expectedGridSlots = GridSlot.allSlots.flatMap(\.self)

        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id),
                  let mainMode = definition.mode(ModeNames.main)
            else {
                Issue.record("Failed to load main mode for \(info.id)")
                continue
            }

            for slotId in expectedGridSlots {
                #expect(
                    mainMode.key(for: slotId) != nil,
                    "Language \(info.id) main mode missing grid key '\(slotId)'"
                )
            }
        }
    }

    @Test func allLanguagesHaveUtilityKeys() {
        let expectedUtility = [UtilitySlot.space, UtilitySlot.delete, UtilitySlot.return, UtilitySlot.globe, UtilitySlot.symbols]

        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id),
                  let mainMode = definition.mode(ModeNames.main)
            else {
                Issue.record("Failed to load main mode for \(info.id)")
                continue
            }

            for slotId in expectedUtility {
                #expect(
                    mainMode.key(for: slotId) != nil,
                    "Language \(info.id) main mode missing utility key '\(slotId)'"
                )
            }
        }
    }

    // MARK: - Center Characters Non-Empty

    @Test func allGridKeyTapBindingsAreNonEmpty() {
        let gridSlots = GridSlot.allSlots.flatMap(\.self)

        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id),
                  let mainMode = definition.mode(ModeNames.main)
            else { continue }

            for slotId in gridSlots {
                guard let key = mainMode.key(for: slotId) else {
                    Issue.record("Language \(info.id) missing grid key '\(slotId)'")
                    continue
                }

                guard let tapBinding = key.bindings[.tap] else {
                    Issue.record("Language \(info.id) key '\(slotId)' is missing a .tap binding")
                    continue
                }

                #expect(
                    !tapBinding.label.isEmpty,
                    "Language \(info.id) key '\(slotId)' has empty tap label"
                )
            }
        }
    }

    // MARK: - Validation (no structural errors)

    @Test func allLanguageDefinitionsPassValidation() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load \(info.id)")
                continue
            }
            let errors = definition.validate()
            #expect(
                errors.isEmpty,
                "Language \(info.id) has validation errors: \(errors)"
            )
        }
    }

    // MARK: - Language Lookup

    @Test func languageLookupByIdWorks() {
        for language in LanguageConfig.allLanguages {
            let found = LanguageConfig.language(withId: language.id)
            #expect(found != nil, "Language \(language.name) not found by id '\(language.id)'")
            #expect(found?.name == language.name)
        }
    }

    @Test func unknownLanguageIdReturnsNil() {
        #expect(LanguageConfig.language(withId: "xx_XX") == nil)
    }

    @Test func registryLoadUnknownIdReturnsNil() {
        #expect(KeyboardRegistry.load(id: "nonexistent_XX") == nil)
    }
}
