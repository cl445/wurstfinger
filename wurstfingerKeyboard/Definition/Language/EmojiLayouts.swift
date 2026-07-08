//
//  EmojiLayouts.swift
//  Wurstfinger
//
//  Emoji keyboard mode: direct-select keys for the most-used emojis.
//

import Foundation

/// Emoji keyboard mode shared across all languages.
///
/// The 3x3 grid plus a three-way split space row gives 12 direct-select emoji
/// keys — every emoji is a plain tap with a full-size label, no swipe
/// gestures. The set is a static pick of the globally most-used emojis
/// (Unicode CLDR frequency data); usage-based personalization and a full
/// browse view are follow-ups.
enum EmojiLayouts {
    /// The 12 default emojis in display order: three 3x3 grid rows followed
    /// by the split space row.
    static let defaultEmojis: [[String]] = [
        ["😂", "❤️", "🤣"],
        ["👍", "😭", "🙏"],
        ["😘", "🥰", "😍"],
        ["😊", "🎉", "😁"],
    ]

    /// Slot ids matching `defaultEmojis` row by row.
    static let slotRows: [[String]] = GridSlot.allSlots + [[
        GridSlot.emojiExtraLeft, GridSlot.emojiExtraCenter, GridSlot.emojiExtraRight,
    ]]

    /// Builds the emoji mode. `backToAlphaLabel` labels the key that returns
    /// to the main (alphabetic) layer, matching the numeric layer's label.
    static func mode(backToAlphaLabel: String = NumericLayouts.defaultBackToAlphaLabel) -> KeyboardMode {
        var keys: [String: KeyConfig] = [:]
        for (rowIdx, row) in defaultEmojis.enumerated() {
            for (colIdx, emoji) in row.enumerated() {
                let slotId = slotRows[rowIdx][colIdx]
                keys[slotId] = emojiKey(slotId, emoji: emoji)
            }
        }

        keys[UtilitySlot.globe] = CommonKeys.globe
        keys[UtilitySlot.delete] = CommonKeys.delete
        keys[UtilitySlot.return] = CommonKeys.return
        keys[UtilitySlot.symbols] = backToMain(label: backToAlphaLabel)

        return KeyboardMode(
            name: ModeNames.emoji,
            keys: keys,
            arrangements: StandardArrangements.emoji3x3,
            autoTransitions: [:],
            doubleTapMode: nil
        )
    }

    /// Direct-select emoji key: tap commits the emoji, no swipe bindings.
    /// The explicit `.emoji` category keeps the label exempt from the
    /// practice-mode label-hiding toggles.
    private static func emojiKey(_ id: String, emoji: String) -> KeyConfig {
        KeyConfig(
            id: id,
            bindings: [
                .tap: KeyBinding(
                    label: emoji, action: .commitText(emoji),
                    category: .emoji, returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .none,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
    }

    /// Back-to-alphabet key on the symbols slot, mirroring the numeric layer.
    private static func backToMain(label: String) -> KeyConfig {
        KeyConfig.utility(
            UtilitySlot.symbols, label: label, action: .switchMode(ModeNames.main),
            swipeMode: .eightWay,
            swipes: CommonKeys.clipboardSwipes
        )
    }
}
