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
        localeId: String = "de_DE"
    ) -> AdvancedTextMiddleware {
        AdvancedTextMiddleware(
            target: { target },
            locale: { Locale(identifier: localeId) }
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
// singleton, so they must not run concurrently with one another.
@Suite(.serialized)
struct AdvancedTextMiddlewareClipboardTests {
    @Test func copyWritesSelectionToPasteboardWithFullAccess() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = "copied-\(UUID().uuidString)"
        let expected = target.selectedText
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.copy)) { _ in }

        #expect(UIPasteboard.general.string == expected)
        #expect(target.events.isEmpty) // copy must not mutate the document
    }

    @Test func copyIsNoopWithoutFullAccess() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = false
        target.selectedText = "secret"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.copy)) { _ in }

        #expect(UIPasteboard.general.string == marker) // unchanged
    }

    @Test func pasteInsertsClipboardTextWithFullAccess() {
        let text = "pasted-\(UUID().uuidString)"
        UIPasteboard.general.string = text

        let target = MockTextTarget()
        target.hasFullAccess = true
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        #expect(target.events == [.insertText(text)])
    }

    @Test func pasteIsNoopWithoutFullAccess() {
        UIPasteboard.general.string = "anything"

        let target = MockTextTarget()
        target.hasFullAccess = false
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.paste)) { _ in }

        #expect(target.events.isEmpty)
    }

    @Test func cutCopiesSelectionAndDeletes() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = "cut-\(UUID().uuidString)"
        let expected = target.selectedText
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(UIPasteboard.general.string == expected)
        #expect(target.events == [.deleteBackward])
    }

    @Test func cutIsNoopWithoutFullAccess() {
        let target = MockTextTarget()
        target.hasFullAccess = false
        target.selectedText = "secret"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(target.events.isEmpty)
    }

    @Test func cutIsNoopWhenNothingSelected() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.selectedText = nil
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cut)) { _ in }

        #expect(target.events.isEmpty)
    }
}
