//
//  AdvancedTextMiddlewareTests.swift
//  WurstfingerTests
//
//  Tests for AdvancedTextMiddleware: delete-forward, capitalize-word, and
//  clipboard (copy/paste/cut). These handlers perform multi-step proxy
//  interaction and are driven here through MockTextTarget.
//

import Foundation
import Testing
import UIKit
@testable import WurstfingerApp

// MARK: - Helpers

private enum AdvancedTextFixtures {
    static func context(_ action: KeyAction, mode: String = "main") -> ActionContext {
        ActionContext(action: action, binding: nil, mode: mode)
    }

    /// Builds a middleware bound to `target` using the German locale (matches
    /// the app's default uppercasing behaviour, e.g. `ß → SS`).
    static func middleware(
        target: MockTextTarget,
        localeId: String = "de_DE",
        cutAllEnabled: Bool = true,
        onClipboardSuccess: @escaping () -> Void = {}
    ) -> AdvancedTextMiddleware {
        AdvancedTextMiddleware(
            target: { target },
            locale: { Locale(identifier: localeId) },
            onClipboardSuccess: onClipboardSuccess,
            isCutAllEnabled: { cutAllEnabled }
        )
    }
}

// MARK: - Process / forwarding

struct AdvancedTextMiddlewareProcessTests {
    @Test func forwardsContextToNext() {
        let target = MockTextTarget()
        let middleware = AdvancedTextFixtures.middleware(target: target)

        var forwarded: ActionContext?
        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { forwarded = $0 }

        #expect(forwarded != nil)
        #expect(forwarded?.action == .deleteForward)
    }

    @Test func ignoresUnhandledActionsButStillForwards() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "hallo"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        var forwarded = false
        // .space is not handled by AdvancedTextMiddleware → no target events.
        middleware.process(AdvancedTextFixtures.context(.space)) { _ in forwarded = true }

        #expect(forwarded)
        #expect(target.events.isEmpty)
    }

    @Test func noopWhenTargetUnavailable() {
        // target provider returns nil → no crash, still forwards.
        let middleware = AdvancedTextMiddleware(
            target: { nil },
            locale: { Locale(identifier: "de_DE") }
        )

        var forwarded = false
        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in forwarded = true }

        #expect(forwarded)
    }
}

// MARK: - Delete forward

struct AdvancedTextMiddlewareDeleteForwardTests {
    @Test func deletesCharacterAfterCursor() {
        let target = MockTextTarget()
        target.documentContextAfterInput = "xyz"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events == [.adjustCursor(1), .deleteBackward])
    }

    @Test func noopWhenNothingAfterCursor() {
        let target = MockTextTarget()
        target.documentContextAfterInput = ""
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events.isEmpty)
    }

    @Test func noopWhenAfterContextIsNil() {
        let target = MockTextTarget()
        target.documentContextAfterInput = nil
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events.isEmpty)
    }

    @Test func deletesWholeSurrogatePairEmojiAfterCursor() {
        let target = MockTextTarget()
        // 👍 = surrogate pair = 2 UTF-16 units; a fixed +1 offset would land
        // mid-pair and the deleteBackward would corrupt the emoji.
        target.documentContextAfterInput = "👍abc"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events == [.adjustCursor(2), .deleteBackward])
        #expect(target.documentContextBeforeInput == "")
        #expect(target.documentContextAfterInput == "abc")
    }

    @Test func deletesWholeSkinToneEmojiAfterCursor() {
        let target = MockTextTarget()
        // 👍🏽 = thumbs up + skin-tone modifier = 4 UTF-16 units.
        target.documentContextAfterInput = "👍🏽abc"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events == [.adjustCursor(4), .deleteBackward])
        #expect(target.documentContextBeforeInput == "")
        #expect(target.documentContextAfterInput == "abc")
    }

    @Test func deletesWholeZWJFamilyEmojiAfterCursor() {
        let target = MockTextTarget()
        // 👨‍👩‍👧‍👦 = ZWJ family sequence = 11 UTF-16 units.
        target.documentContextAfterInput = "👨‍👩‍👧‍👦!"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        #expect(target.events == [.adjustCursor(11), .deleteBackward])
        #expect(target.documentContextBeforeInput == "")
        #expect(target.documentContextAfterInput == "!")
    }
}

// MARK: - Capitalize word

struct AdvancedTextCapitalizeWordTests {
    @Test func uppercasesWordBeforeCursor() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "hallo"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        #expect(target.events == [
            .deleteBackward, .deleteBackward, .deleteBackward, .deleteBackward, .deleteBackward,
            .insertText("HALLO"),
        ])
        #expect(target.documentContextBeforeInput == "HALLO")
    }

    @Test func lowercasesWordWhenNotUppercased() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "HALLO"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: false))) { _ in }

        #expect(target.documentContextBeforeInput == "hallo")
    }

    @Test func onlyAffectsLastWordStoppingAtNonLetter() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "Hallo welt"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        // Stops at the space → only "welt" is transformed.
        #expect(target.documentContextBeforeInput == "Hallo WELT")
    }

    @Test func stopsAtDigitBoundary() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "abc123def"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        #expect(target.documentContextBeforeInput == "abc123DEF")
    }

    @Test func usesGermanLocaleForSharpS() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "straße"
        let middleware = AdvancedTextFixtures.middleware(target: target, localeId: "de_DE")

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        // German uppercasing expands ß → SS.
        #expect(target.documentContextBeforeInput == "STRASSE")
    }

    @Test func noopWhenContextEmpty() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = ""
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        #expect(target.events.isEmpty)
    }

    @Test func noopWhenLastCharacterIsNotLetter() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "hallo "
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        // Trailing space means no word characters collected → no-op.
        #expect(target.events.isEmpty)
        #expect(target.documentContextBeforeInput == "hallo ")
    }
}

// MARK: - Clipboard

// Serialized: these tests share the process-wide `UIPasteboard.general`
// singleton, so they must not run concurrently with one another. A fresh
// instance is created per test, so capturing the pasteboard in `init` and
// restoring it in `deinit` reverts any clipboard writes and prevents leaking
// process-global state into later tests.
@Suite(.serialized)
final class AdvancedTextMiddlewareClipboardTests {
    private let originalPasteboard: String?

    init() {
        originalPasteboard = UIPasteboard.general.string
    }

    deinit { UIPasteboard.general.string = originalPasteboard }

    @Test func copyWritesSelectionToPasteboardWithFullAccess() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = "copied-\(UUID().uuidString)"
        let expected = target.selectedText
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.copy)) { _ in }

        #expect(UIPasteboard.general.string == expected)
        #expect(target.events.isEmpty) // copy must not mutate the document
        #expect(successTicks == 1)
    }

    @Test func copyIsNoopWithoutFullAccess() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = false
        target.selectedText = "secret"
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.copy)) { _ in }

        #expect(UIPasteboard.general.string == marker) // unchanged
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func copyIsNoopWhenNothingSelected() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = nil
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.copy)) { _ in }

        #expect(UIPasteboard.general.string == marker) // unchanged
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func pasteInsertsClipboardTextWithFullAccess() {
        let text = "pasted-\(UUID().uuidString)"
        UIPasteboard.general.string = text

        let target = MockTextTarget()
        target.hasFullAccess = true
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        #expect(target.events == [.insertText(text)])
        #expect(successTicks == 1)
    }

    @Test func pasteIsNoopWithoutFullAccess() {
        UIPasteboard.general.string = "anything"

        let target = MockTextTarget()
        target.hasFullAccess = false
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        #expect(target.events.isEmpty)
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func pasteIsNoopWhenPasteboardEmpty() {
        UIPasteboard.general.items = []

        let target = MockTextTarget()
        target.hasFullAccess = true
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        #expect(target.events.isEmpty)
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func pasteTruncatesOversizedPasteboardText() {
        // 250k UTF-16 units — above the 200k cap. ASCII, so units == Characters.
        let oversized = String(repeating: "a", count: 250_000)
        UIPasteboard.general.string = oversized

        let target = MockTextTarget()
        target.hasFullAccess = true
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        let expected = String(repeating: "a", count: KeyboardConstants.TextInput.maxPasteUTF16Length)
        #expect(target.events == [.insertText(expected)])
        #expect(successTicks == 1, "A truncated paste still inserts text and ticks")
    }

    @Test func cutCopiesSelectionAndDeletes() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = "cut-\(UUID().uuidString)"
        let expected = target.selectedText
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(UIPasteboard.general.string == expected)
        #expect(target.events == [.deleteBackward])
        #expect(successTicks == 1)
    }

    @Test func cutIsNoopWithoutFullAccess() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = false
        target.selectedText = "secret"
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(target.events.isEmpty)
        #expect(UIPasteboard.general.string == marker) // pasteboard untouched
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func cutIsNoopWhenNothingSelected() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = nil
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(target.events.isEmpty)
        #expect(UIPasteboard.general.string == marker) // pasteboard untouched
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    // MARK: cut-all

    @Test func cutAllCopiesContextOnBothSidesOfCursorAndEmptiesIt() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = "hallo "
        target.documentContextAfterInput = "welt"
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "hallo welt")
        // Cursor parked past "welt" (4 UTF-16 units), then all 10 characters deleted.
        #expect(target.events == [.adjustCursor(4)] + Array(repeating: .deleteBackward, count: 10))
        #expect(target.documentContextBeforeInput == "")
        #expect(target.documentContextAfterInput == "")
        #expect(successTicks == 1)
    }

    @Test func cutAllDoesNotMoveCursorWhenNothingFollowsIt() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = "hallo"
        target.documentContextAfterInput = ""
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "hallo")
        #expect(target.events == Array(repeating: .deleteBackward, count: 5))
    }

    @Test func cutAllTreatsFusedGraphemeClusterAcrossCursorAsOneCharacter() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        // The cursor sits between a base letter and its combining acute accent,
        // which join into the single cluster "é" — one deleteBackward, not two.
        target.documentContextBeforeInput = "e"
        target.documentContextAfterInput = "\u{0301}"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "e\u{0301}")
        #expect(target.events == [.adjustCursor(1), .deleteBackward])
    }

    @Test func cutAllDeletesMultiUnitEmojiAsOneCharacter() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = ""
        // ZWJ family: 11 UTF-16 units, one grapheme cluster.
        target.documentContextAfterInput = "👨‍👩‍👧‍👦"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "👨‍👩‍👧‍👦")
        #expect(target.events == [.adjustCursor(11), .deleteBackward])
    }

    @Test func cutAllIsNoopWhenDisabledInSettings() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = "secret"
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(
            target: target,
            cutAllEnabled: false
        ) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(target.events.isEmpty)
        #expect(UIPasteboard.general.string == marker) // pasteboard untouched
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    /// The switch gates cut-all only — the plain clipboard swipes on the same
    /// key must keep working when it is off.
    @Test func disablingCutAllLeavesPlainCutWorking() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = "picked"
        let middleware = AdvancedTextFixtures.middleware(target: target, cutAllEnabled: false)

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(UIPasteboard.general.string == "picked")
        #expect(target.events == [.deleteBackward])
    }

    @Test func cutAllIsNoopWithoutFullAccess() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = false
        target.documentContextBeforeInput = "secret"
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(target.events.isEmpty)
        #expect(UIPasteboard.general.string == marker) // pasteboard untouched
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }

    @Test func cutAllIsNoopWhenDocumentIsEmpty() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = nil
        target.documentContextAfterInput = nil
        var successTicks = 0
        let middleware = AdvancedTextFixtures.middleware(target: target) { successTicks += 1 }

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(target.events.isEmpty)
        #expect(UIPasteboard.general.string == marker) // pasteboard untouched
        #expect(successTicks == 0, "A guarded no-op must not fire a success tick")
    }
}

// MARK: - Paste size cap

/// `cappedForInsertion` is pure, so the truncation semantics are tested
/// directly with small caps; the 200k production cap is exercised once via
/// the pasteboard in `pasteTruncatesOversizedPasteboardText` above.
struct AdvancedTextPasteCapTests {
    @Test func returnsShortTextUnchanged() {
        let text = "hello wörld 👍🏽"
        #expect(AdvancedTextMiddleware.cappedForInsertion(text) == text)
    }

    @Test func returnsTextExactlyAtCapUnchanged() {
        let text = "abc"
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 3) == "abc")
    }

    @Test func truncatesToCapInUTF16Units() {
        let text = "abcdef"
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 4) == "abcd")
    }

    @Test func neverSplitsAGraphemeCluster() {
        // 👍🏽 = base + skin tone = 4 UTF-16 units. A cap that lands inside the
        // cluster must round down to the previous boundary.
        let text = "a👍🏽b"
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 3) == "a")
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 4) == "a")
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 5) == "a👍🏽")
    }

    @Test func neverSplitsAZWJFamilySequence() {
        // 👨‍👩‍👧‍👦 = ZWJ family sequence = 11 UTF-16 units.
        let family = "👨‍👩‍👧‍👦"
        let text = "ab" + family
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 12) == "ab")
        #expect(AdvancedTextMiddleware.cappedForInsertion(text, maxUTF16Length: 13) == text)
    }
}
