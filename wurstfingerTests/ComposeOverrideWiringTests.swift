//
//  ComposeOverrideWiringTests.swift
//  WurstfingerTests
//
//  End-to-end tests for language-specific compose rule overrides:
//  factory → definition settings → pipeline → ComposeMiddleware.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// Builds a view model whose loaded definition comes from
/// `GridKeyboardFactory.layout` with the given compose rule overrides.
private func makeOverrideViewModel(
    composeRuleOverrides: ComposeRuleSet?
) -> (KeyboardViewModel, MockTextTarget) {
    let vm = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)
    let target = MockTextTarget()
    vm.bindTextInputTarget(target)
    let definition = GridKeyboardFactory.layout(
        id: "test_compose_overrides",
        title: "Test Compose Overrides",
        localeIdentifier: "de_DE",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "d", "r"],
            ["t", "e", "s"],
        ],
        composeRuleOverrides: composeRuleOverrides
    )
    vm.currentDefinition = definition
    vm.activeModeName = definition.defaultMode
    vm.currentMode = definition.mode(definition.defaultMode)
    vm.rebuildResolverChain()
    vm.rebuildPipeline()
    return (vm, target)
}

@Suite(.serialized)
struct ComposeOverrideWiringTests {
    private let overrides = ComposeRuleSet(rules: [
        "¨": ["a": "ǟ"],
    ])

    @Test func factoryPassesOverridesIntoSettings() {
        let definition = GridKeyboardFactory.layout(
            id: "test_compose_overrides",
            title: "Test Compose Overrides",
            localeIdentifier: "de_DE",
            centerCharacters: [
                ["a", "n", "i"],
                ["h", "d", "r"],
                ["t", "e", "s"],
            ],
            composeRuleOverrides: overrides
        )
        #expect(definition.settings.composeRuleOverrides == overrides)
    }

    @Test func factoryDefaultsOverridesToNil() {
        let definition = GridKeyboardFactory.layout(
            id: "test_compose_overrides",
            title: "Test Compose Overrides",
            localeIdentifier: "de_DE",
            centerCharacters: [
                ["a", "n", "i"],
                ["h", "d", "r"],
                ["t", "e", "s"],
            ]
        )
        #expect(definition.settings.composeRuleOverrides == nil)
    }

    @Test func overrideWinsOverGlobalRuleThroughPipeline() {
        let (vm, target) = makeOverrideViewModel(composeRuleOverrides: overrides)
        target.documentContextBeforeInput = "a"
        // Global rule is ¨ + a → ä; the override replaces it with ǟ.
        vm.dispatchAction(.compose(trigger: "¨"))
        #expect(target.events == [.deleteBackward, .insertText("ǟ")])
    }

    @Test func globalRulesStillApplyForUnoverriddenBases() {
        let (vm, target) = makeOverrideViewModel(composeRuleOverrides: overrides)
        target.documentContextBeforeInput = "o"
        // "o" is not overridden — the global rule ¨ + o → ö must still fire.
        vm.dispatchAction(.compose(trigger: "¨"))
        #expect(target.events == [.deleteBackward, .insertText("ö")])
    }

    @Test func definitionWithoutOverridesUsesGlobalRules() {
        let (vm, target) = makeOverrideViewModel(composeRuleOverrides: nil)
        target.documentContextBeforeInput = "a"
        vm.dispatchAction(.compose(trigger: "¨"))
        #expect(target.events == [.deleteBackward, .insertText("ä")])
    }

    @Test func loadingDefinitionWithoutOverridesRebuildsGlobalEngine() {
        // Start with an override-carrying definition, then load a shipped
        // language: the pipeline must fall back to the shared global engine.
        let (vm, target) = makeOverrideViewModel(composeRuleOverrides: overrides)
        vm.loadDefinition(for: "de_DE")
        target.documentContextBeforeInput = "a"
        vm.dispatchAction(.compose(trigger: "¨"))
        #expect(target.events == [.deleteBackward, .insertText("ä")])
    }
}
