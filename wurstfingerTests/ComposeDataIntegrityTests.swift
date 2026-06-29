//
//  ComposeDataIntegrityTests.swift
//  WurstfingerTests
//
//  Data-integrity checks for the compose rules: every rule is well-formed,
//  the engine resolves every rule consistently, and every compose trigger
//  used by a layout actually has rules.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct ComposeDataIntegrityTests {
    private let rules = ComposeRuleSet.global.rules

    @Test func everyRuleIsWellFormed() {
        for (trigger, map) in rules {
            #expect(!trigger.isEmpty, "Empty compose trigger key")
            #expect(!map.isEmpty, "Trigger '\(trigger)' has no entries")
            for (previous, result) in map {
                #expect(!previous.isEmpty, "Trigger '\(trigger)' has an empty previous-character key")
                #expect(!result.isEmpty, "Rule \(trigger)+\(previous) → empty result")
                #expect(
                    result.count == 1,
                    "Rule \(trigger)+\(previous) → '\(result)' is not a single grapheme"
                )
            }
        }
    }

    @Test func engineResolvesEveryRuleConsistently() {
        for (trigger, map) in rules {
            for (previous, result) in map {
                #expect(
                    ComposeEngine.shared.compose(previous: previous, trigger: trigger) == result,
                    "Engine disagrees with data for \(trigger)+\(previous): expected '\(result)'"
                )
            }
        }
    }

    @Test func everyLayoutComposeTriggerHasRules() {
        var triggers = Set<String>()
        for info in KeyboardRegistry.available {
            guard let def = KeyboardRegistry.load(id: info.id) else { continue }
            for (_, mode) in def.modes {
                for (_, key) in mode.keys {
                    for (_, binding) in key.bindings {
                        if case let .compose(trigger) = binding.action {
                            triggers.insert(trigger)
                        }
                        if case let .compose(trigger)? = binding.returnAction {
                            triggers.insert(trigger)
                        }
                    }
                }
            }
        }

        #expect(!triggers.isEmpty, "Expected layouts to use compose triggers")
        for trigger in triggers {
            #expect(
                rules[trigger] != nil,
                "Layout uses compose trigger '\(trigger)' but ComposeRuleSet.global has no rules for it"
            )
        }
    }
}
