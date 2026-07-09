//
//  LanguageDefinitions.swift
//  Wurstfinger
//
//  All supported keyboard language definitions using GridKeyboardFactory.
//

import Foundation

/// All supported keyboard language definitions.
///
/// Each entry is a ``LanguageDescriptor``: its metadata (id/title/locale) is
/// available immediately, while the full `KeyboardDefinition` is built lazily
/// via `makeDefinition()`. The builder reuses the descriptor's metadata
/// (`meta.id`, …) so the id/title/locale live in exactly one place.
enum LanguageDefinitions {
    // MARK: - Croatian

    static let croatian = LanguageDescriptor(
        id: "hr_HR",
        title: "Hrvatski (Croatian)",
        localeIdentifier: "hr_HR"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - English

    static let english = LanguageDescriptor(
        id: "en_US",
        title: "English",
        localeIdentifier: "en_US"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Estonian-Finnish

    static let estonianFinnish = LanguageDescriptor(
        id: "et_EE",
        title: "Eesti-Suomi (Estonian-Finnish)",
        localeIdentifier: "et_EE"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Finnish

    static let finnish = LanguageDescriptor(
        id: "fi_FI",
        title: "Suomi (Finnish)",
        localeIdentifier: "fi_FI"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - French

    static let french = LanguageDescriptor(
        id: "fr_FR",
        title: "Français (French)",
        localeIdentifier: "fr_FR"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - German

    static let german = LanguageDescriptor(
        id: "de_DE",
        title: "Deutsch (German)",
        localeIdentifier: "de_DE"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Hebrew

    static let hebrew = LanguageDescriptor(
        id: "he_IL",
        title: "עברית (Hebrew)",
        localeIdentifier: "he_IL"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
            // MessagEase convention: a return swipe on a base letter produces
            // its final form (ן/ם additionally keep their dedicated swipes).
            returnOverrides: [
                GridSlot.topRight: [.swipeDownLeft: "ץ"],
                GridSlot.center: [
                    .swipeUpRight: "ף", .swipeDown: "ן", .swipeDownLeft: "ך",
                ],
            ],
            // Hebrew is caseless: no shift key, no shifted/capsLock modes,
            // no auto-capitalization.
            supportsCapitalization: false,
            numericBackToAlphaLabel: "אבג"
        )
    }

    // MARK: - Italian

    static let italian = LanguageDescriptor(
        id: "it_IT",
        title: "Italiano (Italian)",
        localeIdentifier: "it_IT"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Polish

    static let polish = LanguageDescriptor(
        id: "pl_PL",
        title: "Polski (Polish)",
        localeIdentifier: "pl_PL"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Russian

    static let russian = LanguageDescriptor(
        id: "ru_RU",
        title: "Русский (Russian)",
        localeIdentifier: "ru_RU"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Spanish-Catalan

    static let spanishCatalan = LanguageDescriptor(
        id: "ca_ES",
        title: "Español-Català (Spanish-Catalan)",
        localeIdentifier: "ca_ES"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Spanish

    static let spanish = LanguageDescriptor(
        id: "es_ES",
        title: "Español (Spanish)",
        localeIdentifier: "es_ES"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Swedish

    static let swedish = LanguageDescriptor(
        id: "sv_SE",
        title: "Svenska (Swedish)",
        localeIdentifier: "sv_SE"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Tagalog

    static let tagalog = LanguageDescriptor(
        id: "tl_PH",
        title: "Tagalog (Filipino)",
        localeIdentifier: "tl_PH"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
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
    }

    // MARK: - Vietnamese (Telex)

    static let vietnamese = LanguageDescriptor(
        id: "vi_VN",
        title: "Tiếng Việt (Vietnamese-Telex)",
        localeIdentifier: "vi_VN"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["a", "n", "i"],
                ["h", "o", "r"],
                ["t", "e", "s"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeDown: "đ", .swipeDownRight: "v"],
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
            ],
            inputMethod: .telex
        )
    }
}
