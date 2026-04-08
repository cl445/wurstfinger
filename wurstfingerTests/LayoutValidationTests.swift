//
//  LayoutValidationTests.swift
//  WurstfingerTests
//
//  Validates all language layouts have correct structure.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct LayoutValidationTests {
    // MARK: - Structure Validation

    @Test func allLanguagesHaveThreeRowsOfThreeKeys() {
        for language in LanguageConfig.allLanguages {
            #expect(
                language.centerCharacters.count == 3,
                "Language \(language.name) should have 3 rows, has \(language.centerCharacters.count)"
            )
            for (rowIndex, row) in language.centerCharacters.enumerated() {
                #expect(
                    row.count == 3,
                    "Language \(language.name) row \(rowIndex) should have 3 keys, has \(row.count)"
                )
            }
        }
    }

    @Test func allLanguagesHaveNonEmptyCenterCharacters() {
        for language in LanguageConfig.allLanguages {
            for (rowIndex, row) in language.centerCharacters.enumerated() {
                for (colIndex, char) in row.enumerated() {
                    #expect(
                        !char.isEmpty,
                        "Language \(language.name) center[\(rowIndex)][\(colIndex)] is empty"
                    )
                }
            }
        }
    }

    // MARK: - Directional Character Validation

    @Test func directionalCharacterPositionsAreValid() {
        for language in LanguageConfig.allLanguages {
            for (slot, value) in language.directionalCharacters {
                #expect(
                    slot.row >= 0 && slot.row <= 2,
                    "Language \(language.name): slot has invalid row \(slot.row)"
                )
                #expect(
                    slot.col >= 0 && slot.col <= 2,
                    "Language \(language.name): slot has invalid column \(slot.col)"
                )
                #expect(
                    slot.direction != .center,
                    "Language \(language.name): directional characters should not use .center direction"
                )
                #expect(
                    !value.isEmpty,
                    "Language \(language.name): slot (\(slot.row),\(slot.col),\(slot.direction)) has empty value"
                )
            }
        }
    }

    // MARK: - Layout Generation

    @Test func allLanguagesGenerateValidLayouts() {
        for language in LanguageConfig.allLanguages {
            let layout = KeyboardLayout.layout(for: language, numpadStyle: .phone)
            let rows = layout.rows(for: .lower)

            #expect(
                rows.count == 3,
                "Language \(language.name) layout should generate 3 rows, got \(rows.count)"
            )
            for (rowIndex, row) in rows.enumerated() {
                #expect(
                    row.count == 3,
                    "Language \(language.name) layout row \(rowIndex) should have 3 keys, got \(row.count)"
                )
            }
        }
    }

    @Test func centerCharactersMatchConfig() {
        for language in LanguageConfig.allLanguages {
            let layout = KeyboardLayout.layout(for: language, numpadStyle: .phone)
            let rows = layout.rows(for: .lower)

            for (rowIndex, row) in rows.enumerated() {
                for (colIndex, key) in row.enumerated() {
                    let expected = language.centerCharacters[rowIndex][colIndex]
                    #expect(
                        key.center == expected,
                        "Language \(language.name): center[\(rowIndex)][\(colIndex)] expected '\(expected)', got '\(key.center)'"
                    )
                }
            }
        }
    }

    // MARK: - Guard: No Language Character Is Silently Overridden

    @Test func allDirectionalCharactersAppearInGeneratedLayout() {
        for config in LanguageConfig.allLanguages {
            let layout = KeyboardLayout.layout(for: config)
            let rows = layout.rows(for: .lower)

            for (slot, expectedChar) in config.directionalCharacters {
                let key = rows[slot.row][slot.col]
                let output = key.output(for: slot.direction)

                switch output {
                case let .text(text):
                    #expect(
                        text == expectedChar,
                        "[\(config.id)] (\(slot.row),\(slot.col),\(slot.direction)): expected '\(expectedChar)', got '\(text)'"
                    )
                default:
                    Issue.record(
                        "[\(config.id)] (\(slot.row),\(slot.col),\(slot.direction)): expected .text(\"\(expectedChar)\"), got \(String(describing: output))"
                    )
                }
            }
        }
    }

    // MARK: - Language ID Lookup

    @Test func allLanguagesHaveUniqueIds() {
        let ids = LanguageConfig.allLanguages.map(\.id)
        let uniqueIds = Set(ids)
        #expect(
            ids.count == uniqueIds.count,
            "Duplicate language IDs found"
        )
    }

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
}
