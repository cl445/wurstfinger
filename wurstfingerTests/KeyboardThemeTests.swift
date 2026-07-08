//
//  KeyboardThemeTests.swift
//  WurstfingerTests
//
//  Covers hex color parsing/formatting, the built-in theme presets, and the
//  fallback behavior of the settings-driven KeyboardTheme initializer.
//

import SwiftUI
import Testing
@testable import WurstfingerApp

struct HexColorTests {
    @Test func parsesHashPrefixedHex() {
        #expect(HexColor.parse("#333A48") == 0x333A48)
    }

    @Test func parsesBareAndLowercaseHex() {
        #expect(HexColor.parse("d1aa05") == 0xD1AA05)
        #expect(HexColor.parse("#ffffff") == 0xFFFFFF)
    }

    @Test func rejectsInvalidHex() {
        #expect(HexColor.parse("") == nil)
        #expect(HexColor.parse("#12345") == nil)
        #expect(HexColor.parse("#1234567") == nil)
        #expect(HexColor.parse("not a color") == nil)
        #expect(HexColor.parse("#GGGGGG") == nil)
    }

    @Test func colorRoundTripsThroughHexString() throws {
        let original: UInt32 = 0x333A48
        let string = try #require(HexColor.string(from: Color(hexRGB: original)))
        #expect(HexColor.parse(string) == original)
    }

    @Test func scalingDarkensAndClamps() {
        #expect(HexColor.scaled(0xFFFFFF, by: 0.5) == 0x7F7F7F)
        #expect(HexColor.scaled(0x000000, by: 0.5) == 0x000000)
        #expect(HexColor.scaled(0xFFFFFF, by: 2.0) == 0xFFFFFF)
    }

    @Test func luminanceOrdersLightAndDark() {
        #expect(HexColor.luminance(of: 0xFFFFFF) > 0.9)
        #expect(HexColor.luminance(of: 0x000000) < 0.1)
        #expect(HexColor.luminance(of: 0x333A48) < 0.5)
        #expect(HexColor.luminance(of: 0xE1CF04) > 0.5)
    }
}

struct KeyboardThemePresetTests {
    @Test func allPresetsHaveParsableColors() {
        for preset in KeyboardThemePreset.all {
            #expect(HexColor.parse(preset.keyHex) != nil, "preset \(preset.id) keyHex")
            #expect(HexColor.parse(preset.mainHex) != nil, "preset \(preset.id) mainHex")
            #expect(HexColor.parse(preset.hintHex) != nil, "preset \(preset.id) hintHex")
            #expect(HexColor.parse(preset.pressedHex) != nil, "preset \(preset.id) pressedHex")
        }
    }

    @Test func presetIdsMatchOriginalOrder() {
        #expect(KeyboardThemePreset.all.count == 16)
        #expect(KeyboardThemePreset.all.map(\.id) == Array(0 ..< 16))
    }

    @Test func standardPresetIsMessagEaseDefault() {
        // Theme 12 is DEFAULT_COLOR_INDEX in the original app.
        #expect(KeyboardThemePreset.standard.id == 12)
        #expect(HexColor.parse(KeyboardThemePreset.standard.keyHex) == 0x333A48)
        #expect(HexColor.parse(KeyboardThemePreset.standard.mainHex) == 0xD1AA05)
    }
}

struct KeyboardThemeTests {
    @Test func unparsableHexFallsBackToStandardPalette() {
        let broken = KeyboardTheme(
            keyHex: "garbage",
            mainHex: "",
            hintHex: "#12345",
            pressedHex: "#GGGGGG",
            cornerRadius: KeyboardTheme.defaultCornerRadius,
            showKeyEdges: KeyboardTheme.defaultShowKeyEdges
        )
        #expect(broken == KeyboardTheme.messagEase)
    }

    @Test func keyEdgesToggleControlsBorderWidth() {
        let preset = KeyboardThemePreset.standard
        let withEdges = KeyboardTheme(
            keyHex: preset.keyHex, mainHex: preset.mainHex, hintHex: preset.hintHex,
            pressedHex: preset.pressedHex, cornerRadius: 8, showKeyEdges: true
        )
        let withoutEdges = KeyboardTheme(
            keyHex: preset.keyHex, mainHex: preset.mainHex, hintHex: preset.hintHex,
            pressedHex: preset.pressedHex, cornerRadius: 8, showKeyEdges: false
        )
        #expect(withEdges.keyBorderWidth == 0.5)
        #expect(withoutEdges.keyBorderWidth == 0)
    }

    @Test func cornerRadiusIsCarriedThrough() {
        let preset = KeyboardThemePreset.standard
        let theme = KeyboardTheme(
            keyHex: preset.keyHex, mainHex: preset.mainHex, hintHex: preset.hintHex,
            pressedHex: preset.pressedHex, cornerRadius: 0, showKeyEdges: true
        )
        #expect(theme.cornerRadius == 0)
    }

    @Test func boardBackgroundIsDarkerThanKeys() {
        // The derived board fill must differ from the key fill so the
        // inter-key gaps stay visible as grid lines.
        let board = KeyboardTheme.boardBackground(forKeyHex: "#333A48")
        #expect(board != Color(hexRGB: 0x333A48))
    }
}
