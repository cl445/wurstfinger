//  ComposeEngine.swift
//  Wurstfinger
//
//  Generated from Thumb-Key compose rules.
//

import Foundation

struct ComposeEngine {
    private static let composeMap: [String: [String: String]] = [
        "¨": [
            "a": "ä", "A": "Ä", "e": "ë", "E": "Ë", "h": "ḧ", "H": "Ḧ",
            "i": "ï", "I": "Ï", "o": "ö", "O": "Ö", "t": "ẗ", "u": "ü",
            "U": "Ü", "w": "ẅ", "W": "Ẅ", "x": "ẍ", "X": "Ẍ", "y": "ÿ",
            "Y": "Ÿ", " ": "¨", "'": "\"", "υ": "ϋ", "ύ": "ΰ",
            "Υ": "Ϋ", "ι": "ϊ", "ί": "ΐ", "Ι": "Ϊ"
        ],
        "´": [
            "a": "á", "A": "Á", "â": "ấ", "Â": "Ấ", "ă": "ắ", "Ă": "Ắ",
            "c": "ć", "C": "Ć", "e": "é", "E": "É", "ê": "ế", "Ê": "Ế",
            "g": "ǵ", "G": "Ǵ", "i": "í", "I": "Í", "j": "j́", "J": "J́",
            "k": "ḱ", "K": "Ḱ", "l": "ĺ", "L": "Ĺ", "m": "ḿ", "M": "Ḿ",
            "n": "ń", "N": "Ń", "o": "ó", "O": "Ó", "ô": "ố", "Ô": "Ố",
            "ơ": "ớ", "Ơ": "Ớ", "p": "ṕ", "P": "Ṕ", "r": "ŕ", "R": "Ŕ",
            "s": "ś", "S": "Ś", "u": "ú", "U": "Ú", "ư": "ứ", "Ư": "Ứ",
            "w": "ẃ", "W": "Ẃ", "y": "ý", "Y": "Ý", "z": "ź", "Z": "Ź",
            "'": "”", " ": "'", "\"": "'", "α": "ά", "Α": "Ά", "ε": "έ",
            "Ε": "Έ", "η": "ή", "Η": "Ή", "ι": "ί", "ϊ": "ΐ", "Ι": "Ί",
            "ο": "ό", "Ο": "Ό", "υ": "ύ", "ϋ": "ΰ", "ω": "ώ", "Ω": "Ώ"
        ],
        "ˋ": [
            "a": "à", "A": "À", "â": "ầ", "Â": "Ầ", "ă": "ằ", "Ă": "Ằ",
            "e": "è", "E": "È", "ê": "ề", "Ê": "Ề", "i": "ì", "I": "Ì",
            "n": "ǹ", "N": "Ǹ", "o": "ò", "O": "Ò", "ô": "ồ", "Ô": "Ồ",
            "ơ": "ờ", "Ờ": "Ờ", "u": "ù", "U": "Ù", "ư": "ừ", "Ư": "Ừ",
            "ü": "ǜ", "Ü": "Ǜ", "w": "ẁ", "W": "Ẁ", "y": "ỳ", "Y": "Ỳ",
            "`": " “", " ": "`", "α": "ά", "Α": "Ά", "ε": "έ", "Ε": "Έ",
            "η": "ή", "Η": "Ή", "ι": "ί", "ϊ": "ΐ", "Ι": "Ί", "ο": "ό",
            "Ο": "Ό", "υ": "ύ", "ϋ": "ΰ", "ω": "ώ", "Ω": "Ώ"
        ],
        "^": [
            "a": "â", "A": "Â", "c": "ĉ", "C": "Ĉ", "e": "ê", "E": "Ê",
            "g": "ĝ", "G": "Ĝ", "h": "ĥ", "H": "Ĥ", "i": "î", "I": "Î",
            "j": "ĵ", "J": "Ĵ", "o": "ô", "O": "Ô", "s": "ŝ", "S": "Ŝ",
            "u": "û", "U": "Û", "w": "ŵ", "W": "Ŵ", "y": "ŷ", "Y": "Ŷ",
            "z": "ẑ", "Z": "Ẑ", " ": "^"
        ],
        "~": [
            "a": "ã", "A": "Ã", "â": "ẫ", "Â": "Ẫ", "ă": "ẵ", "Ă": "Ẵ",
            "c": "ç", "C": "Ç", "e": "ẽ", "E": "Ẽ", "ê": "ễ", "Ê": "Ễ",
            "i": "ĩ", "I": "Ĩ", "n": "ñ", "N": "Ñ", "o": "õ", "O": "Õ",
            "ô": "ỗ", "Ô": "Ỗ", "ơ": "ỡ", "Ơ": "Ỡ", "u": "ũ", "U": "Ũ",
            "ư": "ữ", "Ư": "Ữ", "v": "ṽ", "V": "Ṽ", "y": "ỹ", "Y": "Ỹ",
            " ": "~"
        ],
        "°": [
            "a": "å", "A": "Å", "o": "ø", "O": "Ø", "u": "ů", "U": "Ů",
            " ": "°"
        ],
        "˘": [
            "a": "ă",
            "A": "Ă",
            "e": "ĕ",
            "E": "Ĕ",
            "g": "ğ",
            "G": "Ğ",
            "i": "ĭ",
            "I": "Ĭ",
            "o": "ŏ",
            "O": "Ŏ",
            "u": "ŭ",
            "U": "Ŭ",
            " ": "˘"
        ],
        "!": [
            "a": "æ", "A": "Æ", "æ": "ą", "Æ": "Ą", "c": "ç", "C": "Ç",
            "e": "ę", "E": "Ę", "l": "ł", "L": "Ł", "o": "œ", "O": "Œ",
            "s": "ß", "S": "ẞ", "z": "ż", "Z": "Ż", "!": "¡", "?": "¿",
            "`": " “", "´": "”", "\"": " “", "'": "”", "<": "«", ">": "»",
            " ": "!"
        ],
        "$": [
            "c": "¢", "C": "¢", "e": "€", "E": "€", "f": "₣", "F": "₣",
            "l": "£", "L": "£", "y": "¥", "Y": "¥", "w": "₩", "W": "₩",
            " ": "$"
        ],
        "゛": [
            "あ": "ぁ", "い": "ぃ", "う": "ぅ", "え": "ぇ", "お": "ぉ", "ぅ": "ゔ",
            "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご", "が": "ゕ",
            "げ": "ゖ", "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
            "た": "だ", "ち": "ぢ", "つ": "づ", "て": "で", "と": "ど", "づ": "っ",
            "は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ", "ば": "ぱ",
            "び": "ぴ", "ぶ": "ぷ", "べ": "ぺ", "ぼ": "ぽ", "や": "ゃ", "ゆ": "ゅ",
            "よ": "ょ", "わ": "ゎ", "ゝ": "ゞ", "ア": "ァ", "イ": "ィ", "ウ": "ゥ",
            "エ": "ェ", "オ": "ォ", "ゥ": "ヴ", "カ": "ガ", "キ": "ギ", "ク": "グ",
            "ケ": "ゲ", "コ": "ゴ", "ガ": "ヵ", "ゲ": "ヶ", "サ": "ザ", "シ": "ジ",
            "ス": "ズ", "セ": "ゼ", "ソ": "ゾ", "タ": "ダ", "チ": "ヂ", "ツ": "ヅ",
            "テ": "デ", "ト": "ド", "ヅ": "ッ", "ハ": "バ", "ヒ": "ビ", "フ": "ブ",
            "ヘ": "ベ", "ホ": "ボ", "バ": "パ", "ビ": "ピ", "ブ": "プ", "ベ": "ペ",
            "ボ": "ポ", "ヤ": "ャ", "ユ": "ュ", "ヨ": "ョ", "ワ": "ヷ",
            "ヰ": "ヸ", "ヱ": "ヹ", "ヲ": "ヺ", "ヷ": "ヮ", "ヽ": "ヾ"
        ],
        "?": [
            "a": "ả", "A": "Ả", "â": "ẩ", "Â": "Ẩ", "ă": "ẳ", "Ă": "Ẳ",
            "o": "ỏ", "O": "Ỏ", "ô": "ổ", "Ô": "Ổ", "ơ": "ở", "Ơ": "Ở",
            "u": "ủ", "U": "Ủ", "ư": "ử", "Ư": "Ử", "i": "ỉ", "I": "Ỉ",
            "e": "ẻ", "E": "Ẻ", "ê": "ể", "Ê": "Ể", "y": "ỷ", "Y": "Ỷ",
            " ": "?"
        ],
        "*": [
            "a": "ạ", "A": "Ạ", "â": "ậ", "Â": "Ậ", "ă": "ặ", "Ă": "Ặ",
            "o": "ọ", "O": "Ọ", "ô": "ộ", "Ô": "Ộ", "ơ": "ợ", "Ơ": "Ợ",
            "u": "ụ", "U": "Ụ", "ư": "ự", "Ư": "Ự", "i": "ị", "I": "Ị",
            "e": "ẹ", "E": "Ẹ", "ê": "ệ", "Ê": "Ệ", "y": "ỵ", "Y": "Ỵ",
            " ": "*"
        ],
        "ˇ": [
            "c": "č", "d": "ď", "e": "ě", "l": "ľ", "n": "ň", "r": "ř",
            "s": "š", "t": "ť", "z": "ž", "C": "Č", "D": "Ď", "E": "Ě",
            "L": "Ľ", "N": "Ň", "R": "Ř", "S": "Š", "T": "Ť", "Z": "Ž",
            " ": "ˇ"
        ]
    ]

    static func compose(previous: String, trigger: String) -> String? {
        guard let mapping = composeMap[trigger], let replacement = mapping[previous] else {
            return nil
        }
        return replacement
    }

    // Accent cycling: base character → variants in cycle order
    private static let accentCycles: [String: [String]] = {
        var cycles: [String: [String]] = [:]

        // Build reverse mapping: character → all its accented variants
        // Sort by key for deterministic iteration order across runs
        for (_, charMap) in composeMap.sorted(by: { $0.key < $1.key }) {
            for (base, accented) in charMap.sorted(by: { $0.key < $1.key }) {
                // Skip self-mappings like " " → "\"" or composition mappings
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
        let numberCycles: [String: [String]] = [
            "0": ["0", "⁰"],
            "1": ["1", "¹", "½", "⅓", "¼", "⅕", "⅙", "⅐", "⅛", "⅑", "⅒"],
            "2": ["2", "²", "⅔", "⅖"],
            "3": ["3", "³", "¾", "⅜", "⅗"],
            "4": ["4", "⁴", "⅘"],
            "5": ["5", "⁵", "⅚", "⅝"],
            "6": ["6", "⁶"],
            "7": ["7", "⁷", "⅞"],
            "8": ["8", "⁸"],
            "9": ["9", "⁹"]
        ]

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
    }()

    static func cycleAccent(for character: String) -> String? {
        guard let cycle = accentCycles[character], let currentIndex = cycle.firstIndex(of: character) else {
            return nil
        }

        let nextIndex = (currentIndex + 1) % cycle.count
        return cycle[nextIndex]
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

    /// Reverse tone map built from composeMap: toned char -> (base, telex trigger).
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
            guard let charMap = composeMap[composeTrigger] else { continue }
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
            // 6a. Remove tone (z) on already-toned char: á+z -> a, ấ+z -> â
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
