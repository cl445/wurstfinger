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

    @Test func deletesActiveSelectionAsOneUnit() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "abc"
        target.selectedText = "def"
        target.documentContextAfterInput = "!"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        // The proxy removes a selected range with a single deleteBackward;
        // stepping over "!" first would delete that instead of the selection.
        #expect(target.events == [.deleteBackward])
        #expect(target.selectedText == nil)
        #expect(target.documentContextBeforeInput == "abc")
        #expect(target.documentContextAfterInput == "!")
    }

    @Test func deletesActiveSelectionAtEndOfDocument() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "abc"
        target.selectedText = "def"
        target.documentContextAfterInput = ""
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.deleteForward)) { _ in }

        // Nothing follows the selection, so the "nothing to delete forward"
        // guard must not swallow it.
        #expect(target.events == [.deleteBackward])
        #expect(target.selectedText == nil)
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

    @Test func uppercasesActiveSelectionInsteadOfPrecedingWord() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "abc"
        target.selectedText = "def"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: true))) { _ in }

        // The selection is replaced in a single insert, so the word in front
        // of it stays untouched.
        #expect(target.events == [.insertText("DEF")])
        #expect(target.selectedText == nil)
        #expect(target.documentContextBeforeInput == "abcDEF")
    }

    @Test func lowercasesActiveSelection() {
        let target = MockTextTarget()
        target.documentContextBeforeInput = "abc"
        target.selectedText = "DEF"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.capitalizeWord(uppercased: false))) { _ in }

        #expect(target.events == [.insertText("def")])
        #expect(target.documentContextBeforeInput == "abcdef")
    }
}

// MARK: - Clipboard

/// One-time probe for the process-global pasteboard, so a wedged daemon costs
/// this suite a bounded wait instead of the whole run.
///
/// `UIPasteboard.general` talks to a system service, and on a cold simulator the
/// first call can block for a very long time before returning perfectly normal
/// data: one review run measured `copyWritesSelectionToPasteboardWithFullAccess`
/// at 2268 s (~38 min) — and then green — where a healthy run takes 1.4 s. The
/// call is not cancellable, so the probe hands it to a background thread and
/// waits with a deadline; the answer decides whether the suite runs at all.
///
/// The environment-dependent tests in this target, worth knowing before chasing
/// a slow or oddly-failing run:
///
/// - `LongPressSchedulerTests` — the only wall-clock unit tests: 20–50 ms timers
///   awaited with 200–300 ms sleeps. Tightest budget in the suite; its negative
///   tests can false-pass under load, not flake.
/// - This suite — process-global pasteboard, serialized and capture/restore-ed;
///   cross-suite safety rests on nothing else touching `UIPasteboard.general`.
/// - `KeyboardHealthLogTests` — permission-dependent cases; false-fail as root.
/// - `SettingsReloadObserverTests` — drains the runloop against wall-clock time.
private enum PasteboardWarmUp {
    /// Far above a healthy cold start (single-digit seconds), far below the
    /// pathology (tens of minutes). Nothing legitimate lives in between.
    static let deadline: TimeInterval = 30

    /// Whether a full write/read/restore round-trip came back inside
    /// `deadline`. Resolved once per process — later reads are free, so every
    /// test can ask.
    ///
    /// The probe **writes**, and that is the whole point. A read of an empty
    /// pasteboard can answer instantly on a host whose write path is wedged:
    /// measured on one such machine, a read-only probe passed while
    /// `copyWritesSelectionToPasteboardWithFullAccess` — the first test to
    /// *assign* `UIPasteboard.general.string` — then took 59 minutes and
    /// passed. A read-only probe therefore certifies an environment it never
    /// exercised. Since `xcodebuild` runs the target in parallel clones and
    /// each clone is its own process resolving this on its own, one clone
    /// gating correctly does nothing for the next one; the probe has to test
    /// the operation that actually stalls.
    ///
    /// The restore is inside the probe because nothing else can do it: the
    /// suite's own capture/restore only runs once this has resolved.
    ///
    /// The probe's own write resolves during trait evaluation, outside the
    /// serialized suite and therefore possibly while other suites run — it is
    /// covered by the same invariant as the tests below: nothing else in the
    /// target touches `UIPasteboard.general`.
    static let didAnswer: Bool = {
        let answered = DispatchSemaphore(value: 0)
        // Detached on purpose: a stuck call owns its thread until the service
        // replies, and that must not be the thread the suite waits on. The
        // thread stays stuck for the rest of the run, which is survivable —
        // it holds no lock the suite needs, and a skipped suite touches the
        // pasteboard no further.
        DispatchQueue.global().async {
            // `items`, not `string`: assigning `string` replaces every item, so
            // capturing only the string would drop an image or a URL a
            // developer had on their clipboard when the suite ran.
            let original = UIPasteboard.general.items
            UIPasteboard.general.string = "warm-up-\(UUID().uuidString)"
            _ = UIPasteboard.general.string
            UIPasteboard.general.items = original
            answered.signal()
        }
        return answered.wait(timeout: .now() + deadline) == .success
    }()
}

/// Reports the wedged daemon as a failure of its own. Skipping the clipboard
/// suite keeps the run bounded, and this keeps the run *loud*: without it, a
/// stuck pasteboard would read as a green build with twenty quietly skipped
/// tests.
struct PasteboardEnvironmentTests {
    @Test func pasteboardAnswersWithinTheWarmUpDeadline() {
        #expect(
            PasteboardWarmUp.didAnswer,
            """
            UIPasteboard.general did not answer within \(Int(PasteboardWarmUp.deadline)) s — the known \
            cold-simulator pasteboard stall. AdvancedTextMiddlewareClipboardTests was skipped for this \
            run, so clipboard behaviour is unverified; re-run against a warm simulator (or reboot it).
            """
        )
    }
}

// Serialized: these tests share the process-wide `UIPasteboard.general`
// singleton, so they must not run concurrently with one another. A fresh
// instance is created per test, so capturing the pasteboard in `init` and
// restoring it in `deinit` reverts any clipboard writes and prevents leaking
// process-global state into later tests.
//
// `.serialized` only orders this suite against itself, so the capture/restore
// holds exactly as long as this stays the **only** place in the target that
// touches `UIPasteboard.general` — every other suite runs in parallel with it
// and would read or clobber a value mid-test. The invariant holds today:
// `CircularCutAllBindingTests` is the one other suite that could dispatch
// cut-all, and it deliberately asserts on the definition instead of running the
// action (see the comment on that struct). Re-verify with
// `grep -rn UIPasteboard wurstfingerTests --exclude=AdvancedTextMiddlewareTests.swift`
// — this file is excluded because it is the one place allowed to match, and the
// only remaining hit must be that comment in `CircularGesturePipelineTests.swift`.
// A new test that needs the real pasteboard belongs in this suite, not beside it.
//
// Gated on the warm-up rather than warmed up inside `init`, because a condition
// trait is the only hook that can still *decline* to run: once the daemon has
// gone quiet, every test body would otherwise pay the same unbounded block.
@Suite(
    .serialized,
    .enabled(
        if: PasteboardWarmUp.didAnswer,
        "The pasteboard did not answer within the warm-up deadline — see PasteboardEnvironmentTests"
    )
)
final class AdvancedTextMiddlewareClipboardTests {
    /// The whole pasteboard, not just its string: the tests below assign
    /// `string`, which replaces every item, so restoring a `String?` would
    /// leave a developer's image or URL destroyed by a test run.
    private let originalPasteboard: [[String: Any]]

    init() {
        // Free once the suite trait resolved it; keeps the capture below from
        // becoming the blocking call should trait evaluation ever move.
        _ = PasteboardWarmUp.didAnswer
        originalPasteboard = UIPasteboard.general.items
    }

    deinit { UIPasteboard.general.items = originalPasteboard }

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

    @Test func cutAllIncludesActiveSelectionInPasteboardAndDeletesIt() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = "abc"
        target.selectedText = "xyz"
        target.documentContextAfterInput = "def"
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "abcxyzdef")
        // The selection is consumed by its own deleteBackward first; only then
        // is the cursor parked past "def" and the remaining six characters
        // deleted — otherwise the first backward delete would swallow the
        // selection and the loop would run three deletes past the document.
        #expect(
            target.events == [.deleteBackward, .adjustCursor(3)]
                + Array(repeating: .deleteBackward, count: 6)
        )
        #expect(target.documentContextBeforeInput == "")
        #expect(target.documentContextAfterInput == "")
    }

    @Test func cutAllWithWholeTextSelectedActsLikeCut() {
        let target = MockTextTarget()
        target.hasFullAccess = true
        target.documentContextBeforeInput = ""
        target.selectedText = "everything"
        target.documentContextAfterInput = ""
        let middleware = AdvancedTextFixtures.middleware(target: target)

        middleware.process(AdvancedTextFixtures.context(.cutAll)) { _ in }

        #expect(UIPasteboard.general.string == "everything")
        #expect(target.events == [.deleteBackward])
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

    @Test func cutAllRefusesAnOversizedDocument() {
        let marker = "untouched-\(UUID().uuidString)"
        UIPasteboard.general.string = marker

        let target = MockTextTarget()
        target.hasFullAccess = true
        // One unit past the shared cap: cutting it would mean 200k+
        // deleteBackward round-trips to the host app.
        target.documentContextBeforeInput = String(
            repeating: "a", count: KeyboardConstants.TextInput.maxPasteUTF16Length + 1
        )
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

// MARK: - Cut size cap

/// `exceedsCutLimit` is pure, so the boundary is tested directly with small
/// caps; that it is wired into cut-all is covered by
/// `cutAllRefusesAnOversizedDocument` above.
struct AdvancedTextCutLimitTests {
    @Test func acceptsTextExactlyAtCap() {
        #expect(!AdvancedTextMiddleware.exceedsCutLimit("abc", maxUTF16Length: 3))
    }

    @Test func rejectsTextAboveCap() {
        #expect(AdvancedTextMiddleware.exceedsCutLimit("abcd", maxUTF16Length: 3))
    }

    @Test func countsUTF16UnitsNotCharacters() {
        // 👍🏽 = one Character, 4 UTF-16 units.
        #expect(AdvancedTextMiddleware.exceedsCutLimit("👍🏽", maxUTF16Length: 3))
        #expect(!AdvancedTextMiddleware.exceedsCutLimit("👍🏽", maxUTF16Length: 4))
    }

    @Test func cutAndPasteShareTheSameCeiling() {
        let atCap = String(repeating: "a", count: KeyboardConstants.TextInput.maxPasteUTF16Length)
        #expect(!AdvancedTextMiddleware.exceedsCutLimit(atCap))
        #expect(AdvancedTextMiddleware.exceedsCutLimit(atCap + "a"))
        #expect(AdvancedTextMiddleware.cappedForInsertion(atCap) == atCap)
    }
}
