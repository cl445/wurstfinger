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

    // Surfaces
    /// Fill behind the whole keyboard; shows through the gaps between keys.
    var boardBackground: ThemeFill
    var keyFill: ThemeFill
    /// Key fill while pressed.
    var keyFillActive: ThemeFill
    /// nil = no border overlay at all (Classic).
    var keyBorder: ThemeColor?
    var keyBorderWidth: Double
    var cornerRadius: Double

    // Labels
    var mainLabel: ThemeColor
    var utilityLabel: ThemeColor
    var hintLetter: ThemeColor
    var hintSymbol: ThemeColor
    /// Globe/dismiss icon hints and the language label.
    var hintIconProminent: ThemeColor
    /// Copy/cut/paste icon hints.
    var hintIconSubtle: ThemeColor
}

/// Tolerant, stable persistence: explicit keys, and every field except
/// id/name and the optional `keyBorder` falls back to its Classic value, so
/// themes written by newer app versions (with additional fields) still decode.
/// `keyBorder` is optional — an absent key means "no border", matching Classic.
extension KeyboardThemeDefinition: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name
        case boardBackground, keyFill, keyFillActive
        case keyBorder, keyBorderWidth, cornerRadius
        case mainLabel, utilityLabel
        case hintLetter, hintSymbol, hintIconProminent, hintIconSubtle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BuiltInThemes.classic
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        boardBackground = try container.decodeIfPresent(ThemeFill.self, forKey: .boardBackground)
            ?? fallback.boardBackground
        keyFill = try container.decodeIfPresent(ThemeFill.self, forKey: .keyFill) ?? fallback.keyFill
        keyFillActive = try container.decodeIfPresent(ThemeFill.self, forKey: .keyFillActive)
            ?? fallback.keyFillActive
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
    }
}
