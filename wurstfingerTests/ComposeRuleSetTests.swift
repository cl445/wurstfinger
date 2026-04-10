//
//  ComposeRuleSetTests.swift
//  WurstfingerTests
//
//  Tests for ComposeRuleSet merging and ComposeEngine instance API.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - ComposeRuleSet Global

struct ComposeRuleSetGlobalTests {
    @Test func globalHasAllTriggers() {
        let triggers = ComposeRuleSet.global.rules.keys.sorted()
        #expect(triggers.count == 13)
        #expect(triggers.contains("¨"))
        #expect(triggers.contains("´"))
        #expect(triggers.contains("ˋ"))
        #expect(triggers.contains("^"))
        #expect(triggers.contains("~"))
        #expect(triggers.contains("°"))
        #expect(triggers.contains("˘"))
        #expect(triggers.contains("!"))
        #expect(triggers.contains("$"))
        #expect(triggers.contains("゛"))
        #expect(triggers.contains("?"))
        #expect(triggers.contains("*"))
        #expect(triggers.contains("ˇ"))
    }

    @Test func globalMatchesSharedEngine() {
        // Assert raw rule data so failures pinpoint data-table vs engine regression
        #expect(ComposeRuleSet.global.rules["¨"]?["a"] == "ä")
        #expect(ComposeRuleSet.global.rules["~"]?["n"] == "ñ")
        #expect(ComposeRuleSet.global.rules["$"]?["e"] == "€")
        // Verify that the shared engine produces the same results
        #expect(ComposeEngine.shared.compose(previous: "a", trigger: "¨") == "ä")
        #expect(ComposeEngine.shared.compose(previous: "n", trigger: "~") == "ñ")
        #expect(ComposeEngine.shared.compose(previous: "e", trigger: "$") == "€")
    }
}

// MARK: - ComposeRuleSet Merge

struct ComposeRuleSetMergeTests {
    @Test func overrideWinsOnConflict() {
        let base = ComposeRuleSet(rules: [
            "¨": ["a": "ä", "o": "ö"],
        ])
        let overrides = ComposeRuleSet(rules: [
            "¨": ["a": "X"],
        ])
        let merged = base.merging(overrides: overrides)
        #expect(merged.rules["¨"]?["a"] == "X")
    }

    @Test func baseEntriesPreserved() {
        let base = ComposeRuleSet(rules: [
            "¨": ["a": "ä", "o": "ö"],
        ])
        let overrides = ComposeRuleSet(rules: [
            "¨": ["a": "X"],
        ])
        let merged = base.merging(overrides: overrides)
        #expect(merged.rules["¨"]?["o"] == "ö")
    }

    @Test func newTriggerAdded() {
        let base = ComposeRuleSet(rules: [
            "¨": ["a": "ä"],
        ])
        let overrides = ComposeRuleSet(rules: [
            "NEW": ["x": "y"],
        ])
        let merged = base.merging(overrides: overrides)
        #expect(merged.rules["NEW"]?["x"] == "y")
        #expect(merged.rules["¨"]?["a"] == "ä")
    }

    @Test func newEntryAddedToExistingTrigger() {
        let base = ComposeRuleSet(rules: [
            "¨": ["a": "ä"],
        ])
        let overrides = ComposeRuleSet(rules: [
            "¨": ["z": "ẑ"],
        ])
        let merged = base.merging(overrides: overrides)
        #expect(merged.rules["¨"]?["a"] == "ä")
        #expect(merged.rules["¨"]?["z"] == "ẑ")
    }

    @Test func emptyOverridesReturnBase() {
        let base = ComposeRuleSet(rules: [
            "¨": ["a": "ä"],
        ])
        let merged = base.merging(overrides: ComposeRuleSet(rules: [:]))
        #expect(merged.rules == base.rules)
    }
}

// MARK: - ComposeEngine Instance API

struct ComposeEngineInstanceTests {
    @Test func instanceCompose() {
        let engine = ComposeEngine(ruleSet: ComposeRuleSet(rules: [
            "T": ["a": "X"],
        ]))
        #expect(engine.compose(previous: "a", trigger: "T") == "X")
        #expect(engine.compose(previous: "b", trigger: "T") == nil)
    }

    @Test func instanceCycleAccent() {
        let engine = ComposeEngine(ruleSet: ComposeRuleSet(rules: [
            "T": ["a": "á"],
        ]))
        #expect(engine.cycleAccent(for: "a") == "á")
        #expect(engine.cycleAccent(for: "á") == "a")
    }

    @Test func withGlobalRulesOverrides() {
        let engine = ComposeEngine.withGlobalRules(overrides: ComposeRuleSet(rules: [
            "¨": ["a": "CUSTOM"],
        ]))
        // Override wins
        #expect(engine.compose(previous: "a", trigger: "¨") == "CUSTOM")
        // Base rules still available
        #expect(engine.compose(previous: "o", trigger: "¨") == "ö")
        #expect(engine.compose(previous: "n", trigger: "~") == "ñ")
    }

    @Test func staticAPIMatchesShared() {
        // Static API should delegate to shared instance
        #expect(ComposeEngine.compose(previous: "a", trigger: "¨") == ComposeEngine.shared.compose(previous: "a", trigger: "¨"))
        #expect(ComposeEngine.cycleAccent(for: "a") == ComposeEngine.shared.cycleAccent(for: "a"))
    }
}
