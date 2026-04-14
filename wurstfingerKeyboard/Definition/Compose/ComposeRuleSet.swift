//
//  ComposeRuleSet.swift
//  Wurstfinger
//
//  A complete set of compose rules (trigger → base character → result).
//

import Foundation

/// A complete set of compose rules.
struct ComposeRuleSet: Codable, Equatable {
    /// trigger → (baseChar → result)
    /// e.g. "¨" → ["a": "ä", "o": "ö", ...]
    let rules: [String: [String: String]]
}
