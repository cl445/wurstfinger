//
//  HexColor.swift
//  Wurstfinger
//
//  Parsing and formatting of hex color strings, the storage format for
//  fixed theme colors.
//

import SwiftUI
import UIKit

/// Parses and formats `#RRGGBB` / `#RRGGBBAA` strings.
enum HexColor {
    /// A parsed hex color: packed RGB plus separate alpha (0...1).
    struct Components: Equatable {
        var rgb: UInt32
        var alpha: Double
    }

    /// Parses `#RRGGBB` or `#RRGGBBAA` (case-insensitive, `#` optional).
    static func parse(_ string: String) -> Components? {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        switch hex.count {
        case 6:
            guard let value = UInt32(hex, radix: 16) else { return nil }
            return Components(rgb: value, alpha: 1)
        case 8:
            guard let value = UInt64(hex, radix: 16) else { return nil }
            return Components(rgb: UInt32(value >> 8), alpha: Double(value & 0xFF) / 255)
        default:
            return nil
        }
    }

    static func color(from string: String) -> Color? {
        parse(string).map(color(from:))
    }

    static func color(from components: Components) -> Color {
        Color(
            red: Double((components.rgb >> 16) & 0xFF) / 255,
            green: Double((components.rgb >> 8) & 0xFF) / 255,
            blue: Double(components.rgb & 0xFF) / 255,
            opacity: components.alpha
        )
    }

    static func uiColor(from components: Components) -> UIColor {
        UIColor(
            red: Double((components.rgb >> 16) & 0xFF) / 255,
            green: Double((components.rgb >> 8) & 0xFF) / 255,
            blue: Double(components.rgb & 0xFF) / 255,
            alpha: components.alpha
        )
    }

    /// Formats as `#RRGGBB`, appending the alpha byte (`#RRGGBBAA`) only when
    /// it is not fully opaque. The opacity check is made on the rounded byte,
    /// not the raw value: an alpha like 0.999 rounds to 0xFF, and emitting
    /// `#RRGGBBFF` would re-parse to 1.0 anyway — so it is formatted as the
    /// opaque `#RRGGBB`, keeping the round-trip idempotent.
    static func string(from components: Components) -> String {
        let alphaByte = UInt32((min(max(components.alpha, 0), 1) * 255).rounded())
        if alphaByte >= 255 {
            return String(format: "#%06X", components.rgb)
        }
        return String(format: "#%06X%02X", components.rgb, alphaByte)
    }

    /// Formats a runtime color, or nil when its components cannot be
    /// resolved into RGB (e.g. pattern-based colors).
    static func string(from color: Color) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        func byte(_ value: CGFloat) -> UInt32 {
            UInt32((min(max(value, 0), 1) * 255).rounded())
        }
        let rgb = (byte(red) << 16) | (byte(green) << 8) | byte(blue)
        return string(from: Components(rgb: rgb, alpha: Double(alpha)))
    }
}
