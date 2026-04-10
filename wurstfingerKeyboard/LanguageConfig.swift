//
//  LanguageConfig.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Foundation

/// Configuration for a keyboard language layout
struct LanguageConfig: Identifiable {
    let id: String
    let name: String
    let locale: Locale

    /// Center characters for the 3x3 letter grid (rows 0-2)
    /// Row 0: [left, center, right]
    /// Row 1: [left, center, right]
    /// Row 2: [left, center, right]
    let centerCharacters: [[String]]

    /// Language-specific character mappings by key position and swipe direction.
    /// These take priority over default punctuation and compose triggers.
    let directionalCharacters: [KeySlot: String]

    init(
        id: String,
        name: String,
        locale: Locale,
        centerCharacters: [[String]],
        directionalCharacters: [KeySlot: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.locale = locale
        self.centerCharacters = centerCharacters
        self.directionalCharacters = directionalCharacters
    }
}

extension LanguageConfig: Equatable {
    /// Compares by id only. Safe because all instances are static constants.
    static func == (lhs: LanguageConfig, rhs: LanguageConfig) -> Bool {
        lhs.id == rhs.id
    }
}

extension LanguageConfig {
    // MARK: - Language Definitions

    /// Croatian keyboard layout
    static let croatian = LanguageConfig(
        id: "hr_HR",
        name: "Hrvatski (Croatian)",
        locale: Locale(identifier: "hr_HR"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .up): "š",
            KeySlot(0, 0, .down): "đ",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ć",
            KeySlot(1, 0, .down): "č",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .up): "ž",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// English keyboard layout (MessagEase default)
    static let english = LanguageConfig(
        id: "en_US",
        name: "English",
        locale: Locale(identifier: "en_US"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Estonian-Finnish keyboard layout
    static let estonianFinnish = LanguageConfig(
        id: "et_EE",
        name: "Eesti-Suomi (Estonian-Finnish)",
        locale: Locale(identifier: "et_EE"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .up): "å",
            KeySlot(0, 0, .down): "ä",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ö",
            KeySlot(1, 0, .down): "õ",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .up): "ü",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 1, .left): "ž",
            KeySlot(2, 2, .upLeft): "f",
            KeySlot(2, 2, .left): "š",
        ]
    )

    /// Finnish keyboard layout
    static let finnish = LanguageConfig(
        id: "fi_FI",
        name: "Suomi (Finnish)",
        locale: Locale(identifier: "fi_FI"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "ä",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .down): "ö",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// French keyboard layout
    static let french = LanguageConfig(
        id: "fr_FR",
        name: "Français (French)",
        locale: Locale(identifier: "fr_FR"),
        centerCharacters: [
            ["a", "n", "i"],
            ["u", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .upRight): "à",
            KeySlot(0, 0, .down): "â",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "û",
            KeySlot(1, 0, .down): "ç",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "h",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .up): "ê",
            KeySlot(2, 0, .right): "è",
            KeySlot(2, 0, .down): "ù",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 1, .left): "é",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// German keyboard layout
    static let german = LanguageConfig(
        id: "de_DE",
        name: "Deutsch (German)",
        locale: Locale(identifier: "de_DE"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "d", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "ä",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ü",
            KeySlot(1, 0, .down): "ö",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .down): "o",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .down): "ß",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Hebrew keyboard layout
    static let hebrew = LanguageConfig(
        id: "he_IL",
        name: "עברית (Hebrew)",
        locale: Locale(identifier: "he_IL"),
        centerCharacters: [
            ["ר", "ב", "א"],
            ["מ", "י", "ו"],
            ["ת", "ה", "ל"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .downRight): "ן",
            KeySlot(0, 1, .down): "ג",
            KeySlot(0, 2, .downLeft): "צ",
            KeySlot(1, 0, .right): "ם",
            KeySlot(1, 1, .upLeft): "ק",
            KeySlot(1, 1, .up): "ח",
            KeySlot(1, 1, .upRight): "פ",
            KeySlot(1, 1, .right): "ד",
            KeySlot(1, 1, .downRight): "ש",
            KeySlot(1, 1, .down): "נ",
            KeySlot(1, 1, .downLeft): "כ",
            KeySlot(1, 1, .left): "ע",
            KeySlot(2, 0, .upRight): "ז",
            KeySlot(2, 1, .up): "ס",
            KeySlot(2, 2, .upLeft): "ט",
        ]
    )

    /// Italian keyboard layout
    static let italian = LanguageConfig(
        id: "it_IT",
        name: "Italiano (Italian)",
        locale: Locale(identifier: "it_IT"),
        centerCharacters: [
            ["a", "n", "i"],
            ["l", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .upRight): "à",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "h",
            KeySlot(0, 2, .upLeft): "ì",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ù",
            KeySlot(1, 0, .down): "ò",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .right): "è",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 1, .left): "é",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Polish keyboard layout
    static let polish = LanguageConfig(
        id: "pl_PL",
        name: "Polski (Polish)",
        locale: Locale(identifier: "pl_PL"),
        centerCharacters: [
            ["a", "n", "i"],
            ["w", "o", "r"],
            ["z", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "ą",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .up): "ń",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .upLeft): "ł",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ó",
            KeySlot(1, 0, .down): "ć",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .down): "ę",
            KeySlot(2, 0, .right): "ź",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "h",
            KeySlot(2, 1, .right): "t",
            KeySlot(2, 1, .left): "ż",
            KeySlot(2, 2, .upLeft): "f",
            KeySlot(2, 2, .left): "ś",
        ]
    )

    /// Russian keyboard layout
    static let russian = LanguageConfig(
        id: "ru_RU",
        name: "Русский (Russian)",
        locale: Locale(identifier: "ru_RU"),
        centerCharacters: [
            ["с", "и", "т"],
            ["в", "о", "а"],
            ["е", "р", "н"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "ц",
            KeySlot(0, 0, .downRight): "п",
            KeySlot(0, 1, .up): "й",
            KeySlot(0, 1, .down): "к",
            KeySlot(0, 2, .downLeft): "ь",
            KeySlot(1, 0, .up): "б",
            KeySlot(1, 0, .down): "ъ",
            KeySlot(1, 0, .right): "ы",
            KeySlot(1, 1, .upLeft): "ч",
            KeySlot(1, 1, .up): "м",
            KeySlot(1, 1, .upRight): "х",
            KeySlot(1, 1, .right): "г",
            KeySlot(1, 1, .downRight): "ш",
            KeySlot(1, 1, .down): "я",
            KeySlot(1, 1, .downLeft): "щ",
            KeySlot(1, 1, .left): "ж",
            KeySlot(1, 2, .left): "л",
            KeySlot(2, 0, .up): "ё",
            KeySlot(2, 0, .right): "э",
            KeySlot(2, 0, .upRight): "д",
            KeySlot(2, 1, .up): "у",
            KeySlot(2, 1, .right): "з",
            KeySlot(2, 1, .left): "ю",
            KeySlot(2, 2, .upLeft): "ф",
        ]
    )

    /// Spanish-Catalan keyboard layout
    static let spanishCatalan = LanguageConfig(
        id: "ca_ES",
        name: "Español-Català (Spanish-Catalan)",
        locale: Locale(identifier: "ca_ES"),
        centerCharacters: [
            ["a", "n", "i"],
            ["d", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .up): "à",
            KeySlot(0, 0, .down): "á",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .up): "ñ",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .upLeft): "í",
            KeySlot(0, 2, .upRight): "ï",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ü",
            KeySlot(1, 0, .down): "ç",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "h",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .up): "ú",
            KeySlot(2, 0, .down): "ó",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 1, .left): "é",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Spanish keyboard layout
    static let spanish = LanguageConfig(
        id: "es_ES",
        name: "Español (Spanish)",
        locale: Locale(identifier: "es_ES"),
        centerCharacters: [
            ["a", "n", "i"],
            ["d", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "á",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .up): "ñ",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .upLeft): "í",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .up): "ü",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "h",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .up): "ú",
            KeySlot(2, 0, .down): "ó",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 1, .left): "é",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Swedish keyboard layout
    static let swedish = LanguageConfig(
        id: "sv_SE",
        name: "Svenska (Swedish)",
        locale: Locale(identifier: "sv_SE"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "d", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .up): "å",
            KeySlot(0, 0, .down): "ä",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .down): "ö",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "o",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Tagalog keyboard layout
    static let tagalog = LanguageConfig(
        id: "tl_PH",
        name: "Tagalog (Filipino)",
        locale: Locale(identifier: "tl_PH"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .up): "ñ",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    /// Vietnamese keyboard layout (Telex input method)
    static let vietnamese = LanguageConfig(
        id: "vi_VN",
        name: "Tiếng Việt (Vietnamese-Telex)",
        locale: Locale(identifier: "vi_VN"),
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"]
        ],
        directionalCharacters: [
            KeySlot(0, 0, .down): "đ",
            KeySlot(0, 0, .downRight): "v",
            KeySlot(0, 1, .down): "l",
            KeySlot(0, 2, .downLeft): "x",
            KeySlot(1, 0, .right): "k",
            KeySlot(1, 1, .upLeft): "q",
            KeySlot(1, 1, .up): "u",
            KeySlot(1, 1, .upRight): "p",
            KeySlot(1, 1, .right): "b",
            KeySlot(1, 1, .downRight): "j",
            KeySlot(1, 1, .down): "d",
            KeySlot(1, 1, .downLeft): "g",
            KeySlot(1, 1, .left): "c",
            KeySlot(1, 2, .left): "m",
            KeySlot(2, 0, .upRight): "y",
            KeySlot(2, 1, .up): "w",
            KeySlot(2, 1, .right): "z",
            KeySlot(2, 2, .upLeft): "f",
        ]
    )

    // MARK: - Language Registry

    /// All available language configurations
    /// All supported languages sorted alphabetically by name
    static let allLanguages: [LanguageConfig] = [
        .spanishCatalan, // Català (Catalan)
        .croatian, // Hrvatski (Croatian)
        .english, // English
        .estonianFinnish, // Eesti-Suomi (Estonian-Finnish)
        .finnish, // Suomi (Finnish)
        .french, // Français (French)
        .german, // Deutsch (German)
        .hebrew, // עברית (Hebrew)
        .italian, // Italiano (Italian)
        .polish, // Polski (Polish)
        .russian, // Русский (Russian)
        .spanish, // Español (Spanish)
        .swedish, // Svenska (Swedish)
        .tagalog, // Tagalog
        .vietnamese, // Tiếng Việt (Vietnamese-Telex)
    ].sorted { $0.name < $1.name }

    /// Get language config by ID
    static func language(withId id: String) -> LanguageConfig? {
        allLanguages.first { $0.id == id }
    }
}
