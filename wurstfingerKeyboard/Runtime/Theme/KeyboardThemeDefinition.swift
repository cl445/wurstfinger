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
/// id/name and the optional `keyBorder` falls back to its Classic value, so
/// themes written by newer app versions (with additional fields) still decode.
/// `keyBorder` is optional — an absent key means "no border", matching Classic.
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
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Surface styles decode through their raw string rather than through
        // the enum: `decodeIfPresent(BoardSurfaceStyle.self)` *throws* on an
        // unknown value, and `ThemeStore.Archive.FailableTheme` swallows that
        // throw by discarding the whole theme — one unreadable field would cost
        // the user every color in it, contradicting the tolerance the rest of
        // this initializer promises.
        let boardRaw = (try? container.decodeIfPresent(String.self, forKey: .boardSurface)) ?? nil
        boardSurface = boardRaw.flatMap(BoardSurfaceStyle.init(rawValue:)) ?? fallback.boardSurface
        let keyRaw = (try? container.decodeIfPresent(String.self, forKey: .keySurface)) ?? nil
        keySurface = keyRaw.flatMap(KeySurfaceStyle.init(rawValue:)) ?? fallback.keySurface
        boardColor = try container.decodeIfPresent(ThemeColor.self, forKey: .boardColor) ?? fallback.boardColor
        keyColor = try container.decodeIfPresent(ThemeColor.self, forKey: .keyColor) ?? fallback.keyColor
        keyColorActive = try container.decodeIfPresent(ThemeColor.self, forKey: .keyColorActive)
            ?? fallback.keyColorActive
        keyBorder = try container.decodeIfPresent(ThemeColor.self, forKey: .keyBorder)
        keyBorderWidth = try container.decodeIfPresent(Double.self, forKey: .keyBorderWidth)
            ?? fallback.keyBorderWidth
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? fallback.cornerRadius
        mainLabel = try container.decodeIfPresent(ThemeColor.self, forKey: .mainLabel) ?? fallback.mainLabel
        utilityLabel = try container.decodeIfPresent(ThemeColor.self, forKey: .utilityLabel)
            ?? fallback.utilityLabel
        hintLetter = try container.decodeIfPresent(ThemeColor.self, forKey: .hintLetter) ?? fallback.hintLetter
        hintSymbol = try container.decodeIfPresent(ThemeColor.self, forKey: .hintSymbol) ?? fallback.hintSymbol
        hintIconProminent = try container.decodeIfPresent(ThemeColor.self, forKey: .hintIconProminent)
            ?? fallback.hintIconProminent
        hintIconSubtle = try container.decodeIfPresent(ThemeColor.self, forKey: .hintIconSubtle)
            ?? fallback.hintIconSubtle
        gestureTrail = try container.decodeIfPresent(ThemeColor.self, forKey: .gestureTrail)
            ?? fallback.gestureTrail
    }
}
