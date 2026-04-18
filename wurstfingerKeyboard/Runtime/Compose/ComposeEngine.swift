//
//  ComposeEngine.swift
//  Wurstfinger
//
//  Compose engine for character composition and accent cycling.
//

import Foundation

struct ComposeEngine {
    let ruleSet: ComposeRuleSet
    private let accentCycles: [String: [String]]

    init(ruleSet: ComposeRuleSet) {
        self.ruleSet = ruleSet
        accentCycles = Self.buildAccentCycles(from: ruleSet)
    }

    /// Shared instance using global compose rules.
    static let shared = ComposeEngine(ruleSet: .global)

    /// Creates an engine with global rules merged with language-specific overrides.
    static func withGlobalRules(overrides: ComposeRuleSet) -> ComposeEngine {
        ComposeEngine(ruleSet: ComposeRuleSet.global.merging(overrides: overrides))
    }

    // MARK: - Instance Methods

    func compose(previous: String, trigger: String) -> String? {
        guard let mapping = ruleSet.rules[trigger],
              let replacement = mapping[previous]
        else {
            return nil
        }
        return replacement
    }

    func cycleAccent(for character: String) -> String? {
        guard let cycle = accentCycles[character],
              let currentIndex = cycle.firstIndex(of: character)
        else {
            return nil
        }
        let nextIndex = (currentIndex + 1) % cycle.count
        return cycle[nextIndex]
    }

    // MARK: - Static API (backward compatibility)

    static func compose(previous: String, trigger: String) -> String? {
        shared.compose(previous: previous, trigger: trigger)
    }

    static func cycleAccent(for character: String) -> String? {
        shared.cycleAccent(for: character)
    }

    // MARK: - Accent Cycle Builder

    /// Number cycles (not language-specific).
    private static let numberCycles: [String: [String]] = [
        "0": ["0", "⁰"],
        "1": ["1", "¹", "½", "⅓", "¼", "⅕", "⅙", "⅐", "⅛", "⅑", "⅒"],
        "2": ["2", "²", "⅔", "⅖"],
        "3": ["3", "³", "¾", "⅜", "⅗"],
        "4": ["4", "⁴", "⅘"],
        "5": ["5", "⁵", "⅚", "⅝"],
        "6": ["6", "⁶"],
        "7": ["7", "⁷", "⅞"],
        "8": ["8", "⁸"],
        "9": ["9", "⁹"],
    ]

    private static func buildAccentCycles(from ruleSet: ComposeRuleSet) -> [String: [String]] {
        var cycles: [String: [String]] = [:]

        // Build reverse mapping: character → all its accented variants
        // Sort by key for deterministic iteration order across runs
        for (_, charMap) in ruleSet.rules.sorted(by: { $0.key < $1.key }) {
            for (base, accented) in charMap.sorted(by: { $0.key < $1.key }) {
                // Skip non-cycling entries: space fallbacks (" " → trigger char)
                // and multi-character bases (already-composed forms like "â" → "ấ")
                if base == " " || base.count > 1 { continue }

                // Add base → accented mapping
                if cycles[base] == nil {
                    cycles[base] = []
                }
                if !cycles[base]!.contains(accented) {
                    cycles[base]!.append(accented)
                }

                // Add reverse: accented → base (for cycling back)
                if cycles[accented] == nil {
                    cycles[accented] = []
                }
            }
        }

        // Build complete cycles: base → [base, variant1, variant2, ...]
        // Characters like "â" can be both a variant of "a" and a base for
        // Vietnamese sub-variants. The first assignment wins so that cycling
        // from "a" through its variants always round-trips back to "a".
        var completeCycles: [String: [String]] = [:]
        for (base, variants) in cycles.sorted(by: { $0.key < $1.key }) where !variants.isEmpty {
            let cycle = [base] + variants
            if completeCycles[base] == nil {
                completeCycles[base] = cycle
            }

            // Each variant also maps to the same cycle (first assignment wins)
            for variant in variants where completeCycles[variant] == nil {
                completeCycles[variant] = cycle
            }
        }

        // Add number cycles: digit → superscript → fractions
        for (base, cycle) in numberCycles.sorted(by: { $0.key < $1.key }) {
            if completeCycles[base] == nil {
                completeCycles[base] = cycle
            }
            for variant in cycle where variant != base {
                if completeCycles[variant] == nil {
                    completeCycles[variant] = cycle
                }
            }
        }

        return completeCycles
    }

    // MARK: - Vietnamese Telex

    private static let telexVowelMap: [String: [String: String]] = [
        "a": ["a": "â"],
        "w": ["a": "ă", "o": "ơ", "u": "ư"],
        "d": ["d": "đ"],
        "e": ["e": "ê"],
        "o": ["o": "ô"]
    ]

    private static let telexVowelReverseMap: [String: (base: String, trigger: String)] = [
        "â": ("a", "a"), "ă": ("a", "w"), "ê": ("e", "e"),
        "ô": ("o", "o"), "ơ": ("o", "w"), "ư": ("u", "w"), "đ": ("d", "d")
    ]

    private static let telexToneMap: [String: String] = [
        "s": "´",
        "f": "ˋ",
        "r": "?",
        "x": "~",
        "j": "*"
    ]

    private static let vietnameseBaseVowels: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y"
    ]

    /// Reverse tone map built from the global compose rules: toned char -> (base, telex trigger).
    /// Includes both lowercase and uppercase entries so the caller can pass original case.
    private static let telexToneReverseMap: [String: (base: String, trigger: String)] = {
        let vowels: Set = [
            "a", "A", "ă", "Ă", "â", "Â",
            "e", "E", "ê", "Ê",
            "i", "I",
            "o", "O", "ô", "Ô", "ơ", "Ơ",
            "u", "U", "ư", "Ư",
            "y", "Y"
        ]
        let reverseTelex: [String: String] = [
            "´": "s", "ˋ": "f", "?": "r", "~": "x", "*": "j"
        ]
        var result: [String: (base: String, trigger: String)] = [:]
        for (composeTrigger, telexKey) in reverseTelex {
            guard let charMap = ComposeRuleSet.global.rules[composeTrigger] else { continue }
            for (base, toned) in charMap where vowels.contains(base) {
                result[toned] = (base: base, trigger: telexKey)
            }
        }
        return result
    }()

    private static let telexDigraphMap: [String: [String: String]] = [
        "w": ["uo": "ươ"]
    ]

    private static let telexDigraphReverseMap: [String: (original: String, trigger: String)] = [
        "ươ": ("uo", "w")
    ]

    /// Telex digraph composition (2-char lookback).
    /// Returns (replacement, charsToDelete) or nil.
    static func composeTelexDigraph(prev2: String, prev1: String, trigger: String) -> (String, Int)? {
        let lt = trigger.lowercased()
        let lp2 = prev2.lowercased()
        let lp1 = prev1.lowercased()
        let digraph = lp2 + lp1
        let isUpper2 = prev2 != lp2
        let isUpper1 = prev1 != lp1

        // Undo digraph: ươ+w -> "uo"
        if let (original, originalTrigger) = telexDigraphReverseMap[digraph],
           originalTrigger == lt {
            let chars = Array(original)
            let c0 = isUpper2 ? String(chars[0]).uppercased() : String(chars[0])
            let c1 = isUpper1 ? String(chars[1]).uppercased() : String(chars[1])
            return (c0 + c1, 2)
        }

        // Compose digraph: uo+w -> ươ
        if let result = telexDigraphMap[lt]?[digraph] {
            let chars = Array(result)
            let c0 = isUpper2 ? String(chars[0]).uppercased() : String(chars[0])
            let c1 = isUpper1 ? String(chars[1]).uppercased() : String(chars[1])
            return (c0 + c1, 2)
        }

        return nil
    }

    /// Single-char Telex compose. Priority:
    /// 1. Undo vowel mod  2. Undo/replace tone  3. Compose vowel mod
    /// 4. Compose tone mark  5. Remove tone (z)
    static func composeTelex(previous: String, trigger: String) -> String? {
        let lt = trigger.lowercased()
        let lp = previous.lowercased()
        let isUpperPrev = previous != lp

        // 1. Undo vowel modification: ô+o -> "oo", ă+w -> "aw", đ+d -> "dd"
        if let (base, origTrigger) = telexVowelReverseMap[lp],
           origTrigger == lt {
            let casedBase = isUpperPrev ? base.uppercased() : base
            return casedBase + trigger
        }

        // 2 & 3. Previous character already has a tone mark
        if let (base, origTelex) = telexToneReverseMap[previous] {
            if let composeTrigger = telexToneMap[lt] {
                if origTelex == lt {
                    // 2. Same tone → undo: á+s -> "as", ấ+s -> "âs"
                    return base + trigger
                } else {
                    // 3. Different tone → replace: á+f -> à
                    return compose(previous: base, trigger: composeTrigger)
                }
            }
            // 5. Remove tone (z) on already-toned char: á+z -> a, ấ+z -> â
            if lt == "z" {
                return base
            }
        }

        // 4. Compose vowel modification: a+a -> â, o+w -> ơ, d+d -> đ
        if let result = telexVowelMap[lt]?[lp] {
            return isUpperPrev ? result.uppercased() : result
        }

        // 5. Compose tone mark on vowel: a+s -> á, â+j -> ậ
        if let composeTrigger = telexToneMap[lt],
           vietnameseBaseVowels.contains(lp) {
            return compose(previous: previous, trigger: composeTrigger)
        }

        return nil
    }
}
