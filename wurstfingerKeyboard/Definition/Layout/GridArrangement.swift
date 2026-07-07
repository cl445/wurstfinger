//
//  GridArrangement.swift
//  Wurstfinger
//
//  A concrete spatial arrangement of keys in a grid.
//

import Foundation

/// A concrete spatial arrangement of keys.
/// Multiple arrangements can lay out the same key pool differently.
struct GridArrangement: Codable, Equatable {
    /// Number of logical columns.
    /// The sum of widthMultipliers in each row (plus columns spanned by keys from
    /// previous rows via heightMultiplier) must equal this value.
    let columns: Int

    /// The placements, organized by row.
    let rows: [[KeyPlacement]]
}

// MARK: - Transformations

extension GridArrangement {
    /// Moves the placements with the given key IDs to the leading edge of their
    /// row while preserving the relative order of all other placements
    /// (utility column left ↔ right without mirroring the letter grid).
    func movingToLeading(keyIds: Set<String>) -> GridArrangement {
        GridArrangement(
            columns: columns,
            rows: rows.map { row in
                row.filter { keyIds.contains($0.keyId) } + row.filter { !keyIds.contains($0.keyId) }
            }
        )
    }

    /// Changes the column count and adjusts a specific key's width.
    func resized(columns newColumns: Int, adjusting keyId: String, toWidth newWidth: Int) -> GridArrangement {
        precondition(newColumns > 0, "newColumns must be positive")
        precondition(newWidth > 0, "newWidth must be positive")
        return GridArrangement(
            columns: newColumns,
            rows: rows.map { row in
                row.map { placement in
                    placement.keyId == keyId
                        ? KeyPlacement(keyId: keyId, widthMultiplier: newWidth, heightMultiplier: placement.heightMultiplier)
                        : placement
                }
            }
        )
    }

    /// Removes a key from all rows (e.g. for more compact layouts).
    func removing(keyId: String) -> GridArrangement {
        GridArrangement(
            columns: columns,
            rows: rows.map { $0.filter { $0.keyId != keyId } }
        )
    }
}
