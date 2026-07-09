//
//  ThemeEngineTests.swift
//  WurstfingerTests
//
//  Covers hex parsing, theme codability (the future export wire format),
//  built-in stability, resolver fallbacks, and the legacy-style migration.
//

import SwiftUI
import Testing
@testable import WurstfingerApp

// MARK: - HexColor

struct HexColorTests {
    @Test func parsesSixDigitHex() {
        #expect(HexColor.parse("#333A48") == .init(rgb: 0x333A48, alpha: 1))
        #expect(HexColor.parse("d1aa05") == .init(rgb: 0xD1AA05, alpha: 1))
    }

    @Test func parsesEightDigitHexWithAlpha() throws {
        let parsed = try #require(HexColor.parse("#FFFFFF80"))
        #expect(parsed.rgb == 0xFFFFFF)
        #expect(abs(parsed.alpha - 128.0 / 255.0) < 0.001)
    }

    @Test func rejectsInvalidHex() {
        #expect(HexColor.parse("") == nil)
        #expect(HexColor.parse("#12345") == nil)
        #expect(HexColor.parse("#1234567") == nil)
        #expect(HexColor.parse("#GGGGGG") == nil)
        #expect(HexColor.parse("not a color") == nil)
    }

    @Test func formatsWithAlphaOnlyWhenBelowOne() {
        #expect(HexColor.string(from: .init(rgb: 0x333A48, alpha: 1)) == "#333A48")
        #expect(HexColor.string(from: .init(rgb: 0xFFFFFF, alpha: 0.5)) == "#FFFFFF80")
    }

    @Test func colorRoundTripsThroughHexString() throws {
        let original = HexColor.Components(rgb: 0x333A48, alpha: 1)
        let string = try #require(HexColor.string(from: HexColor.color(from: original)))
        #expect(HexColor.parse(string) == original)
    }

    @Test func luminanceOrdersLightAndDark() {
        #expect(HexColor.luminance(of: 0xFFFFFF) > 0.9)
        #expect(HexColor.luminance(of: 0x000000) < 0.1)
        // Dark Gold's key color is dark, so it earns a light border.
        #expect(HexColor.luminance(of: 0x333A48) < 0.5)
    }

    @Test func scalingRoundsAndClamps() {
        // Rounds (not truncates): this is exactly Dark Gold's board color.
        #expect(HexColor.scaled(0x333A48, by: 0.725) == 0x252A34)
        #expect(HexColor.scaled(0xFFFFFF, by: 2.0) == 0xFFFFFF)
        #expect(HexColor.scaled(0x000000, by: 0.5) == 0x000000)
    }
}

// MARK: - Codable Wire Format

struct ThemeCodableTests {
    private func roundTrip(_ definition: KeyboardThemeDefinition) throws -> KeyboardThemeDefinition {
        let data = try JSONEncoder().encode(definition)
        return try JSONDecoder().decode(KeyboardThemeDefinition.self, from: data)
    }

    @Test func builtInsRoundTripLosslessly() throws {
        for theme in BuiltInThemes.all {
            #expect(try roundTrip(theme) == theme)
        }
    }

    @Test func adaptiveColorRoundTrips() throws {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        theme.mainLabel = .adaptive(light: "#111111", dark: "#EEEEEE")
        #expect(try roundTrip(theme) == theme)
    }

    @Test func missingFieldsDecodeToClassicDefaults() throws {
        let json = Data(#"{"id": "abc", "name": "Sparse"}"#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.keyFill == BuiltInThemes.classic.keyFill)
        #expect(decoded.cornerRadius == BuiltInThemes.classic.cornerRadius)
        #expect(decoded.keyBorder == nil)
    }

    @Test func archiveDecodingIsLossy() throws {
        // One valid theme, one corrupt entry (id missing), one entry claiming
        // a built-in id — only the valid one must survive.
        let json = Data("""
        {"schemaVersion": 1, "themes": [
            {"id": "user-1", "name": "Mine"},
            {"name": "Broken"},
            {"id": "classic", "name": "Impostor"}
        ]}
        """.utf8)
        let archive = try JSONDecoder().decode(ThemeStore.Archive.self, from: json)
        #expect(archive.themes.map(\.id) == ["user-1"])
    }

    @Test func archiveEncodingIsStable() throws {
        var theme = BuiltInThemes.darkGold
        theme.id = "user-stable"
        let archive = ThemeStore.Archive(schemaVersion: 1, themes: [theme])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let first = try encoder.encode(archive)
        let second = try encoder.encode(archive)
        #expect(first == second)
    }
}

// MARK: - Built-ins

struct BuiltInThemeTests {
    /// The ids are API: persisted selections and future export codes
    /// reference them. Changing one silently resets users to Classic.
    @Test func builtInIdsArePinned() {
        #expect(BuiltInThemes.classic.id == "classic")
        #expect(BuiltInThemes.liquidGlass.id == "liquid-glass")
        #expect(BuiltInThemes.darkGold.id == "dark-gold")
        #expect(BuiltInThemes.styles.count == 2)
        #expect(BuiltInThemes.palettes.count == 16)
        #expect(BuiltInThemes.all.count == 18)
        // Dark Gold is palette 12 of the original set.
        #expect(BuiltInThemes.palettes[12].id == "dark-gold")
    }

    /// Every palette has unique, parsable colors — a resolver fallback to a
    /// Classic role (nil hex parse) must never happen for a built-in.
    @Test func palettesHaveUniqueParsableColors() {
        let ids = BuiltInThemes.palettes.map(\.id)
        #expect(Set(ids).count == ids.count)
        for palette in BuiltInThemes.palettes {
            guard case .color = palette.keyFill else {
                Issue.record("palette \(palette.id) keyFill is not a color")
                continue
            }
            #expect(palette.mainLabel.resolvedColor() != nil, "palette \(palette.id) mainLabel")
            #expect(palette.hintLetter.resolvedColor() != nil, "palette \(palette.id) hintLetter")
        }
    }

    /// The palette conversion must reproduce the previously hand-written Dark
    /// Gold definition byte-for-byte, so the on-device-approved look is stable.
    @Test func darkGoldMatchesReferenceDefinition() {
        let gold = BuiltInThemes.darkGold
        #expect(gold.boardBackground == .color(.fixed(hex: "#252A34")))
        #expect(gold.keyFill == .color(.fixed(hex: "#333A48")))
        #expect(gold.keyFillActive == .color(.fixed(hex: "#4A5468")))
        #expect(gold.keyBorder == .fixed(hex: "#FFFFFF1F"))
        #expect(gold.mainLabel == .fixed(hex: "#D1AA05"))
        #expect(gold.utilityLabel == .fixed(hex: "#FFFFFF"))
        #expect(gold.hintLetter == .fixed(hex: "#FFFFFFE6"))
        #expect(gold.hintSymbol == .fixed(hex: "#FFFFFFB3"))
        #expect(gold.hintIconProminent == .fixed(hex: "#FFFFFF80"))
        #expect(gold.hintIconSubtle == .fixed(hex: "#FFFFFF73"))
    }

    @Test func classicHasNoBorder() {
        #expect(BuiltInThemes.classic.resolved().keyBorder == nil)
    }

    @Test func liquidGlassUsesMaterialKeys() {
        let resolved = BuiltInThemes.liquidGlass.resolved()
        #expect(resolved.keyFill == .material)
        #expect(resolved.keyFillActive == .material)
    }

    @Test func darkGoldResolvesItsFixedPalette() throws {
        let resolved = BuiltInThemes.darkGold.resolved()
        #expect(resolved.mainLabel == HexColor.color(from: "#D1AA05"))
        #expect(try resolved.keyFill == .color(#require(HexColor.color(from: "#333A48"))))
    }
}

// MARK: - Resolver

struct ThemeResolverTests {
    @Test func unparsableHexFallsBackToClassicRole() {
        var theme = BuiltInThemes.darkGold
        theme.mainLabel = .fixed(hex: "garbage")
        let resolved = theme.resolved()
        #expect(resolved.mainLabel == BuiltInThemes.classic.resolved().mainLabel)
    }

    @Test func boardOpacityIsFloored() {
        // A fully transparent board would drop touches between keys (#198),
        // so the resolver clamps it to the minimum.
        let floored = ThemeColor.fixed(hex: "#00000000")
            .withMinimumOpacity(KeyboardThemeDefinition.minimumBoardOpacity)
        guard case let .fixed(hex) = floored else {
            Issue.record("expected fixed color, got \(floored)")
            return
        }
        let components = HexColor.parse(hex)
        #expect((components?.alpha ?? 0) >= KeyboardThemeDefinition.minimumBoardOpacity - 0.001)
    }

    @Test func boardOpacityFloorKeepsOpaqueColors() {
        let untouched = ThemeColor.fixed(hex: "#252A34")
            .withMinimumOpacity(KeyboardThemeDefinition.minimumBoardOpacity)
        #expect(untouched == .fixed(hex: "#252A34"))
    }

    @Test func semanticOpacityIsFlooredToo() {
        let floored = ThemeColor.semantic(.systemBackground, opacity: 0)
            .withMinimumOpacity(0.02)
        #expect(floored == .semantic(.systemBackground, opacity: 0.02))
    }
}

// MARK: - Migration

struct ThemeMigrationTests {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "theme-migration-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func migratesLegacyStyles() throws {
        let cases: [(legacy: String, expected: String)] = [
            ("classic", "classic"),
            ("liquidGlass", "liquid-glass"),
            ("darkGold", "dark-gold"),
            ("unknown-junk", "classic"),
        ]
        for testCase in cases {
            let defaults = try isolatedDefaults()
            defaults.set(testCase.legacy, forKey: SettingsKey.keyboardStyle.rawValue)
            ThemeStore.migrateIfNeeded(defaults: defaults)
            #expect(defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == testCase.expected)
            #expect(defaults.string(forKey: SettingsKey.selectedThemeDark.rawValue) == testCase.expected)
            #expect(defaults.string(forKey: SettingsKey.keyboardStyle.rawValue) == nil)
        }
    }

    @Test func migrationIsIdempotent() throws {
        let defaults = try isolatedDefaults()
        defaults.set("liquidGlass", forKey: SettingsKey.keyboardStyle.rawValue)
        ThemeStore.migrateIfNeeded(defaults: defaults)
        // A second run (or a racing second process after the first finished)
        // must not change anything — even if the user re-selected meanwhile.
        defaults.set("classic", forKey: SettingsKey.selectedThemeLight.rawValue)
        ThemeStore.migrateIfNeeded(defaults: defaults)
        #expect(defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == "classic")
    }

    @Test func migrationWithoutLegacyKeyWritesNothing() throws {
        let defaults = try isolatedDefaults()
        ThemeStore.migrateIfNeeded(defaults: defaults)
        #expect(defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == nil)
    }

    @Test func selectionFallsBackThroughCascade() throws {
        let defaults = try isolatedDefaults()
        // Dark slot points at a nonexistent theme → falls back to the light
        // slot, then Classic.
        defaults.set("dark-gold", forKey: SettingsKey.selectedThemeLight.rawValue)
        defaults.set("deleted-user-theme", forKey: SettingsKey.selectedThemeDark.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == "dark-gold")
        defaults.set("also-gone", forKey: SettingsKey.selectedThemeLight.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == "classic")
    }

    @Test func userThemesPersistThroughStore() throws {
        let defaults = try isolatedDefaults()
        var theme = BuiltInThemes.darkGold
        theme.id = "user-abc"
        theme.name = "My Theme"
        ThemeStore.writeUserThemes([theme], defaults: defaults)
        #expect(ThemeStore.userThemes(defaults: defaults) == [theme])
        #expect(ThemeStore.theme(id: "user-abc", defaults: defaults) == theme)
    }
}
