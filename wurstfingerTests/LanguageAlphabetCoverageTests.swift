//
//  LanguageAlphabetCoverageTests.swift
//  WurstfingerTests
//
//  Content coverage for every layout: the characters a native writer needs must
//  be producible from the definition. `KeyboardDefinition.validate()` checks
//  structure only, so a layout can ship with an untypeable letter and still
//  pass CI.
//
//  Coverage alone is not enough, though: the 🅒 accent cycle reaches almost
//  every Latin variant from its base letter, so "reachable" would still hold
//  after a layout lost a key. The tests below therefore pin the *route* — a
//  character is expected to have a key of its own unless its inventory names
//  the detour it takes instead.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// How a definition puts a character into the document, from the most direct
/// route to the least. `ReachabilityIndex.route(for:)` always reports the best
/// available one, so a character that still has a key never looks like a
/// compose-key or cycle character.
private enum CharacterRoute: CustomStringConvertible {
    /// A key commits the character outright — one gesture, in some mode.
    case keyBinding
    /// A compose (dead) key the layout binds, plus the base letter: `¨` then
    /// `e` gives `ë`. Two deliberate gestures, both discoverable from the hints.
    case composeKey
    /// The layout's own sequential-combine table, e.g. kana + `゛` → voiced kana.
    /// Like `composeKey`, but driven by a committed character rather than a
    /// `.compose` action.
    case combineRule
    /// The 🅒 key alone: type the base letter, then tap 🅒 until the variant
    /// comes up. Everything on a reachable character's accent cycle qualifies,
    /// which makes this the weakest possible claim — the position in the cycle
    /// is neither shown nor stable, so a layout may only lean on it for
    /// characters its script barely uses.
    case accentCycle

    var description: String {
        switch self {
        case .keyBinding: "a key binding"
        case .composeKey: "a compose key"
        case .combineRule: "a combine rule"
        case .accentCycle: "the 🅒 accent cycle"
        }
    }
}

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
    /// The characters from `groups` that deliberately have **no key of their
    /// own**, mapped to the route that produces them instead. Everything not
    /// listed here must be committed by a binding.
    ///
    /// This is an allowlist, and the test enforces it in both directions: a
    /// character listed here that regains a key fails just as loudly as one
    /// that loses it. Keeping it exact is the point — an entry that covered
    /// more than it has to would hand back exactly the hole it closes, because
    /// the accent cycle reaches nearly every Latin variant.
    var indirectRoutes: [CharacterRoute: String] = [:]
}

struct LanguageAlphabetCoverageTests {
    @Test(arguments: LanguageDefinitions.all)
    func layoutProducesItsAlphabet(descriptor: LanguageDescriptor) throws {
        let inventory = try #require(
            Self.inventories.first(where: { $0.id == descriptor.id }),
            "No alphabet inventory for \(descriptor.id) — add one to `inventories`"
        )
        let index = Self.reachability(of: descriptor.makeDefinition())
        let missing = Self.requiredCharacters(of: inventory).filter { index.route(for: $0) == nil }
        #expect(
            missing.isEmpty,
            "[\(descriptor.id)] cannot produce \(Self.describe(missing)) — inventory: \(inventory.source)"
        )
    }

    /// The cycle-closure guard: every required character needs a key unless the
    /// inventory declares the detour. Without this, dropping a letter's binding
    /// stays invisible — `é` would simply fall back to the acute compose key,
    /// `ż` to a few taps on 🅒, and coverage would still pass.
    @Test(arguments: LanguageDefinitions.all)
    func layoutBindsEveryCharacterItDoesNotDeclareAsIndirect(descriptor: LanguageDescriptor) throws {
        let inventory = try #require(
            Self.inventories.first(where: { $0.id == descriptor.id }),
            "No alphabet inventory for \(descriptor.id) — add one to `inventories`"
        )
        let index = Self.reachability(of: descriptor.makeDefinition())
        let required = Self.requiredCharacters(of: inventory)

        // The table itself has to stay meaningful: no character under two
        // routes (the expectation would depend on dictionary order), and no
        // leftover entry for a character the inventory stopped requiring.
        let declaredCharacters = inventory.indirectRoutes.values.flatMap(\.unicodeScalars).map { String($0) }
        #expect(
            Set(declaredCharacters).count == declaredCharacters.count,
            "[\(descriptor.id)] a character appears under two routes in `indirectRoutes`"
        )
        let strays = declaredCharacters.filter { !required.contains($0) }
        #expect(
            strays.isEmpty,
            "[\(descriptor.id)] `indirectRoutes` names \(Self.describe(strays)), which this inventory does not require"
        )

        let declared = Self.declaredRoutes(of: inventory)
        let mismatches = required.compactMap { character -> String? in
            // Unreachable characters are `layoutProducesItsAlphabet`'s report.
            guard let actual = index.route(for: character) else { return nil }
            let expected = declared[character] ?? .keyBinding
            guard actual != expected else { return nil }
            return "\(Self.describe(character)) declared as \(expected), reachable via \(actual)"
        }
        #expect(
            mismatches.isEmpty,
            """
            [\(descriptor.id)] \(mismatches.joined(separator: "; ")). \
            Either restore whatever produced it, or record the route it really takes \
            in the inventory's `indirectRoutes` — with a comment saying why.
            """
        )
    }

    // MARK: - Reachability

    /// Every route a definition offers, kept apart instead of merged into one
    /// "producible" set so the tests can tell a key from a fallback.
    private struct ReachabilityIndex {
        /// Characters some key commits outright (primary or return swipe, any mode).
        let bound: Set<String>
        /// Outputs of the compose triggers this layout actually binds.
        let composed: Set<String>
        /// Outputs of the layout's sequential-combine table.
        let combined: Set<String>
        /// Closure of all of the above under the 🅒 accent cycle.
        let cycled: Set<String>

        func route(for character: String) -> CharacterRoute? {
            if bound.contains(character) { return .keyBinding }
            if composed.contains(character) { return .composeKey }
            if combined.contains(character) { return .combineRule }
            if cycled.contains(character) { return .accentCycle }
            return nil
        }
    }

    private static func reachability(of definition: KeyboardDefinition) -> ReachabilityIndex {
        var bound: Set<String> = []
        var composeTriggers: Set<String> = []
        for mode in definition.modes.values {
            for key in mode.keys.values {
                for binding in key.bindings.values {
                    collect(binding.action, into: &bound, triggers: &composeTriggers)
                    if let returnAction = binding.returnAction {
                        collect(returnAction, into: &bound, triggers: &composeTriggers)
                    }
                }
            }
        }

        let engine = definition.settings.composeRuleOverrides
            .map { ComposeEngine.withGlobalRules(overrides: $0) } ?? ComposeEngine.shared
        var composed: Set<String> = []
        for trigger in composeTriggers {
            if let outputs = engine.ruleSet.rules[trigger]?.values {
                composed.formUnion(outputs)
            }
        }
        // A combine rule fires on a *committed* trigger character (kana + ゛),
        // so its outputs only count while the layout still binds that trigger —
        // otherwise losing the ゛ key would leave the voiced kana looking
        // producible.
        var combined: Set<String> = []
        if let combine = definition.settings.combineRuleSet {
            for (trigger, map) in combine.rules where bound.contains(trigger) {
                combined.formUnion(map.values)
            }
        }

        return ReachabilityIndex(
            bound: bound, composed: composed, combined: combined,
            cycled: cycleClosure(of: bound.union(composed).union(combined), engine: engine)
        )
    }

    private static func collect(
        _ action: KeyAction, into bound: inout Set<String>, triggers: inout Set<String>
    ) {
        switch action {
        case let .commitText(text): bound.insert(text)
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

    // MARK: - Inventory helpers

    private static func requiredCharacters(of inventory: AlphabetInventory) -> [String] {
        inventory.groups.flatMap(\.unicodeScalars).map { String($0) }
    }

    /// Flattens `indirectRoutes` into a character → route lookup. Double
    /// declarations are caught by the caller, which can report them; here the
    /// last one simply wins.
    private static func declaredRoutes(of inventory: AlphabetInventory) -> [String: CharacterRoute] {
        var routes: [String: CharacterRoute] = [:]
        for (route, characters) in inventory.indirectRoutes {
            for scalar in characters.unicodeScalars {
                routes[String(scalar)] = route
            }
        }
        return routes
    }

    /// Names the missing characters by code point as well: ZWNJ, the Thai tone
    /// marks and the Devanagari matras are invisible on their own.
    private static func describe(_ characters: [String]) -> String {
        characters.map(describe).joined(separator: ", ")
    }

    private static func describe(_ character: String) -> String {
        let scalars = character.unicodeScalars
            .map { String(format: "U+%04X", $0.value) }
            .joined(separator: " ")
        return "\(character) (\(scalars))"
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
            groups: [latin, "àâçèéêëîïôùûüÿœæ"],
            // The main mode spends its ¨ slot on ê, so the diaeresis sits
            // on the numeric mode's punctuation ring — ë ï ü ÿ come from there,
            // î ô from the circumflex key. œ and æ are outputs of the `!` compose
            // table, which no key triggers (see `ComposeRuleSet.global`), leaving
            // the cycle as their only route.
            indirectRoutes: [.composeKey: "ëîïôüÿ", .accentCycle: "œæ"]
        ),
        AlphabetInventory(id: "de_DE", source: "German umlauts and ß", groups: [latin, "äöüß"]),
        AlphabetInventory(id: "it_IT", source: "Italian accented vowels", groups: [latin, "àèéìòù"]),
        AlphabetInventory(id: "pl_PL", source: "Polish alphabet", groups: [latin, "ąćęłńóśźż"]),
        AlphabetInventory(
            id: "pt_PT", source: "Portuguese diacritics", groups: [latin, "àáâãçéêíóôõú"],
            // à is the rarest Portuguese diacritic (the crasis contraction), so
            // the layout keeps the key for á and leaves à to the grave key.
            indirectRoutes: [.composeKey: "à"]
        ),
        AlphabetInventory(id: "es_ES", source: "Spanish diacritics", groups: [latin, "áéíñóúü"]),
        AlphabetInventory(
            id: "ca_ES", source: "Spanish and Catalan diacritics", groups: [latin, "àáçèéíïñòóúü"],
            // Shared Spanish/Catalan layout: the nine keys carry the Spanish
            // acutes, and the two Catalan-only graves ride on the grave key.
            indirectRoutes: [.composeKey: "èò"]
        ),
        AlphabetInventory(id: "sv_SE", source: "Swedish alphabet", groups: [latin, "åäö"]),
        AlphabetInventory(id: "tl_PH", source: "Filipino alphabet", groups: [latin, "ñ"]),
        // Base letters only: the tone marks come from the Telex input method and
        // are covered by TelexTypingTests, not by a binding.
        AlphabetInventory(
            id: "vi_VN", source: "Vietnamese 29-letter alphabet",
            groups: ["abcdeghiklmnopqrstuvxy", "ăâđêôơư"],
            // The modified vowels have no keys either: Telex types them as
            // aa/ee/oo (circumflex) and aw/ow/uw (breve and horn), which
            // TelexTypingTests pins. The circumflex three double as compose-key
            // output; the breve and horn three are only on the accent cycle,
            // because neither `˘` nor a horn trigger is bound anywhere.
            indirectRoutes: [.composeKey: "âêô", .accentCycle: "ăơư"]
        ),
        AlphabetInventory(id: "ru_RU", source: "Russian alphabet", groups: ["абвгдеёжзийклмнопрстуфхцчшщъыьэюя"]),
        AlphabetInventory(id: "uk_UA", source: "Ukrainian alphabet", groups: ["абвгґдеєжзиіїйклмнопрстуфхцчшщьюя"]),
        AlphabetInventory(
            id: "el_GR", source: "Greek alphabet, final sigma, monotonic accented vowels",
            groups: ["αβγδεζηθικλμνξοπρστυφχψω", "ς", "άέήίόύώϊϋΐΰ"],
            // Monotonic Greek accents every stressed vowel, so binding all of
            // them would cost more slots than the grid has: the tonos vowels
            // come from the acute key, the dialytika ones from the diaeresis key
            // (ΐ and ΰ from either, applied to the other mark's output).
            indirectRoutes: [.composeKey: "άέήίόύώϊϋΐΰ"]
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
            id: "ja_JP", source: "Hiragana gojūon, voiced and small kana, iteration marks, Japanese punctuation",
            groups: [
                "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん",
                "がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ", "ぁぃぅぇぉゃゅょっ", "ゝゞ", "ー、。",
            ],
            // Voicing is a key of its own (゛) rather than 21 more slots: the
            // dakuten kana come from `hiraganaCombineRules`, a second ゛ cascades
            // the ha row on to its handakuten form. ぐ ず ど ぶ are the exception —
            // the reference layout does put those four on keys.
            indirectRoutes: [.combineRule: "がぎげござじぜぞだぢづでばびべぼぱぴぷぺぽ"]
        ),
        AlphabetInventory(
            id: "ja_JP_katakana",
            source: "Katakana gojūon, iteration marks, plus small ヮ and the nakaguro separator",
            groups: [
                "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン",
                "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ", "ァィゥェォャュョッヮ", "ヽヾ", "ー、。・",
            ],
            // Same voicing story as hiragana, via `katakanaCombineRules`;
            // グ ズ ド ブ are the four the reference layout binds directly.
            indirectRoutes: [.combineRule: "ガギゲゴザジゼゾダヂヅデバビベボパピプペポ"]
        ),
    ]
}
