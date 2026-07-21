//
//  KeyAction.swift
//  Wurstfinger
//
//  All possible actions a key binding can trigger.
//

import Foundation

/// All possible actions a key binding can trigger.
enum KeyAction: Codable, Equatable {
    /// Insert text
    case commitText(String)

    /// Compose trigger (accent composition with previous character)
    case compose(trigger: String)

    /// Cycle through accents (ä → â → à → ...)
    case cycleAccents

    /// Switch to another mode by name.
    /// e.g. "shifted", "numeric", "emoji", "symbols", "main"
    case switchMode(String)

    /// Capitalize/uncapitalize last word
    case capitalizeWord(uppercased: Bool)

    /// Next input method (Globe key)
    case advanceToNextInputMode

    /// Dismiss keyboard
    case dismissKeyboard

    /// Switch to the next enabled language
    case switchToNextLanguage

    /// Delete backward
    case deleteBackward

    /// Delete forward
    case deleteForward

    /// Space
    case space

    /// Newline
    case newline

    /// Move cursor
    case moveCursor(offset: Int)

    /// Clipboard
    case copy, paste, cut

    /// Cut everything the document proxy exposes, without a prior selection.
    /// The proxy offers no way to select text, so this reads the context
    /// around the cursor instead — see `AdvancedTextMiddleware.handleCutAll`.
    case cutAll

    /// No action (empty slot)
    case none
}
