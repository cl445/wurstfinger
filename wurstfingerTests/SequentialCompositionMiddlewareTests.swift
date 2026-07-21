//
//  SequentialCompositionMiddlewareTests.swift
//  WurstfingerTests
//
//  Seam tests for the unified SequentialCompositionMiddleware — the single
//  middleware that backs both Vietnamese Telex (two-char digraph + single
//  lookback) and sequential combine (single lookback: rule table or Hangul).
//  Locks the shared skeleton: isActive guard, single-char commit check,
//  selection skip, lookback read, and delete-then-rewrite for both flavours.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct SequentialCompositionMiddlewareTests {
    /// Runs `middleware` over a `.commitText(trigger)` context and returns the
    /// forwarded action plus the number of `deleteBackward` calls it made.
    private func run(
        _ middleware: SequentialCompositionMiddleware,
        trigger: String
    ) -> (action: KeyAction?, deletes: Int) {
        var captured: KeyAction?
        let context = ActionContext(action: .commitText(trigger), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        return (captured, 0)
    }

    // MARK: - Single-lookback (combine flavour)

    @Test func singleLookbackComposesAndDeletesOne() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "か" },
            deleteBackward: { deletes += 1 },
            composeDigraph: nil,
            composeSingle: { previous, trigger in
                previous == "か" && trigger == "゛" ? "が" : nil
            }
        )
        let context = ActionContext(action: .commitText("゛"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 1)
        #expect(captured == .commitText("が"))
    }

    @Test func singleLookbackForwardsWhenNoRuleMatches() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "x" },
            deleteBackward: { deletes += 1 },
            composeDigraph: nil,
            composeSingle: { _, _ in nil }
        )
        let context = ActionContext(action: .commitText("y"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 0)
        #expect(captured == .commitText("y"))
    }

    // MARK: - Digraph (Telex flavour)

    @Test func digraphTakesPrecedenceAndDeletesReportedCount() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "uo" },
            deleteBackward: { deletes += 1 },
            composeDigraph: { prev2, prev1, trigger in
                prev2 == "u" && prev1 == "o" && trigger == "w" ? ("ươ", 2) : nil
            },
            composeSingle: { _, _ in "SHOULD_NOT_BE_USED" }
        )
        let context = ActionContext(action: .commitText("w"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 2)
        #expect(captured == .commitText("ươ"))
    }

    @Test func fallsBackToSingleWhenDigraphMisses() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "ba" },
            deleteBackward: { deletes += 1 },
            composeDigraph: { _, _, _ in nil },
            composeSingle: { previous, trigger in
                previous == "a" && trigger == "s" ? "á" : nil
            }
        )
        let context = ActionContext(action: .commitText("s"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 1)
        #expect(captured == .commitText("á"))
    }

    // MARK: - Shared guards

    @Test func inertWhenNotActive() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { false },
            documentContextBefore: { "か" },
            deleteBackward: { deletes += 1 },
            composeDigraph: nil,
            composeSingle: { _, _ in "が" }
        )
        let context = ActionContext(action: .commitText("゛"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 0)
        #expect(captured == .commitText("゛"))
    }

    @Test func skippedWhenSelectionActive() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "か" },
            deleteBackward: { deletes += 1 },
            selectedText: { "SEL" },
            composeDigraph: nil,
            composeSingle: { _, _ in "が" }
        )
        let context = ActionContext(action: .commitText("゛"), binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(deletes == 0)
        #expect(captured == .commitText("゛"))
    }

    @Test func ignoresMultiCharacterCommits() {
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "か" },
            deleteBackward: {},
            composeDigraph: nil,
            composeSingle: { _, _ in "SHOULD_NOT_RUN" }
        )
        let result = run(middleware, trigger: "ab")
        #expect(result.action == .commitText("ab"))
    }

    @Test func forwardsWhenNoLookbackContext() {
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "" },
            deleteBackward: {},
            composeDigraph: nil,
            composeSingle: { _, _ in "SHOULD_NOT_RUN" }
        )
        let result = run(middleware, trigger: "y")
        #expect(result.action == .commitText("y"))
    }

    @Test func ignoresNonCommitActions() {
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "か" },
            deleteBackward: {},
            composeDigraph: nil,
            composeSingle: { _, _ in "SHOULD_NOT_RUN" }
        )
        var captured: KeyAction?
        let context = ActionContext(action: .deleteBackward, binding: nil, mode: "main")
        middleware.process(context) { captured = $0.action }
        #expect(captured == .deleteBackward)
    }
}

// MARK: - Definition-layer combiner resolution (refactor b)

struct SequentialCombinerResolutionTests {
    private func settings(
        inputMethod: InputMethodKind = .direct,
        combineRuleSet: ComposeRuleSet? = nil
    ) -> KeyboardDefinitionSettings {
        KeyboardDefinitionSettings(
            autoCapitalize: false,
            composeRuleOverrides: nil,
            inputMethod: inputMethod,
            combineRuleSet: combineRuleSet
        )
    }

    @Test func noCombinerForPlainDirectLayout() {
        #expect(settings().sequentialCombiner == nil)
    }

    @Test func noCombinerForTelexSingleLookback() {
        // Telex composes via the digraph/single Telex closures, not this
        // single-lookback combiner.
        #expect(settings(inputMethod: .telex).sequentialCombiner == nil)
    }

    @Test func ruleSetCombinerLooksUpTriggerThenBase() {
        let ruleSet = ComposeRuleSet(rules: ["゛": ["か": "が", "さ": "ざ"]])
        let combiner = settings(combineRuleSet: ruleSet).sequentialCombiner
        #expect(combiner != nil)
        #expect(combiner?("か", "゛") == "が")
        #expect(combiner?("さ", "゛") == "ざ")
        #expect(combiner?("x", "゛") == nil)
    }

    @Test func hangulResolvesToAutomaton() {
        let combiner = settings(inputMethod: .hangul).sequentialCombiner
        #expect(combiner != nil)
        // Lead + vowel → syllable, straight from HangulComposer.
        #expect(combiner?("ㅎ", "ㅏ") == "하")
        #expect(combiner?("한", "ㅏ") == "하나")
    }
}
