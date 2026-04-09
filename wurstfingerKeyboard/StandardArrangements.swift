//
//  StandardArrangements.swift
//  Wurstfinger
//
//  Standard grid arrangements for MessagEase 3x3 layouts.
//

import Foundation

/// Standard grid arrangements for MessagEase 3x3 layouts.
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

    // MARK: - All 4 Contexts

    /// All 4 arrangement contexts for MessagEase 3x3 layouts.
    static let messagEase3x3: [ArrangementContext: GridArrangement] = [
        .portrait: portrait,
        .portraitUtilityLeft: portrait.mirroredHorizontally(),
        .landscape: landscape,
        .landscapeUtilityLeft: landscape.mirroredHorizontally(),
    ]
}
