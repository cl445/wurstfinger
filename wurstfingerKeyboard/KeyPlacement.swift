//
//  KeyPlacement.swift
//  Wurstfinger
//
//  References a key by ID and determines its size in the grid.
//

import Foundation

/// References a key by ID and determines its size in the grid.
/// The same key can be placed differently in different arrangements.
struct KeyPlacement: Codable, Equatable {
    /// Reference to a KeyConfig.id
    let keyId: String

    /// Width as multiple of standard column width (1 = normal, 2 = double, 3 = triple)
    let widthMultiplier: Int

    /// Height as multiple of standard row height (1 = normal, 2 = double)
    /// Enables e.g. a tall return key spanning 2 rows.
    let heightMultiplier: Int

    init(keyId: String, widthMultiplier: Int = 1, heightMultiplier: Int = 1) {
        precondition(widthMultiplier > 0, "widthMultiplier must be positive")
        precondition(heightMultiplier > 0, "heightMultiplier must be positive")
        self.keyId = keyId
        self.widthMultiplier = widthMultiplier
        self.heightMultiplier = heightMultiplier
    }
}
