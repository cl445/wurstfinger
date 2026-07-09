//
//  ThemeColor.swift
//  Wurstfinger
//
//  Color and fill primitives of the theme engine.
//

import SwiftUI
import UIKit

// MARK: - Semantic Tokens

/// Semantic system colors a theme can reference. These stay trait-dynamic —
/// themes built from them (like Classic) follow light/dark and other
/// appearance traits exactly like the previously hardcoded system colors.
enum ThemeSemanticToken: String, Codable, CaseIterable {
    case primary
    case secondary
    case gray
    case systemBackground
    case secondarySystemBackground
    case tertiarySystemFill

    var color: Color {
        switch self {
        case .primary: .primary
        case .secondary: .secondary
        case .gray: .gray
        case .systemBackground: Color(.systemBackground)
        case .secondarySystemBackground: Color(.secondarySystemBackground)
        case .tertiarySystemFill: Color(.tertiarySystemFill)
        }
    }
}

// MARK: - ThemeColor

/// A theme color: a semantic system color with an opacity, a fixed hex value
/// (identical in light and dark mode), or an explicit light/dark hex pair.
enum ThemeColor: Equatable {
    case semantic(ThemeSemanticToken, opacity: Double)
    case fixed(hex: String)
    case adaptive(light: String, dark: String)

    /// Convenience for full-opacity semantic colors (enum cases cannot carry
    /// default associated values).
    static func semantic(_ token: ThemeSemanticToken) -> ThemeColor {
        .semantic(token, opacity: 1)
    }

    /// Resolves to a renderable color. Semantic and adaptive colors remain
    /// trait-dynamic, so nothing needs to re-resolve on appearance changes.
    /// Returns nil when a hex value does not parse.
    func resolvedColor() -> Color? {
        switch self {
        case let .semantic(token, opacity):
            // Skip the .opacity wrapper at 1 so Classic renders through the
            // exact same color values as before the theme engine.
            return opacity >= 1 ? token.color : token.color.opacity(opacity)
        case let .fixed(hex):
            return HexColor.color(from: hex)
        case let .adaptive(light, dark):
            guard let lightComponents = HexColor.parse(light),
                  let darkComponents = HexColor.parse(dark) else { return nil }
            return Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? HexColor.uiColor(from: darkComponents)
                    : HexColor.uiColor(from: lightComponents)
            })
        }
    }

    /// Builds a fixed color from a SwiftUI color — the form the editor's color
    /// wells write. A color with no RGB representation (e.g. a pattern) falls
    /// back to opaque black rather than dropping the edit.
    static func from(_ color: Color) -> ThemeColor {
        .fixed(hex: HexColor.string(from: color) ?? "#000000")
    }

    /// The same color with its opacity raised to at least `minimum`. Used to
    /// keep the board fill touchable (a keyboard extension's input view only
    /// delivers touches on rendered surfaces; see DataDrivenKeyboardRootView).
    func withMinimumOpacity(_ minimum: Double) -> ThemeColor {
        switch self {
        case let .semantic(token, opacity):
            return .semantic(token, opacity: max(opacity, minimum))
        case let .fixed(hex):
            guard let components = HexColor.parse(hex), components.alpha < minimum else { return self }
            return .fixed(hex: HexColor.string(from: .init(rgb: components.rgb, alpha: minimum)))
        case let .adaptive(light, dark):
            let raise = { (hex: String) -> String in
                guard let components = HexColor.parse(hex), components.alpha < minimum else { return hex }
                return HexColor.string(from: .init(rgb: components.rgb, alpha: minimum))
            }
            return .adaptive(light: raise(light), dark: raise(dark))
        }
    }
}

/// Explicit, stable persisted form: `{"type": "semantic"|"fixed"|"adaptive", …}`.
/// The encoding is the future export wire format — keep it disciplined.
extension ThemeColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, token, opacity, hex, light, dark
    }

    private enum Kind: String, Codable {
        case semantic, fixed, adaptive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .semantic:
            let token = try container.decode(ThemeSemanticToken.self, forKey: .token)
            let opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
            self = .semantic(token, opacity: opacity)
        case .fixed:
            self = try .fixed(hex: container.decode(String.self, forKey: .hex))
        case .adaptive:
            self = try .adaptive(
                light: container.decode(String.self, forKey: .light),
                dark: container.decode(String.self, forKey: .dark)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .semantic(token, opacity):
            try container.encode(Kind.semantic, forKey: .type)
            try container.encode(token, forKey: .token)
            try container.encode(opacity, forKey: .opacity)
        case let .fixed(hex):
            try container.encode(Kind.fixed, forKey: .type)
            try container.encode(hex, forKey: .hex)
        case let .adaptive(light, dark):
            try container.encode(Kind.adaptive, forKey: .type)
            try container.encode(light, forKey: .light)
            try container.encode(dark, forKey: .dark)
        }
    }
}

// MARK: - ThemeFill

/// A fill: either a theme color or the system bar material (Liquid Glass).
enum ThemeFill: Equatable {
    case color(ThemeColor)
    case material
}

extension ThemeFill: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, color
    }

    private enum Kind: String, Codable {
        case color, material
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .color:
            self = try .color(container.decode(ThemeColor.self, forKey: .color))
        case .material:
            self = .material
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .color(color):
            try container.encode(Kind.color, forKey: .type)
            try container.encode(color, forKey: .color)
        case .material:
            try container.encode(Kind.material, forKey: .type)
        }
    }
}
