//
//  ThemeEditingTests.swift
//  WurstfingerTests
//
//  The editing rules the style screen and the theme editor are built on:
//  built-ins are immutable templates, glass is a reversible per-surface
//  switch, and a duplicate only becomes real when it is saved.
//

import SwiftUI
import Testing
import UIKit
@testable import WurstfingerApp

// MARK: - Row affordances

struct ThemeRowActionTests {
    @Test func builtInOffersNeitherEditNorDelete() {
        for theme in BuiltInThemes.all {
            let actions = StyleSettingsView.rowActions(for: theme)
            #expect(actions == [.select, .duplicate])
            #expect(!actions.contains(.edit))
            #expect(!actions.contains(.delete))
        }
    }

    @Test func userThemeOffersEveryAction() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        #expect(StyleSettingsView.rowActions(for: theme) == [.select, .duplicate, .edit, .delete])
    }

    /// Delete is the only irreversible action in the row and the tint is its
    /// only cue apart from the glyph. It has to reach the button as data, since
    /// a `.foregroundStyle` wrapped around the button is overridden by the one
    /// applied inside it.
    @Test func onlyTheDestructiveActionCarriesADistinctTint() throws {
        #expect(StyleSettingsView.icon(for: .select) == nil)
        let delete = try #require(StyleSettingsView.icon(for: .delete))
        let duplicate = try #require(StyleSettingsView.icon(for: .duplicate))
        let edit = try #require(StyleSettingsView.icon(for: .edit))
        #expect(delete.tint == .red)
        #expect(duplicate.tint == .accentColor)
        #expect(edit.tint == .accentColor)
        #expect(delete.tint != duplicate.tint)
        #expect(delete.tint != edit.tint)
    }
}

// MARK: - Glass switches

/// The editor's two glass toggles write nothing but the surface style, which
/// is what makes them losslessly reversible and lets the editor work without a
/// shadow copy of the palette.
///
/// These exercise `KeyboardThemeDefinition.setGlassKeys(_:)` /
/// `setGlassBoard(_:)` — the functions the editor's bindings call. A test that
/// re-implemented the assignment would pass no matter what the editor did.
struct ThemeGlassToggleTests {
    @Test func togglingGlassKeysKeepsTheKeyColors() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        let original = theme

        theme.setGlassKeys(true)
        #expect(theme.keySurface == .glass)
        #expect(theme.keyColor == original.keyColor)
        #expect(theme.keyColorActive == original.keyColorActive)
        #expect(theme.boardColor == original.boardColor)

        theme.setGlassKeys(false)
        #expect(theme == original)
    }

    @Test func togglingGlassBackgroundKeepsTheBoardColor() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        let original = theme

        theme.setGlassBoard(true)
        #expect(theme.boardSurface == .glass)
        #expect(theme.boardColor == original.boardColor)
        #expect(theme.keyColor == original.keyColor)
        #expect(theme.keyColorActive == original.keyColorActive)

        theme.setGlassBoard(false)
        #expect(theme == original)
    }

    /// Each switch owns exactly one surface: turning glass on for the keys must
    /// not drag the board along, or the editor's two toggles would fight.
    @Test func eachGlassSwitchTouchesOnlyItsOwnSurface() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString

        theme.setGlassKeys(true)
        #expect(theme.boardSurface == .color)

        theme.setGlassKeys(false)
        theme.setGlassBoard(true)
        #expect(theme.keySurface == .color)
    }

    /// A copy of the glass built-in has to survive the same round trip, since
    /// its colors are the fallbacks the toggle restores.
    @Test func glassBuiltInCopySurvivesTheRoundTrip() {
        var theme = BuiltInThemes.liquidGlass
        theme.id = UUID().uuidString
        let original = theme

        theme.setGlassKeys(false)
        theme.setGlassBoard(false)
        #expect(!theme.resolved().hasGlassKeys)

        theme.setGlassKeys(true)
        theme.setGlassBoard(true)
        #expect(theme == original)
    }

    /// `BuiltInThemes` promises that switching either surface back to `.color`
    /// yields a *usable* keyboard, so the color fields are real fallbacks and
    /// not placeholders. Measured absolutely, in both appearances: comparing a
    /// built-in's colors to themselves would hold for an invisible palette too.
    ///
    /// Measured floor of the shipped palettes: opaque keys and boards
    /// throughout, key-vs-board 1.12:1 (Classic/Liquid Glass light), 1.23:1
    /// (dark) and 1.26:1 (Dark Gold). A key edge is a shape cue, not text, so
    /// the bar is "visibly separate", far below a WCAG text ratio — but well
    /// above the 1.0 an invisible or board-colored key produces.
    @Test(arguments: [ColorScheme.light, .dark])
    func everyBuiltInStaysUsableWithBothSurfacesSetToColor(appearance: ColorScheme) throws {
        for builtIn in BuiltInThemes.all {
            var theme = builtIn
            theme.id = UUID().uuidString
            theme.setGlassKeys(false)
            theme.setGlassBoard(false)

            let key = try #require(ThemeContrast.components(of: theme.keyColor, in: appearance))
            let board = try #require(ThemeContrast.components(of: theme.boardColor, in: appearance))
            #expect(key.alpha >= 0.9, "\(builtIn.id) has near-transparent keys without glass")
            #expect(board.alpha >= 0.9, "\(builtIn.id) has a near-transparent board without glass")
            let ratio = ThemeContrast.ratio(of: key, over: board)
            #expect(ratio >= 1.1, "\(builtIn.id) keys disappear into their board (\(ratio):1)")
        }
    }
}

// MARK: - Duplicate → edit → save

struct ThemeEditingFlowTests {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "theme-editing-flow-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Cancelling the editor must leave no orphaned "… Copy": the gallery's
    /// Duplicate action only opens an edit session, and nothing writes until
    /// Save. Exercises the gallery's own seam, not `ThemeStore.duplicate` — the
    /// latter takes no defaults and so could not fail this assertion.
    @Test func duplicatingOpensAnUnsavedEditSession() throws {
        let defaults = try isolatedDefaults()

        let session = StyleSettingsView.editSession(duplicating: BuiltInThemes.darkGold, defaults: defaults)

        #expect(session.isNewTheme)
        #expect(!session.theme.isBuiltIn)
        #expect(session.theme.keyColor == BuiltInThemes.darkGold.keyColor)
        // Nothing persisted, and not even an empty archive written.
        #expect(defaults.data(forKey: SettingsKey.userThemes.rawValue) == nil)
        #expect(ThemeStore.userThemes(defaults: defaults).isEmpty)
        #expect(ThemeStore.theme(id: session.theme.id, defaults: defaults) == nil)
    }

    /// The copy is named against what is already stored, so duplicating the
    /// same theme twice cannot produce two rows with one name.
    @Test func duplicatingTwiceYieldsDistinctNames() throws {
        let defaults = try isolatedDefaults()

        let first = StyleSettingsView.editSession(duplicating: BuiltInThemes.darkGold, defaults: defaults)
        ThemeStore.saveUserTheme(first.theme, defaults: defaults)
        let second = StyleSettingsView.editSession(duplicating: BuiltInThemes.darkGold, defaults: defaults)

        #expect(first.theme.name != second.theme.name)
        #expect(first.theme.id != second.theme.id)
    }

    @Test func savedNewThemeIsPersisted() throws {
        let defaults = try isolatedDefaults()
        let copy = ThemeStore.duplicate(BuiltInThemes.darkGold, existing: ThemeStore.userThemes(defaults: defaults))

        ThemeStore.saveUserTheme(copy, defaults: defaults)

        #expect(ThemeStore.userThemes(defaults: defaults).map(\.id) == [copy.id])
    }

    @Test func savingANewThemeSelectsIt() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-new",
            isNewTheme: true,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: false,
            editingAppearance: .light
        )
        #expect(slots.light == "user-new")
        // Saving follows the same rule as selecting: with the slots joined the
        // dark one is not written, so a stored dark assignment survives.
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }

    @Test func savingAnEditLeavesTheSelectionAlone() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-edited",
            isNewTheme: false,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            editingAppearance: .light
        )
        #expect(slots.light == BuiltInThemes.classic.id)
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }

    /// A new theme lands in the slot the gallery is editing, not in both, once
    /// the two slots are allowed to diverge.
    @Test func savingANewThemeWhileEditingDarkTouchesOnlyTheDarkSlot() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-new",
            isNewTheme: true,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            editingAppearance: .dark
        )
        #expect(slots.light == BuiltInThemes.classic.id)
        #expect(slots.dark == "user-new")
    }

    /// The mirror of the case above, and the one the light branch is actually
    /// exercised by: with Light=Classic, Dark=Dark Gold and the segment on
    /// Light, saving must not drag the dark assignment along.
    @Test func savingANewThemeWhileEditingLightTouchesOnlyTheLightSlot() {
        let slots = StyleSettingsView.slots(
            afterSaving: "user-new",
            isNewTheme: true,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            editingAppearance: .light
        )
        #expect(slots.light == "user-new")
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }

    @Test func selectingWhileEditingLightTouchesOnlyTheLightSlot() {
        let slots = StyleSettingsView.slots(
            selecting: BuiltInThemes.liquidGlass.id,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            editingAppearance: .light
        )
        #expect(slots.light == BuiltInThemes.liquidGlass.id)
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }

    @Test func selectingWhileEditingDarkTouchesOnlyTheDarkSlot() {
        let slots = StyleSettingsView.slots(
            selecting: BuiltInThemes.liquidGlass.id,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            editingAppearance: .dark
        )
        #expect(slots.light == BuiltInThemes.classic.id)
        #expect(slots.dark == BuiltInThemes.liquidGlass.id)
    }

    /// While the slots share one selection, selecting writes the light slot
    /// only. Mirroring into the dark slot renders identically — the resolver
    /// ignores it in that state — but it destroys a stored dark assignment on a
    /// tap, which is the loss the toggle itself was already stopped from doing.
    @Test func selectingWhileTheSlotsShareOneSelectionLeavesTheDarkSlotAlone() {
        let slots = StyleSettingsView.slots(
            selecting: BuiltInThemes.liquidGlass.id,
            light: BuiltInThemes.classic.id,
            dark: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: false,
            editingAppearance: .light
        )
        #expect(slots.light == BuiltInThemes.liquidGlass.id)
        #expect(slots.dark == BuiltInThemes.darkGold.id)
    }
}

// MARK: - The separate-dark-slot flag

/// The flag is semantic, not a shortcut for "both slots hold the same id":
/// while it is off the resolver ignores the dark slot, which is what lets the
/// dark assignment survive the toggle being switched off and on again.
struct SeparateDarkSlotTests {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "separate-dark-slot-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func darkSlotIsIgnoredWhileTheFlagIsOff() {
        let resolved = ThemeStore.theme(
            lightId: BuiltInThemes.classic.id,
            darkId: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: false,
            for: .dark
        )
        #expect(resolved.id == BuiltInThemes.classic.id)
    }

    @Test func darkSlotAppliesWhileTheFlagIsOn() {
        let resolved = ThemeStore.theme(
            lightId: BuiltInThemes.classic.id,
            darkId: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: true,
            for: .dark
        )
        #expect(resolved.id == BuiltInThemes.darkGold.id)
    }

    /// The regression: turning the toggle off used to overwrite the dark slot
    /// with the light id, so the user's dark theme was gone for good.
    @Test func darkAssignmentSurvivesARoundTripThroughTheToggle() throws {
        let defaults = try isolatedDefaults()
        defaults.set(BuiltInThemes.classic.id, forKey: SettingsKey.selectedThemeLight.rawValue)
        defaults.set(BuiltInThemes.darkGold.id, forKey: SettingsKey.selectedThemeDark.rawValue)
        defaults.set(true, forKey: SettingsKey.themeSeparateDarkSlot.rawValue)

        // Off: the keyboard renders the light slot in both appearances…
        defaults.set(false, forKey: SettingsKey.themeSeparateDarkSlot.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == BuiltInThemes.classic.id)
        #expect(ThemeStore.selectedTheme(for: .light, defaults: defaults).id == BuiltInThemes.classic.id)

        // …and back on, the dark assignment is still there.
        defaults.set(true, forKey: SettingsKey.themeSeparateDarkSlot.rawValue)
        #expect(ThemeStore.selectedTheme(for: .dark, defaults: defaults).id == BuiltInThemes.darkGold.id)
        #expect(ThemeStore.selectedTheme(for: .light, defaults: defaults).id == BuiltInThemes.classic.id)
    }

    /// An unresolvable light slot still falls back to Classic with the flag
    /// off — the guard must not skip the fallback along with the dark slot.
    @Test func deletedLightThemeFallsBackToClassicWithTheFlagOff() {
        let resolved = ThemeStore.theme(
            lightId: "deleted-user-theme",
            darkId: BuiltInThemes.darkGold.id,
            hasSeparateDarkSlot: false,
            for: .light
        )
        #expect(resolved.id == BuiltInThemes.classic.id)
    }

    /// The read side of the same flag. Nil is not "light": it means the device
    /// decides, and it is what keeps the preview and every color well following
    /// the user's actual appearance. Returning `.light` instead would seed a
    /// dark-device user's whole palette from light-mode values — and the wells
    /// freeze what they are seeded with as fixed hex.
    @Test func theGalleryPreviewsTheDeviceAppearanceWhileTheSlotsShareOneSelection() {
        #expect(StyleSettingsView.appearanceOverride(hasSeparateDarkSlot: false, editingAppearance: .light) == nil)
        #expect(StyleSettingsView.appearanceOverride(hasSeparateDarkSlot: false, editingAppearance: .dark) == nil)
    }

    @Test func theGalleryPreviewsTheEditedSlotWhileTheSlotsAreSeparate() {
        #expect(StyleSettingsView.appearanceOverride(hasSeparateDarkSlot: true, editingAppearance: .light) == .light)
        #expect(StyleSettingsView.appearanceOverride(hasSeparateDarkSlot: true, editingAppearance: .dark) == .dark)
    }

    /// Which row wears the checkmark, and which theme the preview and the
    /// editor open on.
    @Test func theActiveThemeIsTheEditedSlot() {
        let light = BuiltInThemes.classic.id
        let dark = BuiltInThemes.darkGold.id
        func active(_ hasSeparateDarkSlot: Bool, _ editingAppearance: ColorScheme) -> String {
            StyleSettingsView.activeThemeId(
                light: light,
                dark: dark,
                hasSeparateDarkSlot: hasSeparateDarkSlot,
                editingAppearance: editingAppearance
            )
        }
        #expect(active(true, .dark) == dark)
        #expect(active(true, .light) == light)
        // Joined, the dark slot is not what renders — showing it selected would
        // point at a theme the keyboard is not using.
        #expect(active(false, .dark) == light)
        #expect(active(false, .light) == light)
    }
}

// MARK: - Row controls

struct ThemeRowControlTests {
    /// The hit area has to stay a real target at the small text sizes and stay
    /// on screen at the large ones: three unclamped AX5 targets do not fit a
    /// phone's width.
    @Test func iconTargetStaysWithinItsBounds() {
        #expect(StyleSettingsView.iconTargetSide(scaledFrom: 36) == 44)
        #expect(StyleSettingsView.iconTargetSide(scaledFrom: 44) == 44)
        #expect(StyleSettingsView.iconTargetSide(scaledFrom: 137) == 64)
    }

    /// The glyph must fit inside its own hit area, or it overflows into the
    /// neighbouring button's — the bug that let a tap on the trash open the
    /// editor.
    ///
    /// Measured on the rendered symbol, not on the point size: `.frame` does
    /// not clip a non-resizable `Image`, and an SF Symbol's bounding box runs
    /// to roughly 1.3× its point size (`plus.square.on.square` is the widest of
    /// the three at ~1.30, `trash` the tallest at ~1.24). Comparing the point
    /// size to the side it was derived from would hold for any fraction below
    /// 1 and miss exactly that overflow.
    @Test func iconGlyphFitsItsTargetAtEveryTextSize() throws {
        let icons = ThemeRowAction.allCases.compactMap(StyleSettingsView.icon(for:))
        #expect(icons.count == 3)
        for scaled in stride(from: CGFloat(20), through: 200, by: 10) {
            let side = StyleSettingsView.iconTargetSide(scaledFrom: scaled)
            let configuration = UIImage.SymbolConfiguration(pointSize: side * StyleSettingsView.iconGlyphFraction)
            for icon in icons {
                let rendered = try #require(UIImage(systemName: icon.systemImage, withConfiguration: configuration))
                #expect(rendered.size.width <= side, "\(icon.systemImage) is \(rendered.size.width) pt wide in a \(side) pt target")
                #expect(rendered.size.height <= side, "\(icon.systemImage) is \(rendered.size.height) pt tall in a \(side) pt target")
            }
        }
    }

    /// Two copies that differ only in radius or border must not render as the
    /// same grey square in the list.
    @Test func swatchScalesRadiusAndBorderToItsKey() {
        #expect(ThemeSwatch.swatchRadius(forKeyRadius: 0) == 0)
        #expect(ThemeSwatch.swatchRadius(forKeyRadius: 24) > ThemeSwatch.swatchRadius(forKeyRadius: 8))
        // 24 pt is the slider maximum; scaled it must stay under half the
        // 30 pt key, or every rounded theme collapses into the same pill.
        #expect(ThemeSwatch.swatchRadius(forKeyRadius: 24) < 15)
        // A hairline border stays visible instead of scaling into nothing.
        #expect(ThemeSwatch.swatchBorderWidth(forKeyBorderWidth: 0.5) >= 0.5)
        #expect(ThemeSwatch.swatchBorderWidth(forKeyBorderWidth: 4) > ThemeSwatch.swatchBorderWidth(forKeyBorderWidth: 0.5))
    }
}

// MARK: - Key border

/// The border toggle is the editor's one *coupled* write: switching it on has
/// to bring a width with it. It lives on the model so the coupling is testable
/// — inline in the binding, deleting it broke nothing.
struct KeyBorderToggleTests {
    @Test func turningTheBorderOnGivesAThemeWithoutOneAVisibleWidth() {
        var theme = BuiltInThemes.classic
        theme.id = UUID().uuidString
        #expect(theme.keyBorder == nil)
        #expect(theme.keyBorderWidth == 0)

        theme.setKeyBorder(true)
        #expect(theme.keyBorder != nil)
        // `KeyView.filled` draws no border at width 0, and the width slider's
        // range starts here — a stored 0 sits outside it.
        #expect(theme.keyBorderWidth >= KeyboardThemeDefinition.minimumKeyBorderWidth)
    }

    @Test func turningTheBorderOffRemovesIt() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString

        theme.setKeyBorder(false)
        #expect(theme.keyBorder == nil)
        // Only the border is switched off; nothing else in the theme moves.
        #expect(theme.keyColor == BuiltInThemes.darkGold.keyColor)
        #expect(theme.keyBorderWidth == BuiltInThemes.darkGold.keyBorderWidth)
    }

    @Test func turningTheBorderOnKeepsTheColorAndWidthTheThemeAlreadyHas() {
        var theme = BuiltInThemes.darkGold
        theme.id = UUID().uuidString
        theme.keyBorderWidth = 3

        theme.setKeyBorder(true)
        #expect(theme.keyBorder == BuiltInThemes.darkGold.keyBorder)
        // The width only gets a floor when there is none to keep.
        #expect(theme.keyBorderWidth == 3)
    }
}

// MARK: - Color wells

/// The editor's wells seed from the appearance the theme is *destined for*,
/// because the setter freezes the pick as a fixed hex.
struct ThemeColorAppearanceTests {
    @Test func semanticColorsResolveDifferentlyPerAppearance() throws {
        let light = try #require(ThemeColor.semantic(.systemBackground).resolvedColor(in: .light))
        let dark = try #require(ThemeColor.semantic(.systemBackground).resolvedColor(in: .dark))
        #expect(HexColor.string(from: light) != HexColor.string(from: dark))
    }

    /// `.systemBackground` alone proves little: it is a bridged UIKit color to
    /// begin with, so it survives `UIColor(_:)` by construction. The roles the
    /// wells actually read are SwiftUI-native semantic colors carrying an
    /// opacity, where the bridge is documented best-effort and could flatten to
    /// the ambient trait — and if it did, a dark slot would be seeded, and then
    /// frozen, with light-mode values.
    @Test func semanticColorsWithOpacityStillResolvePerAppearance() throws {
        // The three the built-ins actually use: hint letter, hint symbol, trail.
        let roles: [ThemeColor] = [
            .semantic(.primary, opacity: 0.65),
            .semantic(.secondary, opacity: 0.55),
            .semantic(.primary, opacity: KeyboardConstants.GestureTrail.opacity),
        ]
        for color in roles {
            let light = try #require(ThemeContrast.components(of: color, in: .light))
            let dark = try #require(ThemeContrast.components(of: color, in: .dark))
            #expect(light.rgb != dark.rgb, "\(color) flattened to one value across appearances")
            // The opacity has to survive the bridge too, or an inverted but
            // opaque value would pass the inequality above.
            #expect(light.alpha < 1)
            #expect(abs(light.alpha - dark.alpha) < 0.01)
        }
    }

    /// One absolute pin, so a bridge that flattened *both* sides to the same
    /// ambient value could not pass by merely differing.
    @Test func primaryResolvesNearBlackInLightAndNearWhiteInDark() throws {
        let color = ThemeColor.semantic(.primary)
        let light = try #require(ThemeContrast.components(of: color, in: .light))
        let dark = try #require(ThemeContrast.components(of: color, in: .dark))
        #expect(ThemeContrast.luminance(of: light, over: light.rgb) < 0.05)
        #expect(ThemeContrast.luminance(of: dark, over: dark.rgb) > 0.9)
    }

    @Test func fixedColorsAreAppearanceIndependent() throws {
        let color = ThemeColor.fixed(hex: "#D1AA05")
        let light = try #require(color.resolvedColor(in: .light))
        let dark = try #require(color.resolvedColor(in: .dark))
        #expect(HexColor.string(from: light) == "#D1AA05")
        #expect(HexColor.string(from: dark) == "#D1AA05")
    }

    @Test func adaptiveColorsTakeTheirSideOfThePair() throws {
        let color = ThemeColor.adaptive(light: "#000000", dark: "#FFFFFF")
        let light = try #require(color.resolvedColor(in: .light))
        let dark = try #require(color.resolvedColor(in: .dark))
        #expect(HexColor.string(from: light) == "#000000")
        #expect(HexColor.string(from: dark) == "#FFFFFF")
    }
}
