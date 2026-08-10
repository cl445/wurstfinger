//
//  ResolvedTheme.swift
//  Wurstfinger
//
//  The flat, render-ready form of a theme. Resolved once per keyboard root,
//  injected via Environment, and Equatable so SwiftUI can skip re-renders.
//

import SwiftUI

struct ResolvedTheme: Equatable {
    let boardBackground: Color
    let keyColor: Color
    let keyColorActive: Color
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
    let gestureTrail: Color

    /// Whether the keys render as the bar/glass material, so the grid wraps
    /// them in a `GlassEffectContainer` on iOS 26 (glass cannot sample other
    /// glass) and each key applies the effect instead of a fill. Stored rather
    /// than derived from a resolved `keySurface`: that field would have no
    /// reader other than its own getter.
    let hasGlassKeys: Bool
}

extension KeyboardThemeDefinition {
    /// Minimum board alpha that still receives touches. A keyboard
    /// extension's input view only delivers touches on rendered surfaces, so
    /// a fully transparent board would drop taps between keys (#198).
    static let minimumBoardOpacity = 0.02

    /// The board a glass theme paints: nearly clear so the backdrop comes
    /// through, but still rendered (#198). The literal is the value of the
    /// shipped Liquid Glass look; that it coincides with `minimumBoardOpacity`
    /// is a coincidence, not a derivation.
    static let glassBoardColor: ThemeColor = .semantic(.gray, opacity: 0.02)

    /// Resolves the definition into renderable values. Unparsable hex colors
    /// fall back to the Classic value of the same role, so a broken user
    /// theme degrades gracefully instead of rendering invisibly.
    func resolved() -> ResolvedTheme {
        let fallback = BuiltInThemes.classic
        let board: ThemeColor = boardSurface == .glass
            ? Self.glassBoardColor
            : boardColor.withMinimumOpacity(Self.minimumBoardOpacity)
        return ResolvedTheme(
            boardBackground: board.resolvedColor(fallback: fallback.boardColor),
            keyColor: keyColor.resolvedColor(fallback: fallback.keyColor),
            keyColorActive: keyColorActive.resolvedColor(fallback: fallback.keyColorActive),
            keyBorder: keyBorder.flatMap { $0.resolvedColor() },
            keyBorderWidth: CGFloat(keyBorderWidth),
            cornerRadius: CGFloat(cornerRadius),
            mainLabel: mainLabel.resolvedColor(fallback: fallback.mainLabel),
            utilityLabel: utilityLabel.resolvedColor(fallback: fallback.utilityLabel),
            hintLetter: hintLetter.resolvedColor(fallback: fallback.hintLetter),
            hintSymbol: hintSymbol.resolvedColor(fallback: fallback.hintSymbol),
            hintIconProminent: hintIconProminent.resolvedColor(fallback: fallback.hintIconProminent),
            hintIconSubtle: hintIconSubtle.resolvedColor(fallback: fallback.hintIconSubtle),
            gestureTrail: gestureTrail.resolvedColor(fallback: fallback.gestureTrail),
            hasGlassKeys: keySurface == .glass
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
