//
//  KeyboardThemeDefinition.swift
//  Wurstfinger
//
//  The persisted description of a keyboard theme. A theme is data, not a
//  code path: built-ins (Classic, Liquid Glass, Dark Gold) and user themes
//  all render through the same resolver.
//

import Foundation

struct KeyboardThemeDefinition: Identifiable, Equatable {
    /// Built-ins use stable string ids ("classic", …); user themes use UUID
    /// strings. Whether a theme is built-in is derived from the id — it is
    /// never trusted from persisted data.
    var id: String
    var name: String

    // MARK: Surfaces

    // Surface style and surface color are independent, and the colors stay in
    // the model even while glass is switched on: **the key color is never the
    // glass tint** (that is the constant `KeyView.glassTint`). Toggling glass
    // off therefore restores the user's own color losslessly, and the editor
    // needs no shadow copy of the palette. Serving one value as both would
    // render wrong in both directions — a Classic copy with glass on would
    // become an opaque tinted pane with no glass in it, and a Liquid Glass copy
    // with glass off would leave nearly invisible keys.

    var boardSurface: BoardSurfaceStyle
    /// Board fill for `boardSurface == .color`; shows through the gaps between
    /// keys. A glass board paints `Self.glassBoardColor` instead.
    var boardColor: ThemeColor
    var keySurface: KeySurfaceStyle
    /// Key fill for `keySurface == .color`.
    var keyColor: ThemeColor
    /// Key fill while pressed. Glass keys have no visible pressed state.
    var keyColorActive: ThemeColor
    /// nil = no border overlay at all (Classic).
    var keyBorder: ThemeColor?
    var keyBorderWidth: Double
    var cornerRadius: Double

    // MARK: Labels

    var mainLabel: ThemeColor
    var utilityLabel: ThemeColor
    var hintLetter: ThemeColor
    var hintSymbol: ThemeColor
    /// Globe/dismiss icon hints and the language label.
    var hintIconProminent: ThemeColor
    /// Copy/cut/paste icon hints.
    var hintIconSubtle: ThemeColor

    /// Color of the swipe trail. Its alpha is used literally — the draw path
    /// multiplies in the fade-out and nothing else.
    var gestureTrail: ThemeColor
}

/// Tolerant, stable persistence: explicit keys, and every field except
/// id/name and the optional `keyBorder` falls back to its Classic value, so a
/// theme written by another app version — with additional fields, unknown enum
/// cases, or a role it stores differently — still decodes.
/// `keyBorder` is optional — an absent or unreadable value means "no border",
/// which is Classic's value for that role.
extension KeyboardThemeDefinition: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name
        case boardSurface, boardColor
        case keySurface, keyColor, keyColorActive
        case keyBorder, keyBorderWidth, cornerRadius
        case mainLabel, utilityLabel
        case hintLetter, hintSymbol, hintIconProminent, hintIconSubtle
        case gestureTrail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BuiltInThemes.classic
        let legacy = LegacySurfaces(decoder: decoder)
        // Only id and name may fail the decode. Everything else reads through
        // `decodeIfReadable`, which degrades a malformed value the same way a
        // missing one degrades: `ThemeStore.Archive.FailableTheme` turns any
        // throw in here into the loss of the whole theme, and the next
        // save/delete rewrites the archive from that lossy read — so one
        // unreadable field would cost the user every color in the theme,
        // permanently.
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        boardSurface = container.decodeIfReadable(BoardSurfaceStyle.self, forKey: .boardSurface)
            ?? legacy.boardSurface ?? fallback.boardSurface
        boardColor = container.decodeIfReadable(ThemeColor.self, forKey: .boardColor)
            ?? legacy.boardColor ?? fallback.boardColor
        keySurface = container.decodeIfReadable(KeySurfaceStyle.self, forKey: .keySurface)
            ?? legacy.keySurface ?? fallback.keySurface
        keyColor = container.decodeIfReadable(ThemeColor.self, forKey: .keyColor)
            ?? legacy.keyColor ?? fallback.keyColor
        keyColorActive = container.decodeIfReadable(ThemeColor.self, forKey: .keyColorActive)
            ?? legacy.keyColorActive ?? fallback.keyColorActive
        keyBorder = container.decodeIfReadable(ThemeColor.self, forKey: .keyBorder)
        keyBorderWidth = container.decodeIfReadable(Double.self, forKey: .keyBorderWidth) ?? fallback.keyBorderWidth
        cornerRadius = container.decodeIfReadable(Double.self, forKey: .cornerRadius) ?? fallback.cornerRadius
        mainLabel = container.decodeIfReadable(ThemeColor.self, forKey: .mainLabel) ?? fallback.mainLabel
        utilityLabel = container.decodeIfReadable(ThemeColor.self, forKey: .utilityLabel) ?? fallback.utilityLabel
        hintLetter = container.decodeIfReadable(ThemeColor.self, forKey: .hintLetter) ?? fallback.hintLetter
        hintSymbol = container.decodeIfReadable(ThemeColor.self, forKey: .hintSymbol) ?? fallback.hintSymbol
        hintIconProminent = container.decodeIfReadable(ThemeColor.self, forKey: .hintIconProminent)
            ?? fallback.hintIconProminent
        hintIconSubtle = container.decodeIfReadable(ThemeColor.self, forKey: .hintIconSubtle)
            ?? fallback.hintIconSubtle
        gestureTrail = container.decodeIfReadable(ThemeColor.self, forKey: .gestureTrail) ?? fallback.gestureTrail
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or nil when the key is absent **or its value is
    /// unreadable**. `decodeIfPresent` only tolerates the first of those; in
    /// the theme model both have to degrade the same way, because a throw
    /// discards the whole theme (see `KeyboardThemeDefinition.init(from:)`).
    fileprivate func decodeIfReadable<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}

// MARK: - Pre-Rework Surface Keys

/// The surfaces as unreleased dev builds (M2/M3) persisted them: one
/// `ThemeFill` union per surface under `boardBackground` / `keyFill` /
/// `keyFillActive`, encoded as `{"type": "color", "color": …}` or
/// `{"type": "material"}`.
///
/// Read as a last-resort fallback before Classic. Ignoring these keys is not a
/// clean degradation: the label roles decode fine, so an old Dark Gold copy
/// would come back as gold labels on Classic's near-white key — about 2.2:1 —
/// and the next save would persist that. Deliberately absent from
/// `KeyboardThemeDefinition.CodingKeys`, so nothing ever writes the shape back.
/// Delete once no dev install predates the surface rework.
private struct LegacySurfaces {
    private enum CodingKeys: String, CodingKey {
        case boardBackground, keyFill, keyFillActive
    }

    private enum FillKeys: String, CodingKey {
        case type, color
    }

    /// One legacy fill: the color it carried, if any, and whether it asked for
    /// the material — which the rework turned into the `glass` surface style.
    private struct Fill {
        var isMaterial: Bool
        var color: ThemeColor?
    }

    private var board: Fill?
    private var key: Fill?
    private var keyActive: Fill?

    init(decoder: Decoder) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        board = Self.fill(in: container, forKey: .boardBackground)
        key = Self.fill(in: container, forKey: .keyFill)
        keyActive = Self.fill(in: container, forKey: .keyFillActive)
    }

    var boardSurface: BoardSurfaceStyle? {
        board.map { $0.isMaterial ? .glass : .color }
    }

    var boardColor: ThemeColor? {
        board?.color
    }

    var keySurface: KeySurfaceStyle? {
        key.map { $0.isMaterial ? .glass : .color }
    }

    var keyColor: ThemeColor? {
        key?.color
    }

    var keyColorActive: ThemeColor? {
        keyActive?.color
    }

    private static func fill(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Fill? {
        guard let fill = try? container.nestedContainer(keyedBy: FillKeys.self, forKey: key) else { return nil }
        return Fill(
            isMaterial: fill.decodeIfReadable(String.self, forKey: .type) == "material",
            color: fill.decodeIfReadable(ThemeColor.self, forKey: .color)
        )
    }
}
