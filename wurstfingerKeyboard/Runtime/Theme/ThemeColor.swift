//
//  ThemeColor.swift
//  Wurstfinger
//
//  Color primitives of the theme engine.
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
            guard let color = AdaptiveColors.color(light: light, dark: dark) else { return nil }
            return Color(color)
        }
    }

    /// The color as it renders in one specific appearance, frozen to a static
    /// value.
    ///
    /// The editor's color wells need this. A semantic or adaptive color
    /// resolves against the environment it is *displayed* in, so a well drawn
    /// in a light-mode sheet would show a dark-slot theme's label in its light
    /// value — and because the well's setter freezes whatever it was seeded
    /// with, that wrong reading gets written into the theme permanently.
    func resolvedColor(in colorScheme: ColorScheme) -> Color? {
        guard let color = resolvedColor() else { return nil }
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        return Color(UIColor(color).resolvedColor(with: traits))
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

// MARK: - Adaptive Colors

/// The trait-dynamic colors behind `ThemeColor.adaptive`, one per light/dark
/// hex pair.
///
/// They have to be shared rather than rebuilt: `UIColor(dynamicProvider:)`
/// hands back a fresh object every call and two of those never compare equal,
/// so resolving one theme twice would yield two unequal `ResolvedTheme`s —
/// every root body evaluation would then read as a theme change and invalidate
/// the grid plus every key in it.
///
/// A color is fully determined by its pair, so entries never go stale and the
/// table only grows with the number of distinct pairs across the user's themes
/// (no UI writes adaptive colors today). Host app and extension are separate
/// processes with their own table; the lock guards against resolution off the
/// main thread.
private enum AdaptiveColors {
    private struct Pair: Hashable {
        var light: String
        var dark: String
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var colors: [Pair: UIColor] = [:]

    /// The dynamic color for a hex pair, or nil when either hex is unparsable.
    static func color(light: String, dark: String) -> UIColor? {
        let pair = Pair(light: light, dark: dark)
        lock.lock()
        defer { lock.unlock() }
        if let cached = colors[pair] {
            return cached
        }
        guard let lightComponents = HexColor.parse(light),
              let darkComponents = HexColor.parse(dark) else { return nil }
        let color = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? HexColor.uiColor(from: darkComponents)
                : HexColor.uiColor(from: lightComponents)
        }
        colors[pair] = color
        return color
    }
}

/// Explicit, stable persisted form: `{"type": "semantic"|"fixed"|"adaptive", …}`.
/// The encoding is the future export wire format — keep it disciplined.
extension ThemeColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, token, opacity, hex, light, dark
    }

    private enum EncodedType: String, Codable {
        case semantic, fixed, adaptive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EncodedType.self, forKey: .type) {
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
            try container.encode(EncodedType.semantic, forKey: .type)
            try container.encode(token, forKey: .token)
            try container.encode(opacity, forKey: .opacity)
        case let .fixed(hex):
            try container.encode(EncodedType.fixed, forKey: .type)
            try container.encode(hex, forKey: .hex)
        case let .adaptive(light, dark):
            try container.encode(EncodedType.adaptive, forKey: .type)
            try container.encode(light, forKey: .light)
            try container.encode(dark, forKey: .dark)
        }
    }
}
