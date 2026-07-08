//
//  EmojiModeTests.swift
//  WurstfingerTests
//
//  Tests for the emoji keyboard mode (direct-select emoji layer).
//

import Foundation
import Testing
@testable import WurstfingerApp

struct EmojiModeTests {
    private let mode = EmojiLayouts.mode()

    // MARK: - Mode Structure

    @Test func everyLanguageDefinitionContainsEmojiMode() {
        for descriptor in LanguageDefinitions.all {
            let definition = descriptor.makeDefinition()
            #expect(definition.mode(ModeNames.emoji) != nil, "\(definition.id) is missing the emoji mode")
        }
    }

    @Test func emojiModeValidates() {
        #expect(mode.validate().isEmpty)
    }

    @Test func hasTwelveDirectSelectEmojiKeys() {
        let emojiSlots = Array(EmojiLayouts.slotRows.joined())
        #expect(emojiSlots.count == 12)

        var seen = Set<String>()
        for slotId in emojiSlots {
            guard let key = mode.key(for: slotId) else {
                Issue.record("missing key for \(slotId)")
                continue
            }
            // Direct select: exactly one tap binding, no swipes.
            #expect(key.bindings.count == 1)
            let tap = key.bindings[.tap]
            #expect(tap != nil)
            if let tap, case let .commitText(emoji) = tap.action {
                #expect(tap.label == emoji)
                seen.insert(emoji)
            } else {
                Issue.record("\(slotId) tap binding must commit text")
            }
        }
        #expect(seen.count == 12, "all 12 emojis must be unique")
    }

    @Test func emojiLabelsAreNeverHidden() throws {
        let key = try #require(mode.key(for: GridSlot.center))
        let tap = try #require(key.bindings[.tap])
        #expect(tap.resolvedCategory == .emoji)
        #expect(LabelCategory.of(tap) == .functional)
        #expect(LabelCategory.of(tap).isVisible(
            hideLetters: true, hideStandardSymbols: true, hideExtraSymbols: true
        ))
    }

    @Test func stayingInEmojiModeAfterCommit() {
        // Empty autoTransitions — several emojis can be sent in a row.
        #expect(mode.autoTransitions.isEmpty)
        #expect(mode.nextMode(after: .emoji) == nil)
    }

    // MARK: - Arrangement

    @Test func arrangementSplitsSpaceRowIntoEmojiKeys() throws {
        let arrangement = try #require(mode.arrangement(for: .portrait))
        let placedIds = arrangement.rows.flatMap { $0.map(\.keyId) }
        #expect(!placedIds.contains(UtilitySlot.space))
        for slotId in EmojiLayouts.slotRows.joined() {
            #expect(placedIds.contains(slotId))
        }
        for utility in [UtilitySlot.globe, UtilitySlot.symbols, UtilitySlot.delete, UtilitySlot.return] {
            #expect(placedIds.contains(utility))
        }
    }

    @Test func landscapeFallsBackToPortraitShape() throws {
        let landscape = try #require(mode.arrangement(for: .landscape))
        let portrait = try #require(mode.arrangement(for: .portrait))
        #expect(landscape == portrait)
    }

    // MARK: - Entry and Exit

    @Test func globeTapOpensEmojiMode() throws {
        let binding = try #require(CommonKeys.globe.bindings[.tap])
        #expect(binding.action == .switchMode(ModeNames.emoji))
        // The entry label stays visible under all label-hiding toggles.
        #expect(LabelCategory.of(binding) == .functional)
    }

    @Test func emojiEntryKeepsGlobeSwipes() {
        let bindings = CommonKeys.globe.bindings
        #expect(bindings[.swipeLeft]?.action == .advanceToNextInputMode)
        #expect(bindings[.swipeDown]?.action == .dismissKeyboard)
        #expect(bindings[.swipeRight]?.action == .switchToNextLanguage)
    }

    @Test func backKeyReturnsToMainMode() throws {
        let backKey = try #require(mode.key(for: UtilitySlot.symbols))
        let tap = try #require(backKey.bindings[.tap])
        #expect(tap.action == .switchMode(ModeNames.main))
        #expect(tap.label == NumericLayouts.defaultBackToAlphaLabel)
    }

    @Test func backKeyUsesLanguageSpecificLabel() throws {
        let hebrew = LanguageDefinitions.hebrew.makeDefinition()
        let emojiMode = try #require(hebrew.mode(ModeNames.emoji))
        let backKey = try #require(emojiMode.key(for: UtilitySlot.symbols))
        #expect(backKey.bindings[.tap]?.label == hebrew.numericBackToAlphaLabel)
    }
}
