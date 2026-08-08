//
//  LanguageAlphabetCoverageTests.swift
//  WurstfingerTests
//
//  Content coverage for every layout: the characters a native writer needs must
//  be producible from the definition. `KeyboardDefinition.validate()` checks
//  structure only, so a layout can ship with an untypeable letter and still
//  pass CI.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// One layout's required characters and where that list comes from. Characters
/// a layout knowingly does not provide are named in the entry's comment —
/// never left silent.
private struct AlphabetInventory {
    let id: String
    let source: String
    /// Groups of characters, iterated by Unicode scalar (several of these
    /// scripts use combining marks, which grapheme iteration would fuse with
    /// the preceding letter).
    let groups: [String]
}

struct LanguageAlphabetCoverageTests {
    @Test(arguments: LanguageDefinitions.all)
    func layoutProducesItsAlphabet(descriptor: LanguageDescriptor) throws {
        let inventory = try #require(
            Self.inventories.first(where: { $0.id == descriptor.id }),
            "No alphabet inventory for \(descriptor.id) — add one to `inventories`"
        )
        let producible = Self.producibleText(of: descriptor.makeDefinition())
        let missing = inventory.groups
            .flatMap(\.unicodeScalars)
            .map { String($0) }
            .filter { !producible.contains($0) }
        #expect(
            missing.isEmpty,
            "[\(descriptor.id)] cannot produce \(Self.describe(missing)) — inventory: \(inventory.source)"
        )
    }

    /// Names the missing characters by code point as well: ZWNJ, the Thai tone
    /// marks and the Devanagari matras are invisible on their own.
    private static func describe(_ characters: [String]) -> String {
        characters
            .map { character in
                let scalars = character.unicodeScalars
                    .map { String(format: "U+%04X", $0.value) }
                    .joined(separator: " ")
                return "\(character) (\(scalars))"
            }
            .joined(separator: ", ")
    }

    /// Everything the definition can put into the document: every `commitText`
    /// (primary and return swipe, all modes), every output of a compose rule
    /// whose trigger is actually bound, every sequential-combine result, and
    /// everything reachable from those through the 🅒 accent-cycle key.
    private static func producibleText(of definition: KeyboardDefinition) -> Set<String> {
        var direct: Set<String> = []
        var composeTriggers: Set<String> = []
        for mode in definition.modes.values {
            for key in mode.keys.values {
                for binding in key.bindings.values {
                    collect(binding.action, into: &direct, triggers: &composeTriggers)
                    if let returnAction = binding.returnAction {
                        collect(returnAction, into: &direct, triggers: &composeTriggers)
                    }
                }
            }
        }

        let engine = definition.settings.composeRuleOverrides
            .map { ComposeEngine.withGlobalRules(overrides: $0) } ?? ComposeEngine.shared
        for trigger in composeTriggers {
            if let outputs = engine.ruleSet.rules[trigger]?.values {
                direct.formUnion(outputs)
            }
        }
        if let combine = definition.settings.combineRuleSet {
            for map in combine.rules.values {
                direct.formUnion(map.values)
            }
        }
        return cycleClosure(of: direct, engine: engine)
    }

    private static func collect(
        _ action: KeyAction, into direct: inout Set<String>, triggers: inout Set<String>
    ) {
        switch action {
        case let .commitText(text): direct.insert(text)
        case let .compose(trigger): triggers.insert(trigger)
        default: break
        }
    }

    /// The 🅒 key cycles the character before the cursor through its accent
    /// variants, so everything on a reachable character's cycle is producible.
    private static func cycleClosure(of seeds: Set<String>, engine: ComposeEngine) -> Set<String> {
        var result = seeds
        var pending = Array(seeds)
        while let character = pending.popLast() {
            guard let next = engine.cycleAccent(for: character),
                  result.insert(next).inserted
            else { continue }
            pending.append(next)
        }
        return result
    }

    // MARK: - Inventories

    private static let latin = "abcdefghijklmnopqrstuvwxyz"

    private static let inventories: [AlphabetInventory] = [
        AlphabetInventory(id: "en_US", source: "ISO basic Latin alphabet", groups: [latin]),
        AlphabetInventory(id: "hr_HR", source: "Croatian alphabet (Gaj's Latin)", groups: [latin, "čćđšž"]),
        AlphabetInventory(id: "et_EE", source: "Estonian and Finnish alphabets", groups: [latin, "äöõüšžå"]),
        AlphabetInventory(id: "fi_FI", source: "Finnish alphabet", groups: [latin, "äöå"]),
        AlphabetInventory(
            id: "fr_FR", source: "French accented letters and ligatures",
            groups: [latin, "àâçèéêëîïôùûüÿœæ"]
        ),
        AlphabetInventory(id: "de_DE", source: "German umlauts and ß", groups: [latin, "äöüß"]),
        AlphabetInventory(id: "it_IT", source: "Italian accented vowels", groups: [latin, "àèéìòù"]),
        AlphabetInventory(id: "pl_PL", source: "Polish alphabet", groups: [latin, "ąćęłńóśźż"]),
        AlphabetInventory(id: "pt_PT", source: "Portuguese diacritics", groups: [latin, "àáâãçéêíóôõú"]),
        AlphabetInventory(id: "es_ES", source: "Spanish diacritics", groups: [latin, "áéíñóúü"]),
        AlphabetInventory(id: "ca_ES", source: "Spanish and Catalan diacritics", groups: [latin, "àáçèéíïñòóúü"]),
        AlphabetInventory(id: "sv_SE", source: "Swedish alphabet", groups: [latin, "åäö"]),
        AlphabetInventory(id: "tl_PH", source: "Filipino alphabet", groups: [latin, "ñ"]),
        // Base letters only: the tone marks come from the Telex input method and
        // are covered by TelexTypingTests, not by a binding.
        AlphabetInventory(
            id: "vi_VN", source: "Vietnamese 29-letter alphabet",
            groups: ["abcdeghiklmnopqrstuvxy", "ăâđêôơư"]
        ),
        AlphabetInventory(id: "ru_RU", source: "Russian alphabet", groups: ["абвгдеёжзийклмнопрстуфхцчшщъыьэюя"]),
        AlphabetInventory(id: "uk_UA", source: "Ukrainian alphabet", groups: ["абвгґдеєжзиіїйклмнопрстуфхцчшщьюя"]),
        AlphabetInventory(
            id: "el_GR", source: "Greek alphabet, final sigma, monotonic accented vowels",
            groups: ["αβγδεζηθικλμνξοπρστυφχψω", "ς", "άέήίόύώϊϋΐΰ"]
        ),
        AlphabetInventory(
            id: "he_IL", source: "Hebrew alphabet, final forms, geresh and gershayim",
            groups: ["אבגדהוזחטיכלמנסעפצקרשת", "ךםןףץ", "׳״"]
        ),
        // The tense consonants ㄲㄸㅃㅆㅉ are produced by HangulComposer (typing the
        // base consonant twice), not by a binding — see HangulComposerTests.
        AlphabetInventory(
            id: "ko_KR", source: "Basic jamo plus the complex vowels the layout binds",
            groups: ["ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ", "ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣ", "ㅐㅔㅒㅖ"]
        ),
        AlphabetInventory(
            id: "ar", source: "Arabic alphabet, hamza carriers, Arabic punctuation",
            groups: ["ابتثجحخدذرزسشصضطظعغفقكلمنهوي", "ءآأؤإئةى", "؟،؛٭"]
        ),
        AlphabetInventory(
            id: "fa_IR", source: "Persian alphabet, hamza carriers, ZWNJ, Arabic-script punctuation",
            groups: ["ابپتثجچحخدذرزژسشصضطظعغفقکگلمنوهی", "ءآأؤئةۀ", "؟،؛٭", "\u{200C}"]
        ),
        // The reference layout has no ہ (heh goal) and no ھ (do-chashmi heh)
        // anywhere; adding them would mean inventing positions.
        AlphabetInventory(
            id: "ur", source: "Urdu alphabet as the reference layout defines it",
            groups: ["ابپتٹثجچحخدڈذرڑزژسشصضطظعغفقکگلمنںوی", "ےۓءآؤئۀ", "؟،؛٭", "\u{200C}"]
        ),
        // Without ฅ (khokhon): obsolete, and absent from the reference layout.
        AlphabetInventory(
            id: "th_TH", source: "Thai consonants, vowel signs, tone marks, baht sign",
            groups: [
                "กขฃคฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ", "ฤฦ",
                "ะัาำิีึืุูเแโใไๅ", "็่้๊๋์ํ๎", "ๆฯ฿",
            ]
        ),
        // Without ङ (nga): absent from the reference layout.
        AlphabetInventory(
            id: "hi_IN", source: "Devanagari consonants, vowels, matras, signs, danda, rupee sign",
            groups: [
                "कखगघचछजझञटठडढणतथदधनपफबभमयरलवशषसह", "अआइईउऊऋएऐऑओऔ",
                "ािीुूृॅेैॉोौ्", "ंःँ़", "।₹",
            ]
        ),
        AlphabetInventory(
            id: "ja_JP", source: "Hiragana gojūon, voiced and small kana, Japanese punctuation",
            groups: [
                "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん",
                "がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ", "ぁぃぅぇぉゃゅょっ", "ー、。",
            ]
        ),
        AlphabetInventory(
            id: "ja_JP_katakana", source: "Katakana gojūon, plus small ヮ and the nakaguro separator",
            groups: [
                "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン",
                "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ", "ァィゥェォャュョッヮ", "ー、。・",
            ]
        ),
    ]
}
