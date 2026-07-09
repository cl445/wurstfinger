//
//  ResolvedTheme.swift
//  Wurstfinger
//
//  The flat, render-ready form of a theme. Resolved once per keyboard root,
//  injected via Environment, and Equatable so SwiftUI can skip re-renders.
//

import SwiftUI

/// A resolved fill. Deliberately not `AnyShapeStyle` (which is not
/// Equatable, and whose wrapping shifts how `.bar` samples its backdrop);
/// the view layer switches on this and applies `.bar` directly.
enum ResolvedFill: Equatable {
    case color(Color)
    case material
}

struct ResolvedTheme: Equatable {
    let boardBackground: ResolvedFill
    let keyFill: ResolvedFill
    let keyFillActive: ResolvedFill
    /// nil = no border overlay in the view tree.
    let keyBorder: Color?
    let keyBorderWidth: CGFloat
    let cornerRadius: CGFloat
    let mainLabel: Color
    let utilityLabel: Color
    let hintLetter: Color
    let hintSymbol: Color
    let hintIconProminent: Color
    let hintIconSubtle: Color

    /// Whether any key fill is the bar/glass material, so the grid wraps its
    /// keys in a `GlassEffectContainer` on iOS 26 (shared sampling region).
    var usesGlassMaterial: Bool {
        keyFill == .material || keyFillActive == .material
    }
}

extension KeyboardThemeDefinition {
    /// Minimum board alpha that still receives touches. A keyboard
    /// extension's input view only delivers touches on rendered surfaces, so
    /// a fully transparent board would drop taps between keys (#198).
    static let minimumBoardOpacity = 0.02

    /// Resolves the definition into renderable values. Unparsable hex colors
    /// fall back to the Classic value of the same role, so a broken user
    /// theme degrades gracefully instead of rendering invisibly.
    func resolved() -> ResolvedTheme {
        let fallback = BuiltInThemes.classic
        return ResolvedTheme(
            boardBackground: boardBackground
                .withMinimumOpacity(Self.minimumBoardOpacity)
                .resolvedFill(fallback: fallback.boardBackground),
            keyFill: keyFill.resolvedFill(fallback: fallback.keyFill),
            keyFillActive: keyFillActive.resolvedFill(fallback: fallback.keyFillActive),
            keyBorder: keyBorder.flatMap { $0.resolvedColor() },
            keyBorderWidth: CGFloat(keyBorderWidth),
            cornerRadius: CGFloat(cornerRadius),
            mainLabel: mainLabel.resolvedColor(fallback: fallback.mainLabel),
            utilityLabel: utilityLabel.resolvedColor(fallback: fallback.utilityLabel),
            hintLetter: hintLetter.resolvedColor(fallback: fallback.hintLetter),
            hintSymbol: hintSymbol.resolvedColor(fallback: fallback.hintSymbol),
            hintIconProminent: hintIconProminent.resolvedColor(fallback: fallback.hintIconProminent),
            hintIconSubtle: hintIconSubtle.resolvedColor(fallback: fallback.hintIconSubtle)
        )
    }
}

extension ThemeColor {
    /// Resolves, falling back to another theme color (whose own resolution
    /// is expected to be infallible — built-ins only use valid values).
    fileprivate func resolvedColor(fallback: ThemeColor) -> Color {
        resolvedColor() ?? fallback.resolvedColor() ?? .primary
    }
}

extension ThemeFill {
    fileprivate func withMinimumOpacity(_ minimum: Double) -> ThemeFill {
        switch self {
        case let .color(color): .color(color.withMinimumOpacity(minimum))
        case .material: .material
        }
    }

    fileprivate func resolvedFill(fallback: ThemeFill) -> ResolvedFill {
        switch self {
        case let .color(color):
            if let resolved = color.resolvedColor() {
                return .color(resolved)
            }
            return fallback.resolvedFill(fallback: .color(.semantic(.secondarySystemBackground)))
        case .material:
            return .material
        }
    }
}
