//
//  ComposeRuleSet+Merge.swift
//  Wurstfinger
//
//  Merge logic for compose rule sets.
//

import Foundation

extension ComposeRuleSet {
    /// Merges this rule set with overrides.
    /// Override entries win on conflict; new triggers and entries are added.
    func merging(overrides: ComposeRuleSet) -> ComposeRuleSet {
        var merged = rules
        for (trigger, charMap) in overrides.rules {
            merged[trigger] = (merged[trigger] ?? [:]).merging(charMap) { _, override in override }
        }
        return ComposeRuleSet(rules: merged)
    }
}
