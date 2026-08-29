//
//  DoubleSpacePeriodMiddlewareTests.swift
//  WurstfingerTests
//
//  Verifies the double-space → sentence terminator substitution (the iOS "."
//  Shortcut): the rule, the timing window, the per-script terminator, and
//  end-to-end wiring through the action pipeline including the free
//  auto-capitalization follow-up.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct DoubleSpacePeriodMiddlewareTests {
    // MARK: - Rule

    @Test("Substitution rule matches letter/digit + single trailing space", arguments: [
        ("hello ", true), // letter before the pending space
        ("a ", true), // single letter is enough
        ("5 ", true), // digit before the pending space
        ("hello. ", false), // preceding char is punctuation
        ("hello  ", false), // two spaces: preceding char is a space
        ("hello", false), // no trailing space
        (" ", false), // leading space only: no preceding character
        ("", false), // empty field
        ("hello.", false), // ends in punctuation, no space
    ])
    func rule(_ context: String, _ expected: Bool) {
        #expect(DoubleSpacePeriodMiddleware.shouldSubstitute(before: context) == expected)
    }

    // MARK: - Isolated middleware

    /// Drives one middleware instance through a timeline of `(time, action)`
    /// pairs on an injected clock, returning every forwarded action, the
    /// target's recorded events, and the resulting pre-cursor context.
    /// The default timeline is two space presses well inside the window.
    private func run(
        before: String?,
        timeline: [(TimeInterval, KeyAction)] = [(0, .space), (0.2, .space)],
        enabled: Bool = true,
        selection: String? = nil,
        terminator: String = ". "
    )
        -> (forwarded: [KeyAction], events: [MockTextTarget.Event], contextAfter: String?) {
        let target = MockTextTarget()
        target.documentContextBeforeInput = before
        target.selectedText = selection
        var clock: TimeInterval = 0
        let middleware = DoubleSpacePeriodMiddleware(
            isEnabled: { enabled },
            documentContextBefore: { target.documentContextBeforeInput },
            selectedText: { target.selectedText },
            deleteBackward: { target.deleteBackward() },
            sentenceTerminator: terminator,
            now: { clock }
        )
        var forwarded: [KeyAction] = []
        for (time, action) in timeline {
            clock = time
            middleware.process(ActionContext(action: action, binding: nil, mode: ModeNames.main)) { context in
                forwarded.append(context.action)
            }
        }
        return (forwarded, target.events, target.documentContextBeforeInput)
    }

    @Test("Deletes the pending space and rewrites to a terminator commit")
    func rewritesAfterLetter() {
        let result = run(before: "hello ")
        #expect(result.forwarded == [.space, .commitText(". ")])
        #expect(result.events == [.deleteBackward])
        // The middleware only removes the pending space; the commit itself is
        // applied later by TextInputMiddleware.
        #expect(result.contextAfter == "hello")
    }

    @Test("Passes a space through untouched after punctuation")
    func passesThroughAfterPunctuation() {
        let result = run(before: "hello. ")
        #expect(result.forwarded == [.space, .space])
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello. ")
    }

    @Test("Passes a space through untouched while text is selected")
    func passesThroughWithActiveSelection() {
        // With a selection, `deleteBackward` would delete the selected text
        // instead of the pending space, so the space must keep its plain
        // replace-selection semantics even when the pre-selection context
        // matches the substitution rule.
        let result = run(before: "hello ", selection: "world")
        #expect(result.forwarded == [.space, .space])
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello ")
    }

    @Test("Passes a third space through untouched")
    func passesThroughOnDoubleSpace() {
        let result = run(before: "hello  ")
        #expect(result.forwarded == [.space, .space])
        #expect(result.events.isEmpty)
    }

    @Test("Does nothing when disabled")
    func inertWhenDisabled() {
        let result = run(before: "hello ", enabled: false)
        #expect(result.forwarded == [.space, .space])
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello ")
    }

    @Test("Ignores non-space actions")
    func ignoresNonSpaceActions() {
        let result = run(before: "hello ", timeline: [(0, .commitText("x"))])
        #expect(result.forwarded == [.commitText("x")])
        #expect(result.events.isEmpty)
    }

    // MARK: - Timing window

    @Test("A lone space is never a double space")
    func loneSpaceDoesNotSubstitute() {
        // The rule alone matches "hello " — only the missing first press keeps
        // a space typed into an already-finished word from being rewritten.
        let result = run(before: "hello ", timeline: [(0, .space)])
        #expect(result.forwarded == [.space])
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello ")
    }

    @Test("A space after the window has closed inserts a plain space")
    func windowExpires() {
        let window = KeyboardConstants.TextInput.doubleSpacePeriodWindow
        let result = run(before: "hello ", timeline: [(0, .space), (window + 0.01, .space)])
        #expect(result.forwarded == [.space, .space])
        #expect(result.events.isEmpty)
    }

    @Test("A space at the edge of the window still substitutes")
    func windowBoundarySubstitutes() {
        let window = KeyboardConstants.TextInput.doubleSpacePeriodWindow
        let result = run(before: "hello ", timeline: [(0, .space), (window, .space)])
        #expect(result.forwarded.last == .commitText(". "))
    }

    @Test("A keystroke between the two spaces disarms the window")
    func interveningActionDisarms() {
        let result = run(
            before: "hello ",
            timeline: [(0, .space), (0.1, .commitText("x")), (0.2, .space)]
        )
        #expect(result.forwarded == [.space, .commitText("x"), .space])
        #expect(result.events.isEmpty)
    }

    @Test("A cursor move between the two spaces disarms the window")
    func cursorMoveDisarms() {
        let result = run(
            before: "hello ",
            timeline: [(0, .space), (0.1, .moveCursor(offset: -1)), (0.2, .space)]
        )
        #expect(result.forwarded.last == .space)
        #expect(result.events.isEmpty)
    }

    @Test("A consumed pair does not arm the next space")
    func thirdSpaceStartsAFreshPair() {
        // "hello" + space + space substitutes; the third space must insert a
        // plain space rather than substituting again on its own.
        let result = run(
            before: "hello ",
            timeline: [(0, .space), (0.2, .space), (0.4, .space)]
        )
        #expect(result.forwarded == [.space, .commitText(". "), .space])
        #expect(result.events == [.deleteBackward])
    }

    // MARK: - Per-script terminator

    @Test("Commits the sentence terminator the definition supplies", arguments: [
        ("hello ", ". "),
        ("क ", "। "),
        ("س ", "۔ "),
        ("あ ", "。"),
    ])
    func commitsScriptTerminator(_ before: String, _ terminator: String) {
        let result = run(before: before, terminator: terminator)
        #expect(result.forwarded.last == .commitText(terminator))
        #expect(result.events == [.deleteBackward])
    }

    // MARK: - Pipeline integration

    @Test("Enabled: a second space after a word yields a period + space")
    func integrationSubstitutes() {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.doubleSpacePeriodEnabled.rawValue)
        target.documentContextBeforeInput = "hi"
        viewModel.dispatchAction(.space)
        viewModel.dispatchAction(.space)
        #expect(target.events == [.insertText(" "), .deleteBackward, .insertText(". ")])
        #expect(target.documentContextBeforeInput == "hi. ")
    }

    @Test("Disabled by default: two spaces just insert two spaces")
    func integrationDisabledByDefault() {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "hi"
        viewModel.dispatchAction(.space)
        viewModel.dispatchAction(.space)
        #expect(target.events == [.insertText(" "), .insertText(" ")])
        #expect(target.documentContextBeforeInput == "hi  ")
    }

    @Test("Auto-capitalization engages after the inserted period")
    func integrationAutoCapitalizes() throws {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        try #require(viewModel.currentDefinition?.settings.autoCapitalize == true)
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.doubleSpacePeriodEnabled.rawValue)
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        target.documentContextBeforeInput = "hi"
        viewModel.dispatchAction(.space)
        viewModel.dispatchAction(.space)
        #expect(target.documentContextBeforeInput == "hi. ")
        // ". " is a sentence boundary, so the shifted mode engages for the
        // next letter without any extra wiring in this middleware.
        #expect(viewModel.activeModeName == ModeNames.shifted)
    }

    @Test("Hindi commits a danda instead of a period")
    func integrationHindiDanda() {
        let (viewModel, target) = makeViewModel(languageId: "hi_IN")
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.doubleSpacePeriodEnabled.rawValue)
        target.documentContextBeforeInput = "क"
        viewModel.dispatchAction(.space)
        viewModel.dispatchAction(.space)
        #expect(target.documentContextBeforeInput == "क। ")
    }
}
