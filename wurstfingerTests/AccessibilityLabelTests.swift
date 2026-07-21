//
//  AccessibilityLabelTests.swift
//  WurstfingerTests
//
//  Ensures every key in every mode of every registered language exposes a
//  usable VoiceOver label — i.e. a tap binding with a non-empty label, so the
//  rendered key never falls back to reading the raw slot id ("topLeft", …).
//
//  Complements LayoutValidationTests.allGridKeyTapBindingsAreNonEmpty, which
//  only checks grid keys in the main mode.
//
//  NamedAccessibilityBindingTests below covers the other half: which *non-tap*
//  bindings carry a VoiceOver name. Those names are the opt-in for custom rotor
//  actions, so a suite that only inspects named bindings cannot see the ones
//  that are missing — the set itself has to be pinned.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// Every registered layout, loaded — with the count pinned to the registry.
///
/// A plain `compactMap` over `KeyboardRegistry.available` would let a layout
/// whose `load` returns nil vanish from every pinning test in this file instead
/// of failing one, and the tests would stay green while pinning less. Nothing
/// can drop out today — `available` and the registry's descriptor index are both
/// built from `LanguageDefinitions.all`, and `makeDefinition()` neither throws
/// nor returns an optional — so this guards the silent-drop pattern against the
/// day that stops being true, not a hole in today's suite.
///
/// Throwing (rather than a computed property) is what `#require` needs; every
/// test in both suites below goes through here.
private func loadedDefinitions() throws -> [KeyboardDefinition] {
    let loaded = KeyboardRegistry.available.map {
        (id: $0.id, definition: KeyboardRegistry.load(id: $0.id))
    }
    let missing = loaded.filter { $0.definition == nil }.map(\.id).sorted()
    try #require(
        missing.isEmpty,
        """
        \(missing.count) of \(loaded.count) registered layouts do not load and would \
        silently drop out of these tests: \(missing.joined(separator: ", "))
        """
    )
    return loaded.compactMap(\.definition)
}

struct AccessibilityLabelTests {
    /// Mirrors KeyView's accessibility-label resolution
    /// (custom accessibility label → tap label → slot id fallback).
    private func accessibilityLabel(for key: KeyConfig) -> String {
        if let tap = key.bindings[.tap] {
            return tap.accessibilityLabel ?? tap.label
        }
        return key.id
    }

    @Test func definitionsLoad() throws {
        let definitions = try loadedDefinitions()
        #expect(!definitions.isEmpty, "Expected registered languages to load")
    }

    @Test func everyKeyHasATapBinding() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    #expect(
                        key.bindings[.tap] != nil,
                        "\(def.id)/\(modeName)/\(keyId) has no .tap binding — VoiceOver would read the raw slot id"
                    )
                }
            }
        }
    }

    @Test func everyKeyHasANonEmptyAccessibilityLabel() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let label = accessibilityLabel(for: key)
                    #expect(
                        !label.isEmpty,
                        "\(def.id)/\(modeName)/\(keyId) resolves to an empty accessibility label"
                    )
                }
            }
        }
    }

    @Test func accessibilityLabelNeverFallsBackToSlotId() throws {
        let slotIds = Set(GridSlot.allSlots.flatMap(\.self))
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys where slotIds.contains(keyId) {
                    let label = accessibilityLabel(for: key)
                    #expect(
                        label != keyId,
                        "\(def.id)/\(modeName)/\(keyId) accessibility label is the raw slot id"
                    )
                }
            }
        }
    }

    // MARK: - Operability without gestures

    /// VoiceOver activates a key by synthesizing a tap, so a key whose tap is
    /// inert is unreachable unless it declares a substitute gesture. Also the
    /// guard for the derived modes: shifted/capsLock keys are made by copying,
    /// so a copy site that drops the declaration fails here.
    @Test func everyKeyIsOperableWithoutGestures() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let tapAction: KeyAction = key.bindings[.tap]?.action ?? .none
                    #expect(
                        tapAction != .none || key.accessibilityActivationOverride != nil,
                        "\(def.id)/\(modeName)/\(keyId) has an inert tap and no accessibility activation"
                    )
                }
            }
        }
    }

    /// The globe's tap opens (and closes) the emoji layer, so an assistive
    /// activation already does something and needs no substitute gesture —
    /// `accessibilityActivationOverride` is nil by design here. The
    /// input-method switch it used to stand in for stays reachable as the
    /// named custom action carried by the swipe-left binding's label.
    @Test func globeOffersTheInputModeSwitchAsACustomAction() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                guard let globe = mode.keys[UtilitySlot.globe] else { continue }
                // Annotated so `.none` reads as the key action, not `Optional.none`.
                let tapAction: KeyAction = globe.bindings[.tap]?.action ?? .none
                #expect(
                    tapAction != .none,
                    "\(def.id)/\(modeName) globe tap is inert — activation would do nothing"
                )
                #expect(
                    globe.accessibilityActivationOverride == nil,
                    "\(def.id)/\(modeName) globe substitutes a gesture although its tap is live"
                )
                #expect(globe.bindings[.swipeLeft]?.action == .advanceToNextInputMode)
                #expect(
                    globe.accessibilityActions.contains { $0.gesture == .swipeLeft },
                    "\(def.id)/\(modeName) globe does not offer the input-mode switch as an action"
                )
            }
        }
    }

    /// Reachability is by name, not by gesture: bindings sharing a label
    /// collapse into one rotor entry, so the entry must dispatch the same
    /// action for every gesture that folded into it.
    @Test func everyLabelledNonTapBindingIsReachableAsAnAction() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let offered = Dictionary(
                        key.accessibilityActions.map { ($0.name, $0.gesture) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    for (gesture, binding) in key.bindings
                        where gesture != .tap && binding.action != .none {
                        guard let label = binding.accessibilityLabel, !label.isEmpty else { continue }
                        guard gesture != key.accessibilityActivationOverride else { continue }
                        let origin = "\(def.id)/\(modeName)/\(keyId) \(gesture)"
                        guard let offeredGesture = offered[label] else {
                            Issue.record("\(origin) is named \"\(label)\" but unreachable")
                            continue
                        }
                        #expect(
                            key.bindings[offeredGesture]?.action == binding.action,
                            "\(origin) folds into \"\(label)\", which dispatches a different action"
                        )
                    }
                }
            }
        }
    }

    /// Cut-all is bound to both circle directions under one name; two
    /// identical rotor entries read as a bug.
    @Test func accessibilityActionNamesAreUnique() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let names = key.accessibilityActions.map(\.name)
                    #expect(
                        Set(names).count == names.count,
                        "\(def.id)/\(modeName)/\(keyId) offers duplicate action names: \(names)"
                    )
                }
            }
        }
    }

    /// End to end through the real resolver chain and pipeline: the gesture the
    /// globe offers under the "switch keyboard" name has to actually reach the
    /// input-mode switch.
    @Test func globeInputModeActionReachesTheInputModeSwitch() throws {
        var advanced = 0
        let (viewModel, _) = makeViewModel(advanceToNextInputMode: { advanced += 1 })
        let globe = try #require(viewModel.activeModeFromDefinition?.key(for: UtilitySlot.globe))
        let action = try #require(globe.accessibilityActions.first { $0.gesture == .swipeLeft })
        viewModel.handleGesture(action.gesture, keyId: UtilitySlot.globe, isReturn: false)
        #expect(advanced == 1)
    }
}

// MARK: - Which bindings are named

/// Pins the *set* of named bindings, not just the ones that happen to be named.
///
/// A VoiceOver name is the opt-in for a custom action, so the suite could only
/// ever see bindings that already had one — the swipe-only punctuation and shift
/// gap was therefore structurally invisible to it. The table below writes the
/// policy out, and both directions of a regression now fail: a name silently
/// dropped, and a name silently added (the rotor flooding the opt-in exists to
/// prevent). The reasoning behind the selection lives on
/// `CommonKeys.defaultSlotBindings`.
struct NamedAccessibilityBindingTests {
    /// Every grid-key gesture allowed to carry a name. Letter gestures are
    /// absent on purpose: a key's own center letter is reachable by activating
    /// it, and naming the other eight on all nine keys is the flooding case.
    private static let namedGridGestures: [String: Set<GestureType>] = [
        GridSlot.topRight: [.swipeLeft], // ?
        GridSlot.bottomCenter: [.swipeDown, .swipeDownLeft], // . and ,
        GridSlot.midRight: [.swipeUp, .swipeDown], // ⇧ and ⇩
    ]

    /// The three sentence-punctuation gestures. A layout may substitute its own
    /// script's mark here (Arabic ؟ ،, Japanese 。 、) and the name follows,
    /// because it states the function rather than the glyph.
    private static let sentencePunctuation: [(slot: String, gesture: GestureType)] = [
        (GridSlot.topRight, .swipeLeft),
        (GridSlot.bottomCenter, .swipeDown),
        (GridSlot.bottomCenter, .swipeDownLeft),
    ]

    private static let gridSlotIds = Set(GridSlot.allSlots.flatMap(\.self))

    /// Non-tap gestures of a key that carry a non-empty name. The tap is the
    /// element's own label, not a custom action, so it is never in here.
    private func namedGestures(of key: KeyConfig) -> Set<GestureType> {
        Set(
            key.bindings
                .filter { $0.key != .tap && !($0.value.accessibilityLabel ?? "").isEmpty }
                .keys
        )
    }

    private func requireBinding(
        _ languageId: String, _ modeName: String, _ keyId: String, _ gesture: GestureType
    ) throws -> KeyBinding {
        let definition = try #require(
            KeyboardRegistry.load(id: languageId), "\(languageId) does not load"
        )
        let mode = try #require(definition.modes[modeName], "\(languageId) has no \(modeName) mode")
        let key = try #require(mode.keys[keyId], "\(languageId)/\(modeName) has no \(keyId) key")
        return try #require(
            key.bindings[gesture], "\(languageId)/\(modeName)/\(keyId) has no \(gesture) binding"
        )
    }

    @Test func noGridBindingIsNamedOutsideThePolicySet() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys where Self.gridSlotIds.contains(keyId) {
                    let unexpected = namedGestures(of: key)
                        .subtracting(Self.namedGridGestures[keyId] ?? [])
                    let listed = unexpected.map { "\($0)" }.sorted().joined(separator: ", ")
                    #expect(
                        unexpected.isEmpty,
                        """
                        \(def.id)/\(modeName)/\(keyId) names [\(listed)] — every name is a rotor entry, \
                        so extend namedGridGestures deliberately or drop the label
                        """
                    )
                }
            }
        }
    }

    /// The gap the review found: `, . ?` were swipe-only and had no name, so a
    /// VoiceOver user could not end a sentence at all.
    @Test func sentencePunctuationIsNamedInEveryModeOfEveryLayout() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (slot, gesture) in Self.sentencePunctuation {
                    // A layout is free to place a letter here instead; only the
                    // punctuation this slot normally carries has to be named.
                    guard let binding = mode.keys[slot]?.bindings[gesture],
                          binding.resolvedCategory == .symbol
                    else { continue }
                    #expect(
                        !(binding.accessibilityLabel ?? "").isEmpty,
                        "\(def.id)/\(modeName)/\(slot) \(gesture) commits \"\(binding.label)\" unnamed"
                    )
                }
            }
        }
    }

    /// Deliberate capitalization: auto-capitalization only produces
    /// sentence-initial capitals, so without a name the modifier is unreachable.
    ///
    /// A binding that switches to the mode it already lives in is the one
    /// exception, pinned separately below.
    @Test func theShiftAffordanceIsNamedWhereverItExists() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for gesture in [GestureType.swipeUp, .swipeDown] {
                    guard let binding = mode.keys[GridSlot.midRight]?.bindings[gesture],
                          case let .switchMode(target) = binding.action,
                          target != modeName
                    else { continue }
                    #expect(
                        !(binding.accessibilityLabel ?? "").isEmpty,
                        "\(def.id)/\(modeName) midRight \(gesture) switches mode unnamed"
                    )
                }
            }
        }
    }

    /// The counterpart: naming a binding is what puts it in the rotor, so a
    /// binding that switches to the mode it is invoked from must stay unnamed.
    /// The caps-lock `⇪` is the only one — activating it would return the
    /// VoiceOver user exactly where they were.
    @Test func aModeSwitchOntoItsOwnModeOffersNoAction() throws {
        for def in try loadedDefinitions() {
            for (modeName, mode) in def.modes {
                for (gesture, binding) in mode.keys[GridSlot.midRight]?.bindings ?? [:] {
                    guard case let .switchMode(target) = binding.action, target == modeName
                    else { continue }
                    #expect(
                        binding.accessibilityLabel == nil,
                        "\(def.id)/\(modeName) midRight \(gesture) names a switch onto its own mode"
                    )
                }
            }
        }
    }

    /// Why `⇩` is named alongside `⇧`: in the caps-lock mode the `⇧` gesture
    /// switches to the mode it is already in, so `⇩` is the only way out. Naming
    /// only `⇧` would hand VoiceOver users a one-way door into caps lock.
    @Test func capsLockIsNotAOneWayDoorForVoiceOver() throws {
        for def in try loadedDefinitions() {
            guard let capsLock = def.modes[ModeNames.capsLock] else { continue }
            let midRight = try #require(
                capsLock.keys[GridSlot.midRight], "\(def.id) caps lock has no midRight key"
            )
            let exits = midRight.accessibilityActions.filter { action in
                midRight.bindings[action.gesture]?.action == .switchMode(ModeNames.main)
            }
            #expect(
                !exits.isEmpty,
                "\(def.id) caps lock offers no named action back to the main mode"
            )
        }
    }

    /// Finding 11: VoiceOver read "123" as the number one hundred twenty-three
    /// and "abc"/"абв"/"कखग" as a word, instead of naming what the key does.
    @Test func theModeSwitchKeysAreNamedSemantically() throws {
        for def in try loadedDefinitions() {
            let toNumeric = try requireBinding(def.id, ModeNames.main, UtilitySlot.symbols, .tap)
            let toLetters = try requireBinding(def.id, ModeNames.numeric, UtilitySlot.symbols, .tap)
            for (key, mode) in [(toNumeric, ModeNames.main), (toLetters, ModeNames.numeric)] {
                let name = key.accessibilityLabel ?? ""
                #expect(!name.isEmpty, "\(def.id)/\(mode) symbols key falls back to its glyph label")
                #expect(
                    name != key.label,
                    "\(def.id)/\(mode) symbols key names itself \"\(name)\" — that is the glyph, not the function"
                )
            }
            #expect(
                toNumeric.accessibilityLabel != toLetters.accessibilityLabel,
                "\(def.id) uses one name for both directions of the numeric mode switch"
            )
        }
    }

    /// The names state the function, so a layout substituting its own script's
    /// mark inherits them — otherwise exactly the RTL and CJK users the labelling
    /// was for would be left with unnamed keys.
    @Test func aScriptsOwnMarkInheritsTheSharedPunctuationName() throws {
        let questionMark = try requireBinding("de_DE", ModeNames.main, GridSlot.topRight, .swipeLeft)
        let period = try requireBinding("de_DE", ModeNames.main, GridSlot.bottomCenter, .swipeDown)
        let comma = try requireBinding("de_DE", ModeNames.main, GridSlot.bottomCenter, .swipeDownLeft)

        let arabicQuestionMark = try requireBinding("ar", ModeNames.main, GridSlot.topRight, .swipeLeft)
        #expect(arabicQuestionMark.label == "؟")
        #expect(arabicQuestionMark.accessibilityLabel == questionMark.accessibilityLabel)

        let arabicComma = try requireBinding("ar", ModeNames.main, GridSlot.bottomCenter, .swipeDownLeft)
        #expect(arabicComma.label == "،")
        #expect(arabicComma.accessibilityLabel == comma.accessibilityLabel)

        let japanesePeriod = try requireBinding("ja_JP", ModeNames.main, GridSlot.bottomCenter, .swipeDown)
        #expect(japanesePeriod.label == "。")
        #expect(japanesePeriod.accessibilityLabel == period.accessibilityLabel)

        let japaneseComma = try requireBinding("ja_JP", ModeNames.main, GridSlot.bottomCenter, .swipeDownLeft)
        #expect(japaneseComma.label == "、")
        #expect(japaneseComma.accessibilityLabel == comma.accessibilityLabel)
    }

    /// The two guards on that inheritance. A letter must not inherit a
    /// punctuation name ("Comma" would be a lie on て), and a mark that displaces
    /// a *mode switch* must not inherit its name — Hindi's danda sits on the
    /// midRight `⇩` gesture and is a full stop, not the way out of caps lock.
    @Test func inheritedNamesStopAtLettersAndAtModeSwitches() throws {
        let japaneseLetter = try requireBinding("ja_JP", ModeNames.main, GridSlot.bottomCenter, .swipeUp)
        #expect(japaneseLetter.label == "て")
        #expect(japaneseLetter.accessibilityLabel == nil)

        let danda = try requireBinding("hi_IN", ModeNames.main, GridSlot.midRight, .swipeDown)
        #expect(danda.label == "।")
        #expect(danda.accessibilityLabel == nil)
    }
}
