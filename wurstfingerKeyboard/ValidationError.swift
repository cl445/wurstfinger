//
//  ValidationError.swift
//  Wurstfinger
//
//  Validation for data-driven keyboard definitions.
//

import Foundation

/// Validation errors for keyboard definitions.
enum ValidationError: Error, Equatable, CustomStringConvertible {
    case missingKey(keyId: String, context: ArrangementContext)
    case missingMode(String)
    case columnMismatch(row: Int, context: ArrangementContext, expected: Int, got: Int)
    case emptyKeyPool
    case noPortraitArrangement
    case duplicateKeyId(String)
    case modeNameMismatch(key: String, modeName: String)

    var description: String {
        switch self {
        case let .missingKey(keyId, context):
            "Key '\(keyId)' referenced in arrangement '\(context)' but not found in key pool"
        case let .missingMode(name):
            "Mode '\(name)' referenced but not found in definition"
        case let .columnMismatch(row, context, expected, got):
            "Row \(row) in '\(context)' has \(got) columns (expected \(expected))"
        case .emptyKeyPool:
            "Key pool is empty"
        case .noPortraitArrangement:
            "No portrait arrangement defined"
        case let .duplicateKeyId(id):
            "Duplicate key ID '\(id)' in arrangement"
        case let .modeNameMismatch(key, modeName):
            "Mode dictionary key '\(key)' does not match mode name '\(modeName)'"
        }
    }
}

// MARK: - KeyboardMode Validation

extension KeyboardMode {
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        if keys.isEmpty {
            errors.append(.emptyKeyPool)
        }

        if arrangements[.portrait] == nil {
            errors.append(.noPortraitArrangement)
        }

        for (context, arrangement) in arrangements {
            // All keyIds must exist in the key pool
            for row in arrangement.rows {
                for placement in row where keys[placement.keyId] == nil {
                    errors.append(.missingKey(keyId: placement.keyId, context: context))
                }
            }

            // Detect duplicate keyIds within an arrangement
            let allIds = arrangement.rows.flatMap { $0.map(\.keyId) }
            var seen = Set<String>()
            for id in allIds where !seen.insert(id).inserted {
                errors.append(.duplicateKeyId(id))
            }

            // Column validation: widthMultiplier sum + columns spanned from above == columns.
            // Keys with heightMultiplier > 1 occupy their columns in subsequent rows.
            var spannedColumns: [Int: Int] = [:]
            for (i, row) in arrangement.rows.enumerated() {
                let spanning = spannedColumns[i, default: 0]
                let sum = row.reduce(0) { $0 + $1.widthMultiplier } + spanning
                if sum != arrangement.columns {
                    errors.append(.columnMismatch(
                        row: i, context: context,
                        expected: arrangement.columns, got: sum
                    ))
                }
                // Register keys that span into subsequent rows
                for placement in row where placement.heightMultiplier > 1 {
                    for extraRow in 1 ..< placement.heightMultiplier {
                        spannedColumns[i + extraRow, default: 0] += placement.widthMultiplier
                    }
                }
            }
        }

        return errors
    }
}

// MARK: - KeyboardDefinition Validation

extension KeyboardDefinition {
    /// Validates all modes and the overall structure.
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // defaultMode must exist
        if modes[defaultMode] == nil {
            errors.append(.missingMode(defaultMode))
        }

        // Mode dictionary keys must match mode names
        for (key, mode) in modes where key != mode.name {
            errors.append(.modeNameMismatch(key: key, modeName: mode.name))
        }

        // All switchMode targets must exist
        for (_, mode) in modes {
            for (_, key) in mode.keys {
                for (_, binding) in key.bindings {
                    if case let .switchMode(target) = binding.action,
                       modes[target] == nil {
                        errors.append(.missingMode(target))
                    }
                }
            }

            // All autoTransition targets must exist
            for (_, targetMode) in mode.autoTransitions where modes[targetMode] == nil {
                errors.append(.missingMode(targetMode))
            }

            // All doubleTapMode targets must exist
            if let doubleTap = mode.doubleTapMode, modes[doubleTap] == nil {
                errors.append(.missingMode(doubleTap))
            }
        }

        // Validate each mode individually
        for (_, mode) in modes {
            errors += mode.validate()
        }

        return errors
    }
}
