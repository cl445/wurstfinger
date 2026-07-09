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

    /// Formats as `#RRGGBB`, appending the alpha byte (`#RRGGBBAA`) only
    /// when it is below 1.
    static func string(from components: Components) -> String {
        if components.alpha >= 1 {
            return String(format: "#%06X", components.rgb)
        }
        let alphaByte = UInt32((min(max(components.alpha, 0), 1) * 255).rounded())
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

    /// Relative luminance (0...1), sufficient for light/dark decisions.
    static func luminance(of rgb: UInt32) -> Double {
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Multiplies each RGB channel by `factor`, clamping to 0...255.
    static func scaled(_ rgb: UInt32, by factor: Double) -> UInt32 {
        func scale(_ channel: UInt32) -> UInt32 {
            UInt32(min(max(Double(channel) * factor, 0), 255))
        }
        let red = scale((rgb >> 16) & 0xFF)
        let green = scale((rgb >> 8) & 0xFF)
        let blue = scale(rgb & 0xFF)
        return (red << 16) | (green << 8) | blue
    }
}
