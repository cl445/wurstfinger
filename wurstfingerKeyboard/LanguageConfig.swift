//
//  LanguageConfig.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import Foundation

/// Configuration for a keyboard language layout
struct LanguageConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let locale: Locale

    /// Center characters for the 3x3 letter grid (rows 0-2)
    /// Row 0: [left, center, right]
    /// Row 1: [left, center, right]
    /// Row 2: [left, center, right]
    let centerCharacters: [[String]]

    /// Special character mappings for language-specific characters
    /// Keys are positions in format "row_col_direction" or "row_col_center"
    /// Example: "0_0_down" = character when swiping down on top-left key
    let specialCharacters: [String: String]

    init(
        id: String,
        name: String,
        locale: Locale,
        centerCharacters: [[String]],
        specialCharacters: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.locale = locale
        self.centerCharacters = centerCharacters
        self.specialCharacters = specialCharacters
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
        specialCharacters: [
            "0_0_up": "š",
            "0_0_down": "đ",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_up": "ć",
            "1_0_down": "č",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_up": "ž",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_up": "å",
            "0_0_down": "ä",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_up": "ö",
            "1_0_down": "õ",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_up": "ü",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_1_left": "ž",
            "2_2_upLeft": "f",
            "2_2_left": "š"
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
        specialCharacters: [
            "0_0_down": "ä",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_down": "ö",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_upRight": "à",
            "0_0_down": "â",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_up": "û",
            "1_0_down": "ç",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "h",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_up": "ê",
            "2_0_right": "è",
            "2_0_down": "ù",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_1_left": "é",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_down": "ä",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_up": "ü",
            "1_0_down": "ö",
            "1_0_right": "k",
            "1_1_up": "u",
            "1_1_upLeft": "q",
            "1_1_left": "c",
            "1_1_downLeft": "g",
            "1_1_down": "o",
            "1_1_downRight": "j",
            "1_1_right": "b",
            "1_1_upRight": "p",
            "1_2_left": "m",
            "2_0_down": "ß",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_downRight": "ן",
            "0_1_down": "ג",
            "0_2_downLeft": "צ",
            "1_0_right": "ם",
            "1_1_upLeft": "ק",
            "1_1_up": "ח",
            "1_1_upRight": "פ",
            "1_1_right": "ד",
            "1_1_downRight": "ש",
            "1_1_down": "נ",
            "1_1_downLeft": "כ",
            "1_1_left": "ע",
            "2_0_upRight": "ז",
            "2_1_up": "ס",
            "2_2_upLeft": "ט"
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
        specialCharacters: [
            "0_0_upRight": "à",
            "0_0_downRight": "v",
            "0_1_down": "h",
            "0_2_upLeft": "ì",
            "0_2_downLeft": "x",
            "1_0_up": "ù",
            "1_0_down": "ò",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_right": "è",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_1_left": "é",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_down": "ą",
            "0_0_downRight": "v",
            "0_1_up": "ń",
            "0_1_down": "l",
            "0_2_upLeft": "ł",
            "0_2_downLeft": "x",
            "1_0_up": "ó",
            "1_0_down": "ć",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_down": "ę",
            "2_0_right": "ź",
            "2_0_upRight": "y",
            "2_1_up": "h",
            "2_1_right": "t",
            "2_1_left": "ż",
            "2_2_upLeft": "f",
            "2_2_left": "ś"
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
        specialCharacters: [
            "0_0_down": "ц",
            "0_0_downRight": "п",
            "0_1_up": "й",
            "0_1_down": "к",
            "0_2_downLeft": "ь",
            "1_0_up": "б",
            "1_0_down": "ъ",
            "1_0_right": "ы",
            "1_1_upLeft": "ч",
            "1_1_up": "м",
            "1_1_upRight": "х",
            "1_1_right": "г",
            "1_1_downRight": "ш",
            "1_1_down": "я",
            "1_1_downLeft": "щ",
            "1_1_left": "ж",
            "1_2_left": "л",
            "2_0_up": "ё",
            "2_0_right": "э",
            "2_0_upRight": "д",
            "2_1_up": "у",
            "2_1_right": "з",
            "2_1_left": "ю",
            "2_2_upLeft": "ф"
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
        specialCharacters: [
            "0_0_up": "à",
            "0_0_down": "á",
            "0_0_downRight": "v",
            "0_1_up": "ñ",
            "0_1_down": "l",
            "0_2_upLeft": "í",
            "0_2_upRight": "ï",
            "0_2_downLeft": "x",
            "1_0_up": "ü",
            "1_0_down": "ç",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "h",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_up": "ú",
            "2_0_down": "ó",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_1_left": "é",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_down": "á",
            "0_0_downRight": "v",
            "0_1_up": "ñ",
            "0_1_down": "l",
            "0_2_upLeft": "í",
            "0_2_downLeft": "x",
            "1_0_up": "ü",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "h",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_up": "ú",
            "2_0_down": "ó",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_1_left": "é",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_down": "ä",
            "0_0_downRight": "v",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_down": "ö",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "o",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
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
        specialCharacters: [
            "0_0_downRight": "v",
            "0_1_up": "ñ",
            "0_1_down": "l",
            "0_2_downLeft": "x",
            "1_0_right": "k",
            "1_1_upLeft": "q",
            "1_1_up": "u",
            "1_1_upRight": "p",
            "1_1_right": "b",
            "1_1_downRight": "j",
            "1_1_down": "d",
            "1_1_downLeft": "g",
            "1_1_left": "c",
            "1_2_left": "m",
            "2_0_upRight": "y",
            "2_1_up": "w",
            "2_1_right": "z",
            "2_2_upLeft": "f"
        ]
    )

    // MARK: - Language Registry

    /// All available language configurations
    /// All supported languages sorted alphabetically by name
    static let allLanguages: [LanguageConfig] = [
        .spanishCatalan,    // Català (Catalan)
        .croatian,          // Hrvatski (Croatian)
        .english,           // English
        .estonianFinnish,   // Eesti-Suomi (Estonian-Finnish)
        .finnish,           // Suomi (Finnish)
        .french,            // Français (French)
        .german,            // Deutsch (German)
        .hebrew,            // עברית (Hebrew)
        .italian,           // Italiano (Italian)
        .polish,            // Polski (Polish)
        .russian,           // Русский (Russian)
        .spanish,           // Español (Spanish)
        .swedish,           // Svenska (Swedish)
        .tagalog            // Tagalog
    ].sorted { $0.name < $1.name }

    /// Get language config by ID
    static func language(withId id: String) -> LanguageConfig? {
        allLanguages.first { $0.id == id }
    }
}
