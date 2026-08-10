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

    @Test func roundTripPreservesTheTrailAndBothSurfaces() throws {
        // On Classic these three roles happen to equal the decode fallbacks,
        // so a dropped key would round-trip green there. Pick values that
        // differ from Classic's, and the round trip has to carry them.
        var theme = BuiltInThemes.classic
        theme.id = "user-distinct"
        theme.boardSurface = .glass
        theme.keySurface = .glass
        theme.gestureTrail = .fixed(hex: "#FF00FFAA")
        let decoded = try roundTrip(theme)
        #expect(decoded.boardSurface == .glass)
        #expect(decoded.keySurface == .glass)
        #expect(decoded.gestureTrail == .fixed(hex: "#FF00FFAA"))
        #expect(decoded == theme)
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

    /// A color role a later version writes differently, an unknown token, a
    /// truncated payload, and a bare string where an object belongs.
    @Test(arguments: [
        ##"{"type": "gradient", "from": "#000000", "to": "#FFFFFF"}"##,
        ##"{"type": "semantic", "token": "quaternaryLabel"}"##,
        ##"{"type": "fixed"}"##,
        ##""#FFFFFF""##,
    ])
    func aMalformedColorRoleDegradesToClassic(payload: String) throws {
        // Only the one role degrades — throwing would cost the whole theme.
        let json = Data(#"""
        {"id": "abc", "name": "Mine", "keyColor": \#(payload),
         "mainLabel": {"type": "fixed", "hex": "#D1AA05"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.keyColor == BuiltInThemes.classic.keyColor)
        #expect(decoded.name == "Mine")
        #expect(decoded.mainLabel == .fixed(hex: "#D1AA05"))
    }

    @Test func aMalformedNumberDegradesToClassic() throws {
        let json = Data(#"""
        {"id": "abc", "name": "Mine", "keyBorderWidth": "0.5", "cornerRadius": "big",
         "mainLabel": {"type": "fixed", "hex": "#D1AA05"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.keyBorderWidth == BuiltInThemes.classic.keyBorderWidth)
        #expect(decoded.cornerRadius == BuiltInThemes.classic.cornerRadius)
        #expect(decoded.mainLabel == .fixed(hex: "#D1AA05"))
    }

    @Test func aMalformedKeyBorderBecomesNoBorder() throws {
        // Classic's value for this role is "no border"; inventing one would
        // stroke every key with something the user never picked.
        let json = Data(#"""
        {"id": "abc", "name": "Mine", "keyBorder": {"type": "fixed"}, "keyBorderWidth": 2}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.keyBorder == nil)
        #expect(decoded.keyBorderWidth == 2)
    }

    @Test func aBorderedThemeNeverDecodesToAnInvisibleWidth() throws {
        // `KeyView.filled` only strokes for a positive width, so a stored zero
        // next to a border color would show an enabled control that draws
        // nothing — and `setKeyBorder(_:)` only repairs an exact zero, so
        // toggling it off and on would not recover either.
        let bordered = Data(#"""
        {"id": "abc", "name": "Mine", "keyBorder": {"type": "fixed", "hex": "#FFFFFF1F"}, "keyBorderWidth": 0}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: bordered)
        #expect(decoded.keyBorder != nil)
        #expect(decoded.keyBorderWidth == KeyboardThemeDefinition.minimumKeyBorderWidth)

        // Without a border color the width is inert, and Classic legitimately
        // stores zero there.
        let borderless = Data(#"""
        {"id": "abc", "name": "Mine", "keyBorderWidth": 0}
        """#.utf8)
        #expect(try JSONDecoder().decode(KeyboardThemeDefinition.self, from: borderless).keyBorderWidth == 0)
    }

    @Test func aThemeWithOneMalformedFieldSurvivesTheArchive() throws {
        // The damage path in full: `FailableTheme` would drop the theme, and
        // the next save would write that loss back over the original.
        let json = Data("""
        {"schemaVersion": 1, "themes": [{"id": "user-1", "name": "Mine", "cornerRadius": "big"}]}
        """.utf8)
        let archive = try JSONDecoder().decode(ThemeStore.Archive.self, from: json)
        #expect(archive.themes.map(\.id) == ["user-1"])
    }

    @Test func preReworkFillsKeepTheirColors() throws {
        // Unreleased M2/M3 dev builds stored one `ThemeFill` per surface. The
        // label roles still decode, so ignoring these keys would leave gold
        // labels on Classic's near-white key (~2.2:1) — and persist it.
        let json = Data(#"""
        {"id": "user-1", "name": "Old Gold",
         "boardBackground": {"type": "color", "color": {"type": "fixed", "hex": "#252A34"}},
         "keyFill": {"type": "color", "color": {"type": "fixed", "hex": "#333A48"}},
         "keyFillActive": {"type": "color", "color": {"type": "fixed", "hex": "#4A5468"}},
         "keyBorder": {"type": "fixed", "hex": "#FFFFFF1F"}, "keyBorderWidth": 0.5,
         "mainLabel": {"type": "fixed", "hex": "#D1AA05"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.boardSurface == .color)
        #expect(decoded.boardColor == .fixed(hex: "#252A34"))
        #expect(decoded.keySurface == .color)
        #expect(decoded.keyColor == .fixed(hex: "#333A48"))
        #expect(decoded.keyColorActive == .fixed(hex: "#4A5468"))
        #expect(decoded.keyBorder == .fixed(hex: "#FFFFFF1F"))
        #expect(decoded.mainLabel == .fixed(hex: "#D1AA05"))
    }

    @Test func preReworkMaterialFillsBecomeGlassSurfaces() throws {
        let json = Data(#"""
        {"id": "user-2", "name": "Old Glass",
         "boardBackground": {"type": "material"},
         "keyFill": {"type": "material"},
         "keyFillActive": {"type": "material"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.boardSurface == .glass)
        #expect(decoded.keySurface == .glass)
        // A material carried no color, so the colors behind the glass stay
        // Classic's — switching a surface back to `.color` must still render.
        #expect(decoded.keyColor == BuiltInThemes.classic.keyColor)
        #expect(decoded.boardColor == BuiltInThemes.classic.boardColor)
    }

    @Test func currentKeysWinOverPreReworkKeys() throws {
        let json = Data(#"""
        {"id": "user-3", "name": "Both Shapes",
         "keySurface": "color", "keyColor": {"type": "fixed", "hex": "#111111"},
         "keyFill": {"type": "material"}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardThemeDefinition.self, from: json)
        #expect(decoded.keySurface == .color)
        #expect(decoded.keyColor == .fixed(hex: "#111111"))
    }

    @Test func encodingNeverWritesThePreReworkShape() throws {
        var theme = BuiltInThemes.darkGold
        theme.id = "user-4"
        let json = try #require(String(data: JSONEncoder().encode(theme), encoding: .utf8))
        for legacyKey in ["boardBackground", "keyFill", "keyFillActive"] {
            #expect(!json.contains(legacyKey), "encoder wrote the pre-rework key \(legacyKey)")
        }
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
        #expect(BuiltInThemes.all.allSatisfy { $0.resolved() == $0.resolved() })
        // The loop above cannot fail for the reason that matters: no built-in
        // uses `.adaptive`, the one case that resolves through a fresh dynamic
        // UIColor per call — and two of those never compare equal, so the
        // resolved theme would differ from itself and invalidate the grid plus
        // every key on each root body evaluation.
        var adaptive = BuiltInThemes.classic
        adaptive.mainLabel = .adaptive(light: "#111111", dark: "#EEEEEE")
        #expect(adaptive.resolved() == adaptive.resolved())
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

    /// Contrast *ratio*, which is what the palette was tuned against — a raw
    /// luminance delta diverges from it at the light end, where a #F2F2F7 key
    /// with a 6 %-black trail clears a 0.1 delta at an invisible 1.13:1.
    ///
    /// Measured on the shipped palettes, per appearance: Classic 2.65:1 light
    /// and 3.56:1 dark, Dark Gold 3.06:1 in both. Classic's light-mode ink on
    /// a near-white key is the floor, so the bound sits just under it; Dark
    /// Gold's own tuned 3.06:1 is pinned separately below.
    @Test(arguments: [ColorScheme.light, .dark])
    func everyBuiltInTrailContrastsWithItsKeyColor(appearance: ColorScheme) throws {
        // Glass keys have no color of their own to measure against.
        for theme in BuiltInThemes.all where theme.keySurface == .color {
            let key = try #require(ThemeContrast.components(of: theme.keyColor, in: appearance))
            let trail = try #require(ThemeContrast.components(of: theme.gestureTrail, in: appearance))
            let ratio = ThemeContrast.ratio(of: trail, over: key)
            #expect(ratio >= 2.5, "\(theme.id) trail is \(ratio):1 against its key color in \(appearance)")
        }
    }

    /// The bound Dark Gold's gold was actually tuned to: 0.38 alpha reached
    /// only 1.95:1 and disappeared under the finger, 0.65 reaches 3.06:1.
    @Test func darkGoldTrailHoldsTheRatioItsPaletteWasTunedTo() throws {
        let key = try #require(ThemeContrast.components(of: BuiltInThemes.darkGold.keyColor, in: .dark))
        let trail = try #require(ThemeContrast.components(of: BuiltInThemes.darkGold.gestureTrail, in: .dark))
        #expect(ThemeContrast.ratio(of: trail, over: key) >= 3.0)
    }
}

// MARK: - Resolver

struct ThemeResolverTests {
    /// The headline capability of the surface rework: the two surfaces are
    /// independent. Every built-in has `boardSurface == keySurface`, so nothing
    /// else in the suite would notice the resolver reading one surface's style
    /// for the other's decision.
    @Test func aGlassBoardUnderColorKeysResolvesEachSurfaceOnItsOwn() {
        var theme = BuiltInThemes.darkGold
        theme.id = "user-glass-board"
        theme.boardSurface = .glass
        theme.keySurface = .color

        let resolved = theme.resolved()
        #expect(!resolved.hasGlassKeys)
        #expect(resolved.boardBackground == Color.gray.opacity(KeyboardThemeDefinition.minimumBoardOpacity))
        // The key still paints its own color, not the glass constant.
        #expect(resolved.keyColor == HexColor.color(from: "#333A48"))
    }

    @Test func glassKeysOverAColorBoardResolveEachSurfaceOnItsOwn() {
        var theme = BuiltInThemes.darkGold
        theme.id = "user-glass-keys"
        theme.boardSurface = .color
        theme.keySurface = .glass

        let resolved = theme.resolved()
        #expect(resolved.hasGlassKeys)
        #expect(resolved.boardBackground == HexColor.color(from: "#252A34"))
        #expect(resolved.boardBackground != Color.gray.opacity(KeyboardThemeDefinition.minimumBoardOpacity))
    }

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
        // The flag has to be on, or the resolver never reads the dark slot at
        // all and the cascade below is never entered.
        defaults.set(true, forKey: SettingsKey.themeSeparateDarkSlot.rawValue)
        // Dark slot points at a nonexistent theme → falls back to the light
        // slot, then Classic.
        defaults.set("dark-gold", forKey: SettingsKey.selectedThemeLight.rawValue)
        defaults.set("deleted-user-theme", forKey: SettingsKey.selectedThemeDark.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == "dark-gold")
        defaults.set("also-gone", forKey: SettingsKey.selectedThemeLight.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == "classic")
    }

    /// The same cascade with a theme that is *stored* but no longer decodes —
    /// the archive drops the corrupt entry, so the dark slot resolves to
    /// nothing and the light slot has to take over.
    @Test func aDarkSlotPointingAtAnUndecodableThemeFallsBackToTheLightSlot() throws {
        let defaults = try isolatedDefaults()
        let stored = Data("""
        {"schemaVersion": 1, "themes": [
            {"id": "user-light", "name": "Mine"},
            {"name": "user-dark"}
        ]}
        """.utf8)
        defaults.set(stored, forKey: SettingsKey.userThemes.rawValue)
        defaults.set(true, forKey: SettingsKey.themeSeparateDarkSlot.rawValue)
        defaults.set("user-light", forKey: SettingsKey.selectedThemeLight.rawValue)
        defaults.set("user-dark", forKey: SettingsKey.selectedThemeDark.rawValue)

        #expect(ThemeStore.theme(id: "user-dark", defaults: defaults) == nil)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == "user-light")
        #expect(ThemeStore.selectedTheme(for: .light, defaults: defaults).id == "user-light")
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

    @Test func readingUserThemesSeesAWriteFromAnotherProcess() throws {
        // `userThemes()` memoizes the decode. The cache is keyed on the stored
        // bytes rather than invalidated by the writers, because the host app
        // and the keyboard extension are separate processes — a write in one
        // must not leave the other serving a stale list.
        let defaults = try isolatedDefaults()
        var theme = BuiltInThemes.darkGold
        theme.id = "user-1"
        theme.name = "First"
        ThemeStore.saveUserTheme(theme, defaults: defaults)
        #expect(ThemeStore.userThemes(defaults: defaults).map(\.name) == ["First"])

        // Written the way the other process would: straight into defaults,
        // bypassing every in-process code path that could invalidate a cache.
        let renamed = Data("""
        {"schemaVersion": 1, "themes": [{"id": "user-1", "name": "Renamed Elsewhere"}]}
        """.utf8)
        defaults.set(renamed, forKey: SettingsKey.userThemes.rawValue)
        #expect(ThemeStore.userThemes(defaults: defaults).map(\.name) == ["Renamed Elsewhere"])
    }

    @Test func writingDoesNotClobberANewerSchemaArchive() throws {
        let defaults = try isolatedDefaults()
        let stored = Data("""
        {"schemaVersion": 2, "themes": [{"id": "future-1", "name": "From The Future"}]}
        """.utf8)
        defaults.set(stored, forKey: SettingsKey.userThemes.rawValue)

        var theme = BuiltInThemes.darkGold
        theme.id = "user-new"
        ThemeStore.saveUserTheme(theme, defaults: defaults)

        // A newer archive reads as "no themes" on purpose; writing this
        // build's list over it would delete every theme that guard protects.
        #expect(defaults.data(forKey: SettingsKey.userThemes.rawValue) == stored)
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
