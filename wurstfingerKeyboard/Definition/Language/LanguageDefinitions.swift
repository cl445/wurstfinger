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

    // MARK: - Registry

    /// All available language descriptors, sorted alphabetically by title.
    ///
    /// Holds metadata only; definitions are built lazily via
    /// `LanguageDescriptor.makeDefinition()` (see `KeyboardRegistry`).
    static let all: [LanguageDescriptor] = [
        spanishCatalan,
        arabic,
        croatian,
        english,
        estonianFinnish,
        finnish,
        french,
        german,
        greek,
        hebrew,
        italian,
        persian,
        polish,
        portuguese,
        russian,
        spanish,
        swedish,
        tagalog,
        ukrainian,
        urdu,
        vietnamese,
    ].sorted { $0.title < $1.title }
}

// MARK: - Additional Layouts

/// Additional language layouts. Kept in a
/// separate extension so the primary `LanguageDefinitions` body stays within
/// SwiftLint's `type_body_length` limit.
extension LanguageDefinitions {
    // MARK: Ukrainian

    /// Ukrainian reuses the Russian Cyrillic layout with four letter
    /// substitutions (ъёэы → ґїєі).
    static let ukrainian = LanguageDescriptor(
        id: "uk_UA",
        title: "Українська (Ukrainian)",
        localeIdentifier: "uk_UA"
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
                GridSlot.midLeft: [.swipeUp: "б", .swipeDown: "ґ", .swipeRight: "і"],
                GridSlot.center: [
                    .swipeUpLeft: "ч", .swipeUp: "м", .swipeUpRight: "х",
                    .swipeRight: "г", .swipeDownRight: "ш", .swipeDown: "я",
                    .swipeDownLeft: "щ", .swipeLeft: "ж",
                ],
                GridSlot.midRight: [.swipeLeft: "л"],
                GridSlot.bottomLeft: [.swipeUp: "ї", .swipeRight: "є", .swipeUpRight: "д"],
                GridSlot.bottomCenter: [.swipeUp: "у", .swipeRight: "з", .swipeLeft: "ю"],
                GridSlot.bottomRight: [.swipeUpLeft: "ф"],
            ],
            numericBackToAlphaLabel: "абв"
        )
    }

    // MARK: Greek

    static let greek = LanguageDescriptor(
        id: "el_GR",
        title: "Ελληνικά (Greek)",
        localeIdentifier: "el_GR"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["α", "ν", "ι"],
                ["η", "ο", "ρ"],
                ["τ", "ε", "σ"],
            ],
            // The generic Latin accent ring (ô â ä í î ç ø é ü) is
            // dropped here: it is noise on a Greek keyboard and would override
            // the default punctuation/symbol swipes. Greek tonos/dialytika
            // belong in compose rules, not as primary swipes.
            directionalOverrides: [
                GridSlot.topLeft: [.swipeDownRight: "ω"],
                GridSlot.topCenter: [.swipeDown: "λ"],
                GridSlot.topRight: [.swipeDownLeft: "χ"],
                GridSlot.midLeft: [.swipeRight: "κ"],
                GridSlot.center: [
                    .swipeUpLeft: "θ", .swipeUp: "υ", .swipeUpRight: "π",
                    .swipeRight: "β", .swipeDownRight: "ς", .swipeDown: "δ",
                    .swipeDownLeft: "γ", .swipeLeft: "ξ",
                ],
                GridSlot.midRight: [.swipeLeft: "μ"],
                GridSlot.bottomLeft: [.swipeUpRight: "ψ"],
                GridSlot.bottomCenter: [.swipeUp: "ω", .swipeRight: "ζ"],
                GridSlot.bottomRight: [.swipeUpLeft: "φ"],
            ],
            numericBackToAlphaLabel: "αβγ"
        )
    }

    // MARK: Portuguese

    static let portuguese = LanguageDescriptor(
        id: "pt_PT",
        title: "Português (Portuguese)",
        localeIdentifier: "pt_PT"
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
                // Portuguese keeps its own accents (â ã õ ô á í ó ú ç ê é);
                // The foreign ring extras — ñ (Spanish) and ü
                // (dropped from Portuguese in the 1990 orthographic reform) —
                // are removed.
                GridSlot.topLeft: [.swipeUp: "ô", .swipeUpRight: "â", .swipeLeft: "ã", .swipeDown: "á", .swipeDownRight: "v"],
                GridSlot.topCenter: [.swipeDown: "l"],
                GridSlot.topRight: [.swipeUpLeft: "í", .swipeRight: "õ", .swipeDownLeft: "x"],
                GridSlot.midLeft: [.swipeRight: "k", .swipeDown: "ç"],
                GridSlot.center: [
                    .swipeUpLeft: "q", .swipeUp: "u", .swipeUpRight: "p",
                    .swipeRight: "b", .swipeDownRight: "j", .swipeDown: "h",
                    .swipeDownLeft: "g", .swipeLeft: "c",
                ],
                GridSlot.midRight: [.swipeLeft: "m"],
                GridSlot.bottomLeft: [.swipeUp: "ú", .swipeUpRight: "y", .swipeRight: "ê", .swipeDown: "ó"],
                GridSlot.bottomCenter: [.swipeUp: "w", .swipeLeft: "é", .swipeRight: "z"],
                GridSlot.bottomRight: [.swipeUpLeft: "f"],
            ]
        )
    }

    // MARK: Arabic script (RTL)

    static let arabic = LanguageDescriptor(
        id: "ar",
        title: "العربية (Arabic)",
        localeIdentifier: "ar"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["ه", "ب", "م"],
                ["ي", "ا", "ر"],
                ["و", "ن", "د"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeRight: "ـ", .swipeDown: "ة", .swipeDownRight: "ق"],
                GridSlot.topCenter: [
                    .swipeUp: "ُ", .swipeUpLeft: "ِ", .swipeUpRight: "َ",
                    .swipeDown: "خ", .swipeDownLeft: "ض",
                ],
                GridSlot.topRight: [.swipeDownLeft: "إ"],
                GridSlot.midLeft: [
                    .swipeUpRight: "ص", .swipeRight: "ح", .swipeDown: "ى",
                    .swipeDownRight: "ط",
                ],
                GridSlot.center: [
                    .swipeUp: "ج", .swipeUpLeft: "ف", .swipeUpRight: "ش",
                    .swipeLeft: "س", .swipeRight: "آ", .swipeDown: "ت",
                    .swipeDownLeft: "ل", .swipeDownRight: "ك",
                ],
                GridSlot.midRight: [.swipeUpLeft: "ٰ", .swipeLeft: "ز", .swipeDownLeft: "ع"],
                GridSlot.bottomLeft: [.swipeUp: "ّ", .swipeUpLeft: "ٓ", .swipeUpRight: "ؤ"],
                GridSlot.bottomCenter: [
                    .swipeUp: "ث", .swipeUpLeft: "ظ", .swipeUpRight: "غ",
                    .swipeLeft: "ء", .swipeRight: "أ", .swipeDownRight: "ئ",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "ً", .swipeUpLeft: "ۋ", .swipeUpRight: "ْ",
                    .swipeLeft: "ذ",
                ],
            ],
            returnOverrides: [
                GridSlot.topCenter: [.swipeUp: "ٌ", .swipeUpLeft: "ٍ", .swipeUpRight: "ً"],
                GridSlot.midLeft: [.swipeDown: "ئ"],
                GridSlot.bottomCenter: [.swipeRight: "إ"],
                GridSlot.bottomRight: [.swipeUpLeft: "گ"],
            ],
            numericBackToAlphaLabel: "ابت",
            numericDigits: NumericLayouts.arabicIndicDigits
        )
    }

    static let persian = LanguageDescriptor(
        id: "fa_IR",
        title: "فارسی (Persian)",
        localeIdentifier: "fa_IR"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["ه", "ب", "م"],
                ["ی", "ا", "ر"],
                ["و", "ن", "د"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeRight: "ـ", .swipeDown: "ۀ", .swipeDownRight: "ق"],
                GridSlot.topCenter: [
                    .swipeUp: "ُ", .swipeUpLeft: "ِ", .swipeUpRight: "َ",
                    .swipeDown: "خ", .swipeDownLeft: "ض", .swipeDownRight: "پ",
                ],
                GridSlot.topRight: [.swipeDownLeft: "چ"],
                GridSlot.midLeft: [.swipeUpRight: "ص", .swipeRight: "ش", .swipeDownRight: "ط"],
                GridSlot.center: [
                    .swipeUp: "ح", .swipeUpLeft: "ف", .swipeUpRight: "ج",
                    .swipeLeft: "س", .swipeRight: "آ", .swipeDown: "ت",
                    .swipeDownLeft: "ل", .swipeDownRight: "ک",
                ],
                GridSlot.midRight: [.swipeUpLeft: "ژ", .swipeLeft: "ز", .swipeDownLeft: "ع"],
                GridSlot.bottomLeft: [.swipeUp: "ّ", .swipeUpLeft: "ٓ", .swipeUpRight: "ؤ"],
                GridSlot.bottomCenter: [
                    .swipeUp: "ث", .swipeUpLeft: "ظ", .swipeUpRight: "غ",
                    .swipeLeft: "ء", .swipeRight: "أ", .swipeDownRight: "ئ",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "ً", .swipeUpLeft: "گ", .swipeUpRight: "ْ",
                    .swipeLeft: "ذ",
                ],
            ],
            returnOverrides: [
                GridSlot.topLeft: [.swipeDown: "ة", .swipeDownRight: "ف"],
                GridSlot.topCenter: [
                    .swipeUp: "ٌ", .swipeUpLeft: "ٍ", .swipeUpRight: "ً",
                    .swipeDown: "ح", .swipeDownLeft: "ص", .swipeDownRight: "ب",
                ],
                GridSlot.topRight: [.swipeDownLeft: "ج"],
                GridSlot.midLeft: [.swipeUpRight: "ض", .swipeRight: "س", .swipeDownRight: "ظ"],
                GridSlot.center: [
                    .swipeUp: "خ", .swipeUpLeft: "ق", .swipeUpRight: "چ",
                    .swipeLeft: "ش", .swipeRight: "ا", .swipeDown: "ث",
                    .swipeDownRight: "گ",
                ],
                GridSlot.midRight: [.swipeLeft: "ر", .swipeDownLeft: "غ"],
                GridSlot.bottomCenter: [
                    .swipeUp: "ت", .swipeUpLeft: "ط", .swipeUpRight: "ع",
                    .swipeRight: "إ",
                ],
                GridSlot.bottomRight: [.swipeUpLeft: "ک", .swipeLeft: "د"],
            ],
            numericBackToAlphaLabel: "ابپ",
            numericDigits: NumericLayouts.persianDigits
        )
    }

    static let urdu = LanguageDescriptor(
        id: "ur",
        title: "اردو (Urdu)",
        localeIdentifier: "ur"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["ه", "ب", "م"],
                ["ی", "ا", "ر"],
                ["و", "ن", "د"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [
                    .swipeUp: "ٹ", .swipeRight: "ـ", .swipeDown: "ۀ",
                    .swipeDownRight: "ق",
                ],
                GridSlot.topCenter: [
                    .swipeUp: "ُ", .swipeUpLeft: "ِ", .swipeUpRight: "َ",
                    .swipeDown: "خ", .swipeDownLeft: "ض", .swipeDownRight: "پ",
                ],
                GridSlot.topRight: [.swipeDownLeft: "چ"],
                GridSlot.midLeft: [
                    .swipeUp: "ۓ", .swipeUpRight: "ص", .swipeRight: "ح",
                    .swipeDown: "ے", .swipeDownRight: "ط",
                ],
                GridSlot.center: [
                    .swipeUp: "ج", .swipeUpLeft: "ف", .swipeUpRight: "ش",
                    .swipeLeft: "س", .swipeRight: "آ", .swipeDown: "ت",
                    .swipeDownLeft: "ل", .swipeDownRight: "ک",
                ],
                GridSlot.midRight: [
                    .swipeUp: "ڑ", .swipeUpLeft: "ژ", .swipeLeft: "ز",
                    .swipeDown: "ڈ", .swipeDownLeft: "ع",
                ],
                GridSlot.bottomLeft: [.swipeUp: "ّ", .swipeUpLeft: "ٓ", .swipeUpRight: "ؤ"],
                GridSlot.bottomCenter: [
                    .swipeUp: "ث", .swipeUpLeft: "ظ", .swipeUpRight: "غ",
                    .swipeLeft: "ء", .swipeRight: "ں", .swipeDownRight: "ئ",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "ً", .swipeUpLeft: "گ", .swipeUpRight: "ْ",
                    .swipeLeft: "ذ",
                ],
            ],
            returnOverrides: [
                GridSlot.topLeft: [.swipeDown: "ة"],
                GridSlot.topCenter: [.swipeUp: "ٌ", .swipeUpLeft: "ٍ", .swipeUpRight: "ً"],
            ],
            numericBackToAlphaLabel: "ابپ",
            numericDigits: NumericLayouts.persianDigits
        )
    }
}
