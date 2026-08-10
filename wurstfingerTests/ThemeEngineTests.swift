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
        #expect(decoded.keyColor == BuiltInThemes.classic.keyColor)
        #expect(decoded.cornerRadius == BuiltInThemes.classic.cornerRadius)
        #expect(decoded.keyBorder == nil)
    }

    @Test func unknownSurfaceStyleDecodesToColorWithoutLosingTheTheme() throws {
        // Decoding the surface through the enum would throw here, and
        // `Archive.FailableTheme` would drop the entire theme over one field.
        let json = Data(#"""
        {"id": "abc", "name": "From The Future",
         "boardSurface": "hologram", "keySurface": "hologram",
         "mainLabel": {"type": "fixed", "hex": "#D1AA05"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.boardSurface == .color)
        #expect(decoded.keySurface == .color)
        #expect(decoded.mainLabel == .fixed(hex: "#D1AA05"))
    }

    @Test func archiveFromANewerSchemaYieldsNoThemes() throws {
        // Field-wise tolerance would invent a plausible-but-wrong theme, and
        // the next save would write it back over the user's original.
        let json = Data("""
        {"schemaVersion": 99, "themes": [{"id": "user-1", "name": "Mine"}]}
        """.utf8)
        let archive = try JSONDecoder().decode(ThemeStore.Archive.self, from: json)
        #expect(archive.themes.isEmpty)
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
        #expect(BuiltInThemes.all.count == 3)
        #expect(BuiltInThemes.all.map(\.id) == ["classic", "liquid-glass", "dark-gold"])
    }

    @Test func classicHasNoBorder() {
        #expect(BuiltInThemes.classic.resolved().keyBorder == nil)
    }

    @Test func liquidGlassUsesGlassSurfaces() {
        #expect(BuiltInThemes.liquidGlass.boardSurface == .glass)
        #expect(BuiltInThemes.liquidGlass.keySurface == .glass)
        #expect(BuiltInThemes.liquidGlass.resolved().hasGlassKeys)
    }

    @Test func aGlassBoardPaintsTheTouchableConstant() {
        // Two assertions, not one tautology: raising the touch floor must not
        // silently recolor every glass theme's board.
        #expect(BuiltInThemes.liquidGlass.resolved().boardBackground == Color.gray.opacity(0.02))
        #expect(KeyboardThemeDefinition.minimumBoardOpacity == 0.02)
    }

    @Test func darkGoldResolvesItsFixedPalette() throws {
        let resolved = BuiltInThemes.darkGold.resolved()
        #expect(resolved.mainLabel == HexColor.color(from: "#D1AA05"))
        #expect(try resolved.keyColor == #require(HexColor.color(from: "#333A48")))
    }

    @Test func resolvingIsStable() {
        // An `.adaptive` color in a built-in would break this: every
        // `resolvedColor()` mints a fresh dynamic UIColor and two are never
        // equal, so the resolved theme would compare unequal to itself and
        // invalidate the grid plus every key on each root body evaluation.
        #expect(BuiltInThemes.all.allSatisfy { $0.resolved() == $0.resolved() })
    }
}

// MARK: - Gesture Trail Role

struct ThemeGestureTrailTests {
    @Test func classicTrailMatchesThePreEngineConstant() {
        #expect(BuiltInThemes.classic.resolved().gestureTrail == Color.primary.opacity(0.38))
        #expect(KeyboardConstants.GestureTrail.opacity == 0.38)
    }

    @Test func explicitTrailColorKeepsItsOwnAlpha() throws {
        // The draw path no longer multiplies the 0.38 constant on top, so a
        // fully opaque pick has to resolve fully opaque.
        var theme = BuiltInThemes.darkGold
        theme.gestureTrail = .fixed(hex: "#FF0000")
        let hex = try #require(HexColor.string(from: theme.resolved().gestureTrail))
        #expect(HexColor.parse(hex) == .init(rgb: 0xFF0000, alpha: 1))
    }

    @Test func unparsableTrailHexFallsBackToClassicRole() {
        var theme = BuiltInThemes.darkGold
        theme.gestureTrail = .fixed(hex: "garbage")
        #expect(theme.resolved().gestureTrail == BuiltInThemes.classic.resolved().gestureTrail)
    }

    @Test func everyBuiltInTrailContrastsWithItsKeyColor() throws {
        // Glass keys have no color of their own to measure against.
        for theme in BuiltInThemes.all where theme.keySurface == .color {
            let resolved = theme.resolved()
            let key = try components(of: resolved.keyColor)
            let trail = try components(of: resolved.gestureTrail)
            let composited = luminance(of: trail.rgb, over: key.rgb, alpha: trail.alpha)
            let delta = abs(composited - luminance(of: key.rgb, over: key.rgb, alpha: 1))
            // Dark Gold's gold-over-slate sits at ~0.19 (3.06:1), Classic's
            // ink-over-system-fill far above it.
            #expect(delta > 0.1, "\(theme.id) trail barely differs from its key color")
        }
    }

    private func components(of color: Color) throws -> HexColor.Components {
        let hex = try #require(HexColor.string(from: color))
        return try #require(HexColor.parse(hex))
    }

    /// WCAG relative luminance of `rgb` composited over the opaque `background`
    /// at `alpha`.
    private func luminance(of rgb: UInt32, over background: UInt32, alpha: Double) -> Double {
        func channel(_ packed: UInt32, _ shift: UInt32) -> Double {
            Double((packed >> shift) & 0xFF) / 255
        }
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let weights = [(16 as UInt32, 0.2126), (8 as UInt32, 0.7152), (0 as UInt32, 0.0722)]
        return weights.reduce(0) { total, entry in
            let mixed = alpha * channel(rgb, entry.0) + (1 - alpha) * channel(background, entry.0)
            return total + entry.1 * linear(mixed)
        }
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

// MARK: - Editing

struct ThemeEditingTests {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "theme-editing-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func isBuiltInIsDerivedFromId() {
        #expect(BuiltInThemes.classic.isBuiltIn)
        #expect(BuiltInThemes.darkGold.isBuiltIn)
        var user = BuiltInThemes.darkGold
        user.id = UUID().uuidString
        #expect(!user.isBuiltIn)
    }

    @Test func duplicateMakesEditableCopyPreservingColors() {
        let source = BuiltInThemes.darkGold
        let copy = ThemeStore.duplicate(source, existing: [])
        #expect(copy.id != source.id)
        #expect(!copy.isBuiltIn)
        // Colors carry over untouched; only identity/name change.
        #expect(copy.keyColor == source.keyColor)
        #expect(copy.mainLabel == source.mainLabel)
        #expect(copy.name != source.displayName)
        #expect(copy.name.contains(source.displayName))
    }

    @Test func duplicateNamesStayUnique() {
        let source = BuiltInThemes.darkGold
        let first = ThemeStore.duplicate(source, existing: [])
        let second = ThemeStore.duplicate(source, existing: [first])
        #expect(first.name != second.name)
    }

    @Test func upsertAppendsThenReplacesById() {
        var theme = BuiltInThemes.darkGold
        theme.id = "user-1"
        var list = ThemeStore.upsert(theme, into: [])
        #expect(list.count == 1)
        theme.name = "Renamed"
        list = ThemeStore.upsert(theme, into: list)
        #expect(list.count == 1)
        #expect(list[0].name == "Renamed")
    }

    @Test func upsertRejectsBuiltInIds() {
        let list = ThemeStore.upsert(BuiltInThemes.classic, into: [])
        #expect(list.isEmpty)
    }

    @Test func deleteRepointsSelectedSlotsToClassic() throws {
        let defaults = try isolatedDefaults()
        var theme = BuiltInThemes.darkGold
        theme.id = "user-selected"
        ThemeStore.saveUserTheme(theme, defaults: defaults)
        defaults.set(theme.id, forKey: SettingsKey.selectedThemeLight.rawValue)
        defaults.set(theme.id, forKey: SettingsKey.selectedThemeDark.rawValue)

        ThemeStore.deleteUserTheme(id: theme.id, defaults: defaults)
        #expect(ThemeStore.userThemes(defaults: defaults).isEmpty)
        #expect(defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == BuiltInThemes.classic.id)
        #expect(defaults.string(forKey: SettingsKey.selectedThemeDark.rawValue) == BuiltInThemes.classic.id)
    }

    @Test func deleteLeavesUnrelatedSelectionUntouched() throws {
        let defaults = try isolatedDefaults()
        var theme = BuiltInThemes.darkGold
        theme.id = "user-doomed"
        ThemeStore.saveUserTheme(theme, defaults: defaults)
        defaults.set("dark-gold", forKey: SettingsKey.selectedThemeLight.rawValue)

        ThemeStore.deleteUserTheme(id: theme.id, defaults: defaults)
        #expect(defaults.string(forKey: SettingsKey.selectedThemeLight.rawValue) == "dark-gold")
    }

    @Test func colorBridgeProducesRoundTrippableFixedHex() throws {
        let color = try #require(HexColor.color(from: "#3366CC"))
        let bridged = ThemeColor.from(color)
        guard case let .fixed(hex) = bridged else {
            Issue.record("expected a fixed color, got \(bridged)")
            return
        }
        #expect(HexColor.parse(hex)?.rgb == 0x3366CC)
    }
}
