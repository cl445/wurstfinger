//
//  AdvancedTextMiddleware.swift
//  Wurstfinger
//
//  Handles text actions that require more than a simple proxy call:
//  delete-forward, capitalize-word, word-cursor movement, and clipboard.
//

import UIKit

/// Handles advanced text-input actions that `TextInputMiddleware` leaves
/// as pass-through: delete-forward, capitalize-word, word-boundary cursor
/// movement, and clipboard (copy/paste/cut).
///
/// These actions need multi-step proxy interaction (e.g. read context,
/// delete, re-insert) and are therefore separated from the basic middleware
/// to keep each middleware focused and independently testable.
struct AdvancedTextMiddleware: ActionMiddleware {
    private let targetProvider: () -> TextInputTarget?
    private let localeProvider: () -> Locale
    private let onClipboardSuccess: () -> Void
    private let isCutAllEnabled: () -> Bool

    init(
        target: @escaping () -> TextInputTarget?,
        locale: @escaping () -> Locale,
        onClipboardSuccess: @escaping () -> Void = {},
        isCutAllEnabled: @escaping () -> Bool = { true }
    ) {
        targetProvider = target
        localeProvider = locale
        self.onClipboardSuccess = onClipboardSuccess
        self.isCutAllEnabled = isCutAllEnabled
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        if let target = targetProvider() {
            apply(action: context.action, to: target)
        }
        next(context)
    }

    private func apply(action: KeyAction, to target: TextInputTarget) {
        switch action {
        case .deleteForward:
            deleteForward(target: target)
        case let .capitalizeWord(uppercased):
            capitalizeWord(target: target, uppercased: uppercased)
        case .copy:
            handleCopy(target: target)
        case .paste:
            handlePaste(target: target)
        case .cut:
            handleCut(target: target)
        case .cutAll:
            handleCutAll(target: target)
        default:
            break
        }
    }

    // MARK: - Delete Forward

    private func deleteForward(target: TextInputTarget) {
        guard let next = target.documentContextAfterInput?.first else { return }
        // `adjustTextPosition` moves by UTF-16 code units, so cross the whole
        // grapheme cluster (emoji can span 2+ units); a fixed +1 would land
        // mid-surrogate and delete the wrong character.
        target.adjustTextPosition(byCharacterOffset: next.utf16.count)
        target.deleteBackward()
    }

    // MARK: - Capitalize Word

    private func capitalizeWord(target: TextInputTarget, uppercased: Bool) {
        guard let context = target.documentContextBeforeInput, !context.isEmpty else { return }

        var characters: [Character] = []
        for character in context.reversed() {
            if character.isLetter {
                characters.append(character)
            } else {
                break
            }
        }
        guard !characters.isEmpty else { return }

        let word = String(characters.reversed())
        let locale = localeProvider()
        let transformed = uppercased ? word.uppercased(with: locale) : word.lowercased(with: locale)

        for _ in 0 ..< word.count {
            target.deleteBackward()
        }
        target.insertText(transformed)
    }

    // MARK: - Clipboard

    // The clipboard confirmation tick fires from the success paths below —
    // not from the haptic middleware — so a guarded no-op (no full access,
    // empty selection/pasteboard) stays silent, mirroring how mode and
    // language switches only tick on an actual change.

    private func handleCopy(target: TextInputTarget) {
        guard target.hasFullAccess else { return }
        if let selected = target.selectedText, !selected.isEmpty {
            UIPasteboard.general.string = selected
            onClipboardSuccess()
        }
    }

    private func handlePaste(target: TextInputTarget) {
        guard target.hasFullAccess else { return }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            // Cap pasted text so a multi-MB pasteboard cannot blow the
            // keyboard extension's jetsam memory budget. Truncates silently.
            target.insertText(Self.cappedForInsertion(text))
            onClipboardSuccess()
        }
    }

    private func handleCut(target: TextInputTarget) {
        guard target.hasFullAccess else { return }
        if let selected = target.selectedText, !selected.isEmpty {
            UIPasteboard.general.string = selected
            target.deleteBackward()
            onClipboardSuccess()
        }
    }

    /// Cuts everything the proxy exposes around the cursor: the surrounding
    /// context goes to the pasteboard and is then deleted.
    ///
    /// This is as close to "select all and cut" as an extension can get. The
    /// proxy has no API to set a selection, so `handleCut` above can only act
    /// on a selection the user made by hand; here the text is read from the
    /// two context properties instead. Those reach no further than the current
    /// paragraph, so in a multi-paragraph field this cuts that paragraph
    /// rather than the whole document — single-line fields, where the feature
    /// earns its keep, are unaffected.
    ///
    /// Deletion is destructive and unaided by undo, hence cut rather than
    /// delete: the pasteboard copy makes an accidental circle recoverable
    /// with the paste swipe on the same key.
    private func handleCutAll(target: TextInputTarget) {
        guard isCutAllEnabled(), target.hasFullAccess else { return }
        // With an active selection the context properties describe the text
        // *around* it, so the selection must be stitched back in for the
        // pasteboard — and consumed by its own deleteBackward below, because
        // the proxy deletes a selected range as one unit and the counting
        // loop would otherwise run past the document.
        let before = target.documentContextBeforeInput ?? ""
        let selected = target.selectedText ?? ""
        let after = target.documentContextAfterInput ?? ""
        let all = before + selected + after
        guard !all.isEmpty else { return }

        UIPasteboard.general.string = all

        if !selected.isEmpty {
            target.deleteBackward()
        }
        // Deletion only runs backwards, so park the cursor past the trailing
        // context first. The offset is in UTF-16 code units (see the protocol).
        if !after.isEmpty {
            target.adjustTextPosition(byCharacterOffset: after.utf16.count)
        }
        // Counted over the joined string, not the two halves: a combining mark
        // leading `after` fuses with the last character of `before` into one
        // grapheme cluster, and deleteBackward removes clusters, so summing the
        // halves separately would delete one character too many.
        for _ in 0 ..< (before + after).count {
            target.deleteBackward()
        }
        onClipboardSuccess()
    }

    /// Returns `text` capped at `KeyboardConstants.TextInput.maxPasteUTF16Length`
    /// UTF-16 code units, cut at a grapheme-cluster boundary so no emoji or
    /// combining sequence is ever split. The cheap `utf16.count` check makes
    /// the common (small) case allocation-free; the truncating path walks at
    /// most the capped prefix, so the memory bound holds for the copy too.
    static func cappedForInsertion(
        _ text: String,
        maxUTF16Length: Int = KeyboardConstants.TextInput.maxPasteUTF16Length
    ) -> String {
        guard text.utf16.count > maxUTF16Length else { return text }
        var usedUTF16 = 0
        var end = text.startIndex
        while end < text.endIndex {
            let next = text.index(after: end)
            usedUTF16 += text[end].utf16.count
            if usedUTF16 > maxUTF16Length { break }
            end = next
        }
        return String(text[..<end])
    }
}
