//
//  ComposeSpaceGuardTests.swift
//  WurstfingerTests
//
//  Locks the space-handling behavior of ComposeMiddleware after the
//  `previous != " "` guard was removed (finding #6). Space handling now lives
//  entirely in the rule data: the acute/grave compose keys normalize a
//  preceding space into a typographic character, while the other modifiers
//  preserve the space (their self-referential `" "` rows were stripped).
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct ComposeSpaceGuardTests {
    /// `"word "` + grave compose commits a backtick, consuming the space
    /// (matches shipped 1.3.1). This is the failing-before/passing-after case
    /// unblocked by removing the middleware's space guard.
    @Test func graveComposeAfterSpaceCommitsBacktick() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "word "

        vm.dispatchAction(.compose(trigger: "ˋ"))

        #expect(target.documentContextBeforeInput == "word`")
        #expect(target.events == [.deleteBackward, .insertText("`")])
    }

    /// `"word "` + acute compose commits an apostrophe, consuming the space.
    @Test func acuteComposeAfterSpaceCommitsApostrophe() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "word "

        vm.dispatchAction(.compose(trigger: "´"))

        #expect(target.documentContextBeforeInput == "word'")
        #expect(target.events == [.deleteBackward, .insertText("'")])
    }

    /// A plain modifier (e.g. circumflex) after a space now preserves the
    /// space: the self-referential `" ": "^"` row was stripped, so the lookup
    /// returns nil and the trigger is inserted verbatim.
    @Test func plainModifierAfterSpacePreservesSpace() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "word "

        vm.dispatchAction(.compose(trigger: "^"))

        #expect(target.documentContextBeforeInput == "word ^")
        #expect(target.events == [.insertText("^")])
    }

    /// Compose still resolves a real accent when a letter precedes the cursor,
    /// confirming the guard removal did not break the primary compose path.
    @Test func acuteComposeAfterLetterStillAccents() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "a"

        vm.dispatchAction(.compose(trigger: "´"))

        #expect(target.documentContextBeforeInput == "á")
        #expect(target.events == [.deleteBackward, .insertText("á")])
    }

    /// With an active selection the compose trigger replaces the selection
    /// verbatim rather than deleting the preceding character (finding #5
    /// parity applied to ComposeMiddleware).
    @Test func composeReplacesActiveSelectionWithRawTrigger() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "a"
        target.selectedText = "SEL"

        vm.dispatchAction(.compose(trigger: "´"))

        #expect(target.documentContextBeforeInput == "a´")
        #expect(target.selectedText == nil)
        #expect(!target.events.contains(.deleteBackward))
    }
}
