//
//  LanguageDefinitions.swift
//  Wurstfinger
//
//  All supported keyboard language definitions using GridKeyboardFactory.
//

import Foundation

/// All supported keyboard language definitions.
/// Each definition is a complete KeyboardDefinition produced by GridKeyboardFactory.
enum LanguageDefinitions {
    // MARK: - Croatian

    static let croatian = GridKeyboardFactory.layout(
        id: "hr_HR",
        title: "Hrvatski (Croatian)",
        localeIdentifier: "hr_HR",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUp: "š", .swipeDown: "đ", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ć", .swipeDown: "č", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUp: "ž", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - English

    static let english = GridKeyboardFactory.layout(
        id: "en_US",
        title: "English",
        localeIdentifier: "en_US",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Estonian-Finnish

    static let estonianFinnish = GridKeyboardFactory.layout(
        id: "et_EE",
        title: "Eesti-Suomi (Estonian-Finnish)",
        localeIdentifier: "et_EE",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUp: "å", .swipeDown: "ä", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ö", .swipeDown: "õ", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUp: "ü", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z", .swipeLeft: "ž"],
            GridSlot.bottomRight: [.swipeUpLeft: "f", .swipeLeft: "š"],
        ]
    )

    // MARK: - Finnish

    static let finnish = GridKeyboardFactory.layout(
        id: "fi_FI",
        title: "Suomi (Finnish)",
        localeIdentifier: "fi_FI",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDown: "ä", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeDown: "ö", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - French

    static let french = GridKeyboardFactory.layout(
        id: "fr_FR",
        title: "Français (French)",
        localeIdentifier: "fr_FR",
        centerCharacters: [
            ["a", "n", "i"],
            ["u", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUpRight: "à", .swipeDown: "â", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "û", .swipeDown: "ç", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "h", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUp: "ê", .swipeRight: "è", .swipeDown: "ù", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z", .swipeLeft: "é"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - German

    static let german = GridKeyboardFactory.layout(
        id: "de_DE",
        title: "Deutsch (German)",
        localeIdentifier: "de_DE",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "d", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDown: "ä", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ü", .swipeDown: "ö", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUp: "u", .swipeUpLeft: "q", .swipeLeft: "c",
                .swipeDownLeft: "g", .swipeDown: "o", .swipeDownRight: "j",
                .swipeRight: "b", .swipeUpRight: "p",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeDown: "ß", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Hebrew

    static let hebrew = GridKeyboardFactory.layout(
        id: "he_IL",
        title: "עברית (Hebrew)",
        localeIdentifier: "he_IL",
        centerCharacters: [
            ["ר", "ב", "א"],
            ["מ", "י", "ו"],
            ["ת", "ה", "ל"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDownRight: "ן"],
            GridSlot.topCenter: [.swipeDown: "ג"],
            GridSlot.topRight: [.swipeDownLeft: "צ"],
            GridSlot.midLeft: [.swipeRight: "ם"],
            GridSlot.center: [
                .swipeUpLeft: "ק", .swipeUp: "ח", .swipeUpRight: "פ",
                .swipeRight: "ד", .swipeDownRight: "ש", .swipeDown: "נ",
                .swipeDownLeft: "כ", .swipeLeft: "ע",
            ],
            GridSlot.bottomLeft: [.swipeUpRight: "ז"],
            GridSlot.bottomCenter: [.swipeUp: "ס"],
            GridSlot.bottomRight: [.swipeUpLeft: "ט"],
        ],
        numericBackToAlphaLabel: "אבג"
    )

    // MARK: - Italian

    static let italian = GridKeyboardFactory.layout(
        id: "it_IT",
        title: "Italiano (Italian)",
        localeIdentifier: "it_IT",
        centerCharacters: [
            ["a", "n", "i"],
            ["l", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUpRight: "à", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "h"],
            GridSlot.topRight: [.swipeUpLeft: "ì", .swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ù", .swipeDown: "ò", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeRight: "è", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z", .swipeLeft: "é"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Polish

    static let polish = GridKeyboardFactory.layout(
        id: "pl_PL",
        title: "Polski (Polish)",
        localeIdentifier: "pl_PL",
        centerCharacters: [
            ["a", "n", "i"],
            ["w", "o", "r"],
            ["z", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDown: "ą", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeUp: "ń", .swipeDown: "l"],
            GridSlot.topRight: [.swipeUpLeft: "ł", .swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ó", .swipeDown: "ć", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeDown: "ę", .swipeRight: "ź", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "h", .swipeRight: "t", .swipeLeft: "ż"],
            GridSlot.bottomRight: [.swipeUpLeft: "f", .swipeLeft: "ś"],
        ]
    )

    // MARK: - Russian

    static let russian = GridKeyboardFactory.layout(
        id: "ru_RU",
        title: "Русский (Russian)",
        localeIdentifier: "ru_RU",
        centerCharacters: [
            ["с", "и", "т"],
            ["в", "о", "а"],
            ["е", "р", "н"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDown: "ц", .swipeDownRight: "п"],
            GridSlot.topCenter: [.swipeUp: "й", .swipeDown: "к"],
            GridSlot.topRight: [.swipeDownLeft: "ь"],
            GridSlot.midLeft: [.swipeUp: "б", .swipeDown: "ъ", .swipeRight: "ы"],
            GridSlot.center: [
                .swipeUpLeft: "ч", .swipeUp: "м", .swipeUpRight: "х",
                .swipeRight: "г", .swipeDownRight: "ш", .swipeDown: "я",
                .swipeDownLeft: "щ", .swipeLeft: "ж",
            ],
            GridSlot.midRight: [.swipeLeft: "л"],
            GridSlot.bottomLeft: [.swipeUp: "ё", .swipeRight: "э", .swipeUpRight: "д"],
            GridSlot.bottomCenter: [.swipeUp: "у", .swipeRight: "з", .swipeLeft: "ю"],
            GridSlot.bottomRight: [.swipeUpLeft: "ф"],
        ],
        numericBackToAlphaLabel: "абв"
    )

    // MARK: - Spanish-Catalan

    static let spanishCatalan = GridKeyboardFactory.layout(
        id: "ca_ES",
        title: "Español-Català (Spanish-Catalan)",
        localeIdentifier: "ca_ES",
        centerCharacters: [
            ["a", "n", "i"],
            ["d", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUp: "à", .swipeDown: "á", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeUp: "ñ", .swipeDown: "l"],
            GridSlot.topRight: [.swipeUpLeft: "í", .swipeUpRight: "ï", .swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ü", .swipeDown: "ç", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "h",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUp: "ú", .swipeDown: "ó", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z", .swipeLeft: "é"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Spanish

    static let spanish = GridKeyboardFactory.layout(
        id: "es_ES",
        title: "Español (Spanish)",
        localeIdentifier: "es_ES",
        centerCharacters: [
            ["a", "n", "i"],
            ["d", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDown: "á", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeUp: "ñ", .swipeDown: "l"],
            GridSlot.topRight: [.swipeUpLeft: "í", .swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeUp: "ü", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "h",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUp: "ú", .swipeDown: "ó", .swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z", .swipeLeft: "é"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Swedish

    static let swedish = GridKeyboardFactory.layout(
        id: "sv_SE",
        title: "Svenska (Swedish)",
        localeIdentifier: "sv_SE",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "d", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeUp: "å", .swipeDown: "ä", .swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeDown: "ö", .swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "o",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Tagalog

    static let tagalog = GridKeyboardFactory.layout(
        id: "tl_PH",
        title: "Tagalog (Filipino)",
        localeIdentifier: "tl_PH",
        centerCharacters: [
            ["a", "n", "i"],
            ["h", "o", "r"],
            ["t", "e", "s"],
        ],
        directionalOverrides: [
            GridSlot.topLeft: [.swipeDownRight: "v"],
            GridSlot.topCenter: [.swipeUp: "ñ", .swipeDown: "l"],
            GridSlot.topRight: [.swipeDownLeft: "x"],
            GridSlot.midLeft: [.swipeRight: "k"],
            GridSlot.center: [
                .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "d",
                .swipeDownLeft: "g", .swipeLeft: "c",
            ],
            GridSlot.midRight: [.swipeLeft: "m"],
            GridSlot.bottomLeft: [.swipeUpRight: "y"],
            GridSlot.bottomCenter: [.swipeUp: "w", .swipeRight: "z"],
            GridSlot.bottomRight: [.swipeUpLeft: "f"],
        ]
    )

    // MARK: - Registry

    /// All available language definitions, sorted alphabetically by title.
    static let all: [KeyboardDefinition] = [
        spanishCatalan,
        croatian,
        english,
        estonianFinnish,
        finnish,
        french,
        german,
        hebrew,
        italian,
        polish,
        russian,
        spanish,
        swedish,
        tagalog,
    ].sorted { $0.title < $1.title }
}
