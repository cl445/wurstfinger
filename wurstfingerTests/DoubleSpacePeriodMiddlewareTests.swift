//
//  DoubleSpacePeriodMiddlewareTests.swift
//  WurstfingerTests
//
//  Verifies the double-space → period substitution (the iOS "." Shortcut):
//  the rule, the isolated middleware behavior, and end-to-end wiring through
//  the action pipeline including the free auto-capitalization follow-up.
//

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

    /// Runs one action through the middleware, returning the forwarded action,
    /// the target's recorded events, and the resulting pre-cursor context.
    private func run(before: String?, enabled: Bool = true, action: KeyAction = .space)
        -> (forwarded: KeyAction, events: [MockTextTarget.Event], contextAfter: String?) {
        let target = MockTextTarget()
        target.documentContextBeforeInput = before
        let middleware = DoubleSpacePeriodMiddleware(
            isEnabled: { enabled },
            documentContextBefore: { target.documentContextBeforeInput },
            deleteBackward: { target.deleteBackward() }
        )
        var forwarded: KeyAction = .none
        middleware.process(ActionContext(action: action, binding: nil, mode: ModeNames.main)) { context in
            forwarded = context.action
        }
        return (forwarded, target.events, target.documentContextBeforeInput)
    }

    @Test("Deletes the pending space and rewrites to a period commit")
    func rewritesAfterLetter() {
        let result = run(before: "hello ")
        #expect(result.forwarded == .commitText(". "))
        #expect(result.events == [.deleteBackward])
        // The middleware only removes the pending space; the commit itself is
        // applied later by TextInputMiddleware.
        #expect(result.contextAfter == "hello")
    }

    @Test("Passes a space through untouched after punctuation")
    func passesThroughAfterPunctuation() {
        let result = run(before: "hello. ")
        #expect(result.forwarded == .space)
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello. ")
    }

    @Test("Passes a third space through untouched")
    func passesThroughOnDoubleSpace() {
        let result = run(before: "hello  ")
        #expect(result.forwarded == .space)
        #expect(result.events.isEmpty)
    }

    @Test("Does nothing when disabled")
    func inertWhenDisabled() {
        let result = run(before: "hello ", enabled: false)
        #expect(result.forwarded == .space)
        #expect(result.events.isEmpty)
        #expect(result.contextAfter == "hello ")
    }

    @Test("Ignores non-space actions")
    func ignoresNonSpaceActions() {
        let result = run(before: "hello ", action: .commitText("x"))
        #expect(result.forwarded == .commitText("x"))
        #expect(result.events.isEmpty)
    }

    // MARK: - Pipeline integration

    @Test("Enabled: a second space after a word yields a period + space")
    func integrationSubstitutes() {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.doubleSpacePeriodEnabled.rawValue)
        target.documentContextBeforeInput = "hi "
        viewModel.dispatchAction(.space)
        #expect(target.events == [.deleteBackward, .insertText(". ")])
        #expect(target.documentContextBeforeInput == "hi. ")
    }

    @Test("Disabled by default: a second space just inserts another space")
    func integrationDisabledByDefault() {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        target.documentContextBeforeInput = "hi "
        viewModel.dispatchAction(.space)
        #expect(target.events == [.insertText(" ")])
        #expect(target.documentContextBeforeInput == "hi  ")
    }

    @Test("Auto-capitalization engages after the inserted period")
    func integrationAutoCapitalizes() throws {
        let (viewModel, target) = makeViewModel(languageId: "de_DE")
        try #require(viewModel.currentDefinition?.settings.autoCapitalize == true)
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.doubleSpacePeriodEnabled.rawValue)
        viewModel.sharedDefaults.set(true, forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        target.documentContextBeforeInput = "hi "
        viewModel.dispatchAction(.space)
        #expect(target.documentContextBeforeInput == "hi. ")
        // ". " is a sentence boundary, so the shifted layer engages for the
        // next letter without any extra wiring in this middleware.
        #expect(viewModel.activeModeName == ModeNames.shifted)
    }
}
