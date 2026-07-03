//
//  ComposeRuleSet+Vietnamese.swift
//  Wurstfinger
//
//  Vietnamese tone compose rules (hỏi and nặng) used by Telex input.
//

import Foundation

extension ComposeRuleSet {
    /// Vietnamese tone rules extracted from Thumb-Key compose tables.
    /// The `?` (hỏi, hook above) and `*` (nặng, dot below) triggers are only
    /// meaningful for Vietnamese Telex input, so they are kept out of
    /// `ComposeRuleSet.global` — otherwise every layout would compose
    /// `a` + `*` → `ạ` instead of inserting a literal asterisk.
    static let vietnameseTones = ComposeRuleSet(rules: [
        "?": [
            "a": "ả", "A": "Ả", "â": "ẩ", "Â": "Ẩ", "ă": "ẳ", "Ă": "Ẳ",
            "o": "ỏ", "O": "Ỏ", "ô": "ổ", "Ô": "Ổ", "ơ": "ở", "Ơ": "Ở",
            "u": "ủ", "U": "Ủ", "ư": "ử", "Ư": "Ử", "i": "ỉ", "I": "Ỉ",
            "e": "ẻ", "E": "Ẻ", "ê": "ể", "Ê": "Ể", "y": "ỷ", "Y": "Ỷ",
        ],
        "*": [
            "a": "ạ", "A": "Ạ", "â": "ậ", "Â": "Ậ", "ă": "ặ", "Ă": "Ặ",
            "o": "ọ", "O": "Ọ", "ô": "ộ", "Ô": "Ộ", "ơ": "ợ", "Ơ": "Ợ",
            "u": "ụ", "U": "Ụ", "ư": "ự", "Ư": "Ự", "i": "ị", "I": "Ị",
            "e": "ẹ", "E": "Ẹ", "ê": "ệ", "Ê": "Ệ", "y": "ỵ", "Y": "Ỵ",
        ],
    ])
}
