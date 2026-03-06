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

    // MARK: - Special Character Position Validation

    @Test func specialCharacterKeysReferenceValidPositions() {
        let validDirections = [
            "up", "down", "left", "right",
            "upLeft", "upRight", "downLeft", "downRight",
            "center"
        ]

        for language in LanguageConfig.allLanguages {
            for (key, value) in language.specialCharacters {
                let parts = key.split(separator: "_")
                #expect(
                    parts.count == 3,
                    "Language \(language.name): key '\(key)' should have format 'row_col_direction'"
                )

                if parts.count == 3 {
                    let row = Int(parts[0])
                    let col = Int(parts[1])
                    let direction = String(parts[2])

                    #expect(
                        row != nil && row! >= 0 && row! <= 2,
                        "Language \(language.name): key '\(key)' has invalid row"
                    )
                    #expect(
                        col != nil && col! >= 0 && col! <= 2,
                        "Language \(language.name): key '\(key)' has invalid column"
                    )
                    #expect(
                        validDirections.contains(direction),
                        "Language \(language.name): key '\(key)' has invalid direction '\(direction)'"
                    )
                    #expect(
                        !value.isEmpty,
                        "Language \(language.name): key '\(key)' has empty value"
                    )
                }
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
