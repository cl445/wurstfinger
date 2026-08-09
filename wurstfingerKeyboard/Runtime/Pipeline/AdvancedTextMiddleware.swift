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
        // The proxy deletes a selected range as one unit, so forward-delete
        // over a selection *is* a plain deleteBackward. Stepping over the
        // trailing context first would move past the selection and delete an
        // unrelated character — or, with nothing behind it, do nothing at all.
        if let selected = target.selectedText, !selected.isEmpty {
            target.deleteBackward()
            return
        }
        guard let next = target.documentContextAfterInput?.first else { return }
        // `adjustTextPosition` moves by UTF-16 code units, so cross the whole
        // grapheme cluster (emoji can span 2+ units); a fixed +1 would land
        // mid-surrogate and delete the wrong character.
        target.adjustTextPosition(byCharacterOffset: next.utf16.count)
        target.deleteBackward()
    }

    // MARK: - Capitalize Word

    private func capitalizeWord(target: TextInputTarget, uppercased: Bool) {
        // With a selection the case change applies to the selection itself:
        // inserting over it replaces it in one step. The word lookback below
        // would instead consume the whole selection with its first
        // deleteBackward and then eat the word in front of it.
        if let selected = target.selectedText, !selected.isEmpty {
            target.insertText(cased(selected, uppercased: uppercased))
            return
        }
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
        let transformed = cased(word, uppercased: uppercased)

        for _ in 0 ..< word.count {
            target.deleteBackward()
        }
        target.insertText(transformed)
    }

    /// Case change in the active layout's locale (German `ß → SS`, Turkish
    /// dotless `i`, …).
    private func cased(_ text: String, uppercased: Bool) -> String {
        let locale = localeProvider()
        return uppercased ? text.uppercased(with: locale) : text.lowercased(with: locale)
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
        // The pasteboard is the gesture path's only external I/O — the writes in
        // handleCopy/handleCut/handleCutAll cross to pasteboardd on this same
        // thread — but this read is the one that can end up waiting on something
        // other than the daemon, and that is an accepted tradeoff: a Universal
        // Clipboard item makes the getter wait for the transfer from the other
        // device, and under the "Ask" paste permission it waits for the system
        // alert — the keyboard's main thread sits inside this line for as long
        // as that takes. What makes it acceptable rather than a hang: both are
        // user-initiated (this is a paste swipe), the system narrates them with
        // its own HUD or alert, the host app stays responsive throughout, and
        // UIKit's own paste blocks exactly the same way. `hasStrings` is no
        // escape — the fetch is what blocks, not the emptiness check.
        //
        // If it ever has to become non-blocking: read asynchronously through
        // `itemProviders`/`loadObject`, hop back to the main thread to insert,
        // and drop the result if the gesture that asked for it is no longer the
        // current one — by then the cursor may have moved or the keyboard may
        // have been torn down.
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
        // Bounded like a paste: every character below costs one deleteBackward
        // round-trip to the host app, and the proxy imposes no size limit of
        // its own. Past the cap the cut is refused rather than half-applied —
        // a silent no-op like the guards above.
        guard !Self.exceedsCutLimit(all) else { return }

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

    /// Whether `text` is too large to cut in one gesture. Shares
    /// `KeyboardConstants.TextInput.maxPasteUTF16Length` with
    /// `cappedForInsertion`, so a single action moves at most that much text in
    /// either direction: an oversized insertion truncates, an oversized
    /// deletion is refused — truncating it would mangle the document while
    /// putting only part of it on the pasteboard.
    static func exceedsCutLimit(
        _ text: String,
        maxUTF16Length: Int = KeyboardConstants.TextInput.maxPasteUTF16Length
    ) -> Bool {
        text.utf16.count > maxUTF16Length
    }
}
