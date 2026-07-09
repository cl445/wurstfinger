//
//  LanguageDefinitions+MessagEase.swift
//  Wurstfinger
//
//  Keyboard layouts ported 1:1 from the decompiled MessagEase reference,
//  kept out of the primary LanguageDefinitions file to stay within SwiftLint's
//  file_length / type_body_length limits.
//

import Foundation

// MARK: - Additional MessagEase Layouts

/// Layouts ported 1:1 from the decompiled MessagEase reference. Kept in a
/// separate extension so the primary `LanguageDefinitions` body stays within
/// SwiftLint's `type_body_length` limit.
extension LanguageDefinitions {
    // MARK: Ukrainian

    /// Ukrainian reuses the Russian Cyrillic layout with MessagEase's four
    /// letter substitutions (ъёэы → ґїєі), matching the decompiled reference.
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
            // MessagEase's generic Latin accent ring (ô â ä í î ç ø é ü) is
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
                // MessagEase's foreign ring extras — ñ (Spanish) and ü
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
            supportsCapitalization: false,
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
            supportsCapitalization: false,
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
            supportsCapitalization: false,
            numericBackToAlphaLabel: "ابپ",
            numericDigits: NumericLayouts.persianDigits
        )
    }

    // MARK: Thai

    static let thai = LanguageDescriptor(
        id: "th_TH",
        title: "ไทย (Thai)",
        localeIdentifier: "th_TH"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["า", "น", "ั"],
                ["ก", "อ", "ร"],
                ["ม", "เ", "ง"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [
                    .swipeUp: "ุ", .swipeUpRight: "ิ", .swipeLeft: "ฝ",
                    .swipeDown: "ู", .swipeDownLeft: "ฟ", .swipeDownRight: "ี",
                ],
                GridSlot.topCenter: [
                    .swipeUp: "ณ", .swipeUpLeft: "็", .swipeUpRight: "์",
                    .swipeDown: "ล", .swipeDownRight: "ข",
                ],
                GridSlot.topRight: [
                    .swipeUpLeft: "ฮ", .swipeRight: "ฐ", .swipeDown: "ะ",
                    .swipeDownLeft: "ๆ", .swipeDownRight: "ภ",
                ],
                GridSlot.midLeft: [
                    .swipeUp: "ื", .swipeUpLeft: "ึ", .swipeUpRight: "โ",
                    .swipeRight: "ค", .swipeDown: "ใ", .swipeDownLeft: "ฤ",
                    .swipeDownRight: "ไ",
                ],
                GridSlot.center: [
                    .swipeUp: "้", .swipeUpLeft: "่", .swipeUpRight: "ป",
                    .swipeLeft: "ช", .swipeRight: "บ", .swipeDown: "ด",
                    .swipeDownLeft: "ห", .swipeDownRight: "จ",
                ],
                GridSlot.midRight: [
                    .swipeUpLeft: "ผ", .swipeUpRight: "ถ", .swipeLeft: "ท",
                    .swipeDownLeft: "พ", .swipeDownRight: "ธ",
                ],
                GridSlot.bottomLeft: [
                    .swipeUp: "ำ", .swipeUpLeft: "ญ", .swipeUpRight: "ย",
                    .swipeLeft: "๊", .swipeDown: "๋",
                ],
                GridSlot.bottomCenter: [.swipeUp: "ว", .swipeLeft: "แ", .swipeRight: "ต"],
                GridSlot.bottomRight: [
                    .swipeUp: "ฉ", .swipeUpLeft: "ส", .swipeUpRight: "ซ",
                    .swipeRight: "ศ", .swipeDownLeft: "ษ",
                ],
            ],
            returnOverrides: [
                GridSlot.topLeft: [
                    .swipeUp: "ู", .swipeUpRight: "ี", .swipeLeft: "ฺ",
                    .swipeDown: "ุ", .swipeDownLeft: "พ", .swipeDownRight: "ิ",
                ],
                GridSlot.topCenter: [
                    .swipeUp: "โ", .swipeUpLeft: "ใ", .swipeUpRight: "ไ",
                    .swipeDown: "ฦ", .swipeDownRight: "ญ",
                ],
                GridSlot.topRight: [
                    .swipeUpLeft: "ฆ", .swipeRight: "ฃ", .swipeDown: "ข",
                    .swipeDownLeft: "ฯ", .swipeDownRight: "ถ",
                ],
                GridSlot.midLeft: [
                    .swipeUp: "ึ", .swipeUpLeft: "ื", .swipeUpRight: "จ",
                    .swipeRight: "ข", .swipeDown: "ๅ", .swipeDownLeft: "ฦ",
                    .swipeDownRight: "ฤ",
                ],
                GridSlot.center: [
                    .swipeUp: "๋", .swipeUpLeft: "๊", .swipeUpRight: "ผ",
                    .swipeLeft: "ฉ", .swipeRight: "ษ", .swipeDown: "ฎ",
                    .swipeDownLeft: "ฮ", .swipeDownRight: "ช",
                ],
                GridSlot.midRight: [
                    .swipeUpLeft: "ฝ", .swipeUpRight: "ภ", .swipeDownLeft: "ฟ",
                    .swipeDownRight: "ณ",
                ],
                GridSlot.bottomLeft: [
                    .swipeUp: "์", .swipeUpLeft: "แ", .swipeUpRight: "๎",
                    .swipeLeft: "็",
                ],
                GridSlot.bottomCenter: [.swipeUp: "ๆ", .swipeRight: "ํ"],
                GridSlot.bottomRight: [.swipeUp: "ฌ", .swipeRight: "ซ", .swipeDownLeft: "ำ"],
            ],
            supportsCapitalization: false,
            numericBackToAlphaLabel: "กขค",
            numericDigits: NumericLayouts.thaiDigits
        )
    }

    // MARK: Hindi

    static let hindi = LanguageDescriptor(
        id: "hi_IN",
        title: "हिन्दी (Hindi)",
        localeIdentifier: "hi_IN"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["म", "न", "ल"],
                ["ह", "क", "र"],
                ["त", "प", "स"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [
                    .swipeUp: "ः", .swipeUpRight: "ँ", .swipeLeft: "ृ",
                    .swipeRight: "अ", .swipeDown: "ओ", .swipeDownLeft: "ञ",
                    .swipeDownRight: "द",
                ],
                GridSlot.topCenter: [
                    .swipeUp: "आ", .swipeUpLeft: "ऊ", .swipeUpRight: "उ",
                    .swipeLeft: "ौ", .swipeRight: "ो", .swipeDown: "व",
                    .swipeDownLeft: "ई", .swipeDownRight: "इ",
                ],
                GridSlot.topRight: [.swipeRight: "़", .swipeDownLeft: "ज", .swipeDownRight: "ख"],
                GridSlot.midLeft: [
                    .swipeUp: "ऑ", .swipeUpLeft: "ॅ", .swipeUpRight: "थ",
                    .swipeRight: "ब", .swipeDown: "झ", .swipeDownLeft: "ढ",
                    .swipeDownRight: "श",
                ],
                GridSlot.center: [
                    .swipeUp: "ा", .swipeUpLeft: "ू", .swipeUpRight: "ु",
                    .swipeLeft: "ी", .swipeRight: "ि", .swipeDown: "्",
                    .swipeDownLeft: "ै", .swipeDownRight: "े",
                ],
                GridSlot.midRight: [
                    .swipeUp: "ट", .swipeUpLeft: "छ", .swipeUpRight: "ड",
                    .swipeLeft: "फ", .swipeDown: "।", .swipeDownRight: "ठ",
                ],
                GridSlot.bottomLeft: [
                    .swipeUp: "ऐ", .swipeUpLeft: "ऋ", .swipeUpRight: "ं",
                    .swipeLeft: "ण",
                ],
                GridSlot.bottomCenter: [
                    .swipeUp: "ए", .swipeUpRight: "औ", .swipeRight: "ग",
                    .swipeDownRight: "ष",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "च", .swipeUpLeft: "य", .swipeUpRight: "भ",
                    .swipeLeft: "ध", .swipeRight: "घ", .swipeDownLeft: "ॉ",
                ],
            ],
            supportsCapitalization: false,
            numericBackToAlphaLabel: "कखग",
            numericDigits: NumericLayouts.devanagariDigits,
            combineRuleSet: hindiCombineRules
        )
    }

    /// Devanagari vowel lengthening (short vowel typed twice → long).
    /// From MessagEase `hindiCombine`; `trigger` is the second-typed vowel.
    private static let hindiCombineRules = ComposeRuleSet(rules: [
        "इ": ["इ": "ई"],
        "उ": ["उ": "ऊ"],
        "ऋ": ["ऋ": "ॠ"],
        "ऌ": ["ऌ": "ॡ"],
        "ऍ": ["ऍ": "ऎ"],
    ])

    // MARK: Japanese kana

    static let hiragana = LanguageDescriptor(
        id: "ja_JP",
        title: "日本語 かな (Hiragana)",
        localeIdentifier: "ja_JP"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["く", "つ", "い"],
                ["ふ", "る", "ら"],
                ["と", "ん", "す"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeRight: "ー", .swipeDown: "や", .swipeDownRight: "さ"],
                GridSlot.topCenter: [
                    .swipeUp: "そ", .swipeUpLeft: "め", .swipeUpRight: "も",
                    .swipeDown: "ま",
                ],
                GridSlot.topRight: [.swipeDownLeft: "ひ"],
                GridSlot.midLeft: [
                    .swipeLeft: "せ", .swipeRight: "き", .swipeDown: "わ",
                    .swipeDownLeft: "へ", .swipeDownRight: "に",
                ],
                GridSlot.center: [
                    .swipeUp: "あ", .swipeUpLeft: "か", .swipeUpRight: "し",
                    .swipeLeft: "は", .swipeRight: "り", .swipeDown: "れ",
                    .swipeDownLeft: "た", .swipeDownRight: "ほ",
                ],
                GridSlot.midRight: [
                    .swipeUpLeft: "ゆ", .swipeLeft: "ろ", .swipeRight: "み",
                    .swipeDownRight: "ち",
                ],
                GridSlot.bottomLeft: [
                    .swipeUp: "の", .swipeUpLeft: "ゝ", .swipeUpRight: "む",
                    .swipeLeft: "を", .swipeRight: "う", .swipeDown: "な",
                ],
                GridSlot.bottomCenter: [
                    .swipeUp: "て", .swipeUpLeft: "゛", .swipeLeft: "ね",
                    .swipeRight: "け",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "え", .swipeUpLeft: "こ", .swipeLeft: "よ",
                    .swipeRight: "ぬ", .swipeDownLeft: "お",
                ],
            ],
            supportsCapitalization: false,
            numericBackToAlphaLabel: "かな",
            combineRuleSet: hiraganaCombineRules
        )
    }

    /// Dakuten voicing (kana + ゛ → voiced kana), from MessagEase hiraganaCombine.
    private static let hiraganaCombineRules = ComposeRuleSet(rules: [
        "゛": [
            "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご", "さ": "ざ",
            "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ", "た": "だ", "ち": "ぢ",
            "つ": "づ", "て": "で", "と": "ど", "は": "ば", "ひ": "び", "ふ": "ぶ",
            "へ": "べ", "ほ": "ぼ", "う": "ゔ",
        ],
    ])

    static let katakana = LanguageDescriptor(
        id: "ja_JP_katakana",
        title: "日本語 カナ (Katakana)",
        localeIdentifier: "ja_JP_katakana"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["ク", "ツ", "イ"],
                ["フ", "ル", "ラ"],
                ["ト", "ン", "ス"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeRight: "ー", .swipeDown: "ヤ", .swipeDownRight: "サ"],
                GridSlot.topCenter: [
                    .swipeUp: "ソ", .swipeUpLeft: "メ", .swipeUpRight: "モ",
                    .swipeDown: "マ",
                ],
                GridSlot.topRight: [.swipeDownLeft: "ヒ"],
                GridSlot.midLeft: [
                    .swipeLeft: "セ", .swipeRight: "キ", .swipeDown: "ワ",
                    .swipeDownLeft: "ヘ", .swipeDownRight: "ニ",
                ],
                GridSlot.center: [
                    .swipeUp: "ア", .swipeUpLeft: "カ", .swipeUpRight: "シ",
                    .swipeLeft: "ハ", .swipeRight: "リ", .swipeDown: "レ",
                    .swipeDownLeft: "タ", .swipeDownRight: "ホ",
                ],
                GridSlot.midRight: [
                    .swipeUpLeft: "ユ", .swipeLeft: "ロ", .swipeRight: "ミ",
                    .swipeDownRight: "チ",
                ],
                GridSlot.bottomLeft: [
                    .swipeUp: "ノ", .swipeUpLeft: "ヽ", .swipeUpRight: "ム",
                    .swipeLeft: "ヲ", .swipeRight: "ウ", .swipeDown: "ナ",
                ],
                GridSlot.bottomCenter: [
                    .swipeUp: "テ", .swipeUpLeft: "゛", .swipeLeft: "ネ",
                    .swipeRight: "ケ", .swipeDownRight: "・",
                ],
                GridSlot.bottomRight: [
                    .swipeUp: "エ", .swipeUpLeft: "コ", .swipeLeft: "ヨ",
                    .swipeRight: "ヌ", .swipeDownLeft: "オ",
                ],
            ],
            supportsCapitalization: false,
            numericBackToAlphaLabel: "カナ",
            combineRuleSet: katakanaCombineRules
        )
    }

    /// Dakuten voicing (kana + ゛ → voiced kana), from MessagEase katakanaCombine.
    private static let katakanaCombineRules = ComposeRuleSet(rules: [
        "゛": [
            "カ": "ガ", "キ": "ギ", "ク": "グ", "ケ": "ゲ", "コ": "ゴ", "サ": "ザ",
            "シ": "ジ", "ス": "ズ", "セ": "ゼ", "ソ": "ゾ", "タ": "ダ", "チ": "ヂ",
            "ツ": "ヅ", "テ": "デ", "ト": "ド", "ハ": "バ", "ヒ": "ビ", "フ": "ブ",
            "ヘ": "ベ", "ホ": "ボ", "ウ": "ヴ", "ワ": "ヷ", "ヰ": "ヸ", "ヱ": "ヹ",
            "ヲ": "ヺ",
        ],
    ])

    // MARK: Korean

    static let korean = LanguageDescriptor(
        id: "ko_KR",
        title: "한국어 (Korean)",
        localeIdentifier: "ko_KR"
    ) { meta in
        GridKeyboardFactory.layout(
            id: meta.id,
            title: meta.title,
            localeIdentifier: meta.localeIdentifier,
            centerCharacters: [
                ["ㄷ", "ㄹ", "ㅈ"],
                ["ㄱ", "ㅇ", "ㄴ"],
                ["ㅁ", "ㅅ", "ㅎ"],
            ],
            directionalOverrides: [
                GridSlot.topLeft: [.swipeDownRight: "ㅌ"],
                GridSlot.topCenter: [.swipeDown: "ㅛ"],
                GridSlot.topRight: [.swipeDownLeft: "ㅊ"],
                GridSlot.midLeft: [.swipeRight: "ㅕ"],
                GridSlot.center: [
                    .swipeUp: "ㅗ", .swipeUpLeft: "ㅔ", .swipeUpRight: "ㅡ",
                    .swipeLeft: "ㅓ", .swipeRight: "ㅏ", .swipeDown: "ㅜ",
                    .swipeDownLeft: "ㅐ", .swipeDownRight: "ㅣ",
                ],
                GridSlot.midRight: [.swipeLeft: "ㅑ"],
                GridSlot.bottomLeft: [.swipeUpRight: "ㅂ"],
                GridSlot.bottomCenter: [.swipeUp: "ㅠ", .swipeRight: "ㅋ"],
                GridSlot.bottomRight: [.swipeUpLeft: "ㅍ"],
            ],
            supportsCapitalization: false,
            numericBackToAlphaLabel: "가나다",
            inputMethod: .hangul
        )
    }
}

// MARK: - Registry

extension LanguageDefinitions {
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
        hindi,
        hiragana,
        italian,
        katakana,
        korean,
        persian,
        polish,
        portuguese,
        russian,
        spanish,
        swedish,
        tagalog,
        thai,
        ukrainian,
        urdu,
        vietnamese,
    ].sorted { $0.title < $1.title }
}
