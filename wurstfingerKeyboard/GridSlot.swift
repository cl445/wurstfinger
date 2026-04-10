//
//  GridSlot.swift
//  Wurstfinger
//
//  Semantic slot names for 3x3 grid layouts.
//

import Foundation

/// Semantic slot names for a 3x3 key grid.
/// Stable across all languages and layout families.
enum GridSlot {
    static let topLeft = "topLeft"
    static let topCenter = "topCenter"
    static let topRight = "topRight"
    static let midLeft = "midLeft"
    static let center = "center"
    static let midRight = "midRight"
    static let bottomLeft = "bottomLeft"
    static let bottomCenter = "bottomCenter"
    static let bottomRight = "bottomRight"

    /// Ordered list of all slots (for mapping from centerCharacters arrays)
    static let allSlots: [[String]] = [
        [topLeft, topCenter, topRight],
        [midLeft, center, midRight],
        [bottomLeft, bottomCenter, bottomRight],
    ]
}
