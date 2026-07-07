//
//  StandardArrangements.swift
//  Wurstfinger
//
//  Standard grid arrangements for 3x3 swipe keyboard layouts.
//

import Foundation

/// Standard grid arrangements for 3x3 swipe keyboard layouts.
/// Shared across all languages using the same 3x3 grid structure.
enum StandardArrangements {
    // MARK: - Portrait

    private static let portrait = GridArrangement(
        columns: 4,
        rows: [
            [.init(keyId: GridSlot.topLeft), .init(keyId: GridSlot.topCenter), .init(keyId: GridSlot.topRight), .init(keyId: UtilitySlot.globe)],
            [.init(keyId: GridSlot.midLeft), .init(keyId: GridSlot.center), .init(keyId: GridSlot.midRight), .init(keyId: UtilitySlot.symbols)],
            [
                .init(keyId: GridSlot.bottomLeft),
                .init(keyId: GridSlot.bottomCenter),
                .init(keyId: GridSlot.bottomRight),
                .init(keyId: UtilitySlot.delete)
            ],
            [.init(keyId: UtilitySlot.space, widthMultiplier: 3), .init(keyId: UtilitySlot.return)],
        ]
    )

    // MARK: - Landscape

    private static let landscape = GridArrangement(
        columns: 5,
        rows: [
            [
                .init(keyId: UtilitySlot.globe),
                .init(keyId: GridSlot.topLeft),
                .init(keyId: GridSlot.topCenter),
                .init(keyId: GridSlot.topRight),
                .init(keyId: UtilitySlot.delete)
            ],
            [
                .init(keyId: UtilitySlot.symbols),
                .init(keyId: GridSlot.midLeft),
                .init(keyId: GridSlot.center),
                .init(keyId: GridSlot.midRight),
                .init(keyId: UtilitySlot.return, heightMultiplier: 2)
            ],
            [
                .init(keyId: UtilitySlot.space),
                .init(keyId: GridSlot.bottomLeft),
                .init(keyId: GridSlot.bottomCenter),
                .init(keyId: GridSlot.bottomRight)
            ],
        ]
    )

    // MARK: - Numeric Portrait

    /// Numeric mode portrait: bottom row has [0 (1 col)] [space (2 cols)] [return (1 col)].
    private static let numericPortrait = GridArrangement(
        columns: 4,
        rows: [
            [.init(keyId: GridSlot.topLeft), .init(keyId: GridSlot.topCenter), .init(keyId: GridSlot.topRight), .init(keyId: UtilitySlot.globe)],
            [.init(keyId: GridSlot.midLeft), .init(keyId: GridSlot.center), .init(keyId: GridSlot.midRight), .init(keyId: UtilitySlot.symbols)],
            [
                .init(keyId: GridSlot.bottomLeft),
                .init(keyId: GridSlot.bottomCenter),
                .init(keyId: GridSlot.bottomRight),
                .init(keyId: UtilitySlot.delete),
            ],
            [.init(keyId: GridSlot.zero), .init(keyId: UtilitySlot.space, widthMultiplier: 2), .init(keyId: UtilitySlot.return)],
        ]
    )

    // MARK: - Numeric Landscape

    private static let numericLandscape = GridArrangement(
        columns: 5,
        rows: [
            [
                .init(keyId: UtilitySlot.globe),
                .init(keyId: GridSlot.topLeft),
                .init(keyId: GridSlot.topCenter),
                .init(keyId: GridSlot.topRight),
                .init(keyId: UtilitySlot.delete),
            ],
            [
                .init(keyId: UtilitySlot.symbols),
                .init(keyId: GridSlot.midLeft),
                .init(keyId: GridSlot.center),
                .init(keyId: GridSlot.midRight),
                .init(keyId: UtilitySlot.return, heightMultiplier: 2),
            ],
            [
                .init(keyId: GridSlot.zero),
                .init(keyId: GridSlot.bottomLeft),
                .init(keyId: GridSlot.bottomCenter),
                .init(keyId: GridSlot.bottomRight),
            ],
        ]
    )

    // MARK: - Utility-Left Variants

    /// The utility keys that move to the leading edge when "Utility Keys on
    /// Left" is enabled: globe, symbols, delete, and return — in the same
    /// top-to-bottom order as the trailing column. The space bar and all
    /// letter/digit keys keep their original left-to-right order.
    static let leadingUtilityKeys: Set<String> = [
        UtilitySlot.globe, UtilitySlot.symbols, UtilitySlot.delete, UtilitySlot.return,
    ]

    private static func utilityLeft(_ arrangement: GridArrangement) -> GridArrangement {
        arrangement.movingToLeading(keyIds: leadingUtilityKeys)
    }

    // MARK: - All 4 Contexts

    /// All 4 arrangement contexts for 3x3 grid layouts.
    static let grid3x3: [ArrangementContext: GridArrangement] = [
        .portrait: portrait,
        .portraitUtilityLeft: utilityLeft(portrait),
        .landscape: landscape,
        .landscapeUtilityLeft: utilityLeft(landscape),
    ]

    /// Numeric mode: same as grid3x3 but with an extra "0" key in the bottom row.
    static let numeric3x3: [ArrangementContext: GridArrangement] = [
        .portrait: numericPortrait,
        .portraitUtilityLeft: utilityLeft(numericPortrait),
        .landscape: numericLandscape,
        .landscapeUtilityLeft: utilityLeft(numericLandscape),
    ]
}
