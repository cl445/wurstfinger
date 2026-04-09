//
//  MessagEaseSlot.swift
//  Wurstfinger
//
//  Semantic slot names for MessagEase 3x3 layouts.
//

import Foundation

/// Slot names for MessagEase 3x3 layouts.
/// Stable across all languages — DE and FR both have a "topLeft" slot,
/// but with different characters.
enum MessagEaseSlot {
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
