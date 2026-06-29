//
//  KeyPlacement.swift
//  Wurstfinger
//
//  References a key by ID and determines its size in the grid.
//

import Foundation

/// References a key by ID and determines its size in the grid.
/// The same key can be placed differently in different arrangements.
struct KeyPlacement: Codable, Equatable, Hashable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyId = try container.decode(String.self, forKey: .keyId)
        let width = try container.decode(Int.self, forKey: .widthMultiplier)
        let height = try container.decode(Int.self, forKey: .heightMultiplier)

        guard width > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .widthMultiplier, in: container,
                debugDescription: "widthMultiplier must be positive"
            )
        }
        guard height > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .heightMultiplier, in: container,
                debugDescription: "heightMultiplier must be positive"
            )
        }

        self.init(keyId: keyId, widthMultiplier: width, heightMultiplier: height)
    }
}
