//
//  SequentialCompositionSelectionTests.swift
//  WurstfingerTests
//
//  Verifies that sequential combine composition never corrupts an active
//  selection: when text is selected, the raw trigger must replace the
//  selection instead of being folded into a lookback character that is then
//  deleted (finding #5).
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct SequentialCompositionSelectionTests {
    /// End-to-end through the Korean (Hangul) pipeline: with "한" selected as
    /// "X" in front of the cursor, typing "ㅏ" must replace the selection with
    /// the raw jamo, not run the Hangul automaton over the lookback character.
    @Test func combineSkippedWhenSelectionActive_ko_KR() {
        let (vm, target) = makeViewModel(languageId: "ko_KR")
        target.documentContextBeforeInput = "한"
        target.documentContextAfterInput = ""
        target.selectedText = "X"

        vm.dispatchAction(.commitText("ㅏ"))

        #expect(target.documentContextBeforeInput == "한ㅏ")
        #expect(target.selectedText == nil)
        #expect(!target.events.contains(.deleteBackward))
    }

    /// Most-precise unit reproduction of #5: with a selection active the
    /// middleware must forward the original commit unchanged (no lookback
    /// delete), even though the combine closure would otherwise produce a
    /// syllable.
    @Test func combineMiddlewareForwardsRawTriggerOverSelection_direct() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "한" },
            deleteBackward: { deletes += 1 },
            selectedText: { "X" },
            composeDigraph: nil,
            composeSingle: { previous, trigger in
                HangulComposer.combine(previous: previous, jamo: trigger)
            }
        )
        let context = ActionContext(action: .commitText("ㅏ"), binding: nil, mode: "main")
        middleware.process(context) { transformed in
            captured = transformed.action
        }

        #expect(deletes == 0)
        #expect(captured == .commitText("ㅏ"))
    }

    /// Regression lock for the non-selection path: with no selection the
    /// combine still runs (한 + ㅏ → 하나), consuming the lookback character.
    @Test func combineRunsWhenNoSelection_direct() {
        var deletes = 0
        var captured: KeyAction?
        let middleware = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { "한" },
            deleteBackward: { deletes += 1 },
            selectedText: { nil },
            composeDigraph: nil,
            composeSingle: { previous, trigger in
                HangulComposer.combine(previous: previous, jamo: trigger)
            }
        )
        let context = ActionContext(action: .commitText("ㅏ"), binding: nil, mode: "main")
        middleware.process(context) { transformed in
            captured = transformed.action
        }

        #expect(deletes == 1)
        #expect(captured == .commitText("하나"))
    }
}
