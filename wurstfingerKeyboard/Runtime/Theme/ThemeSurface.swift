//
//  ThemeSurface.swift
//  Wurstfinger
//
//  How a theme paints its two surfaces: the board behind the keys, and the
//  keys themselves. Separate enums because "glass" means something different
//  on each — see below.
//

import Foundation

/// How the board behind the keys is painted.
///
/// `glass` is deliberately **not** a material. It paints
/// `KeyboardThemeDefinition.glassBoardColor`, a nearly clear constant color, so
/// the `UIInputView(.keyboard)` backdrop reads through it while the board stays
/// a *rendered* surface — a keyboard extension only receives touches over
/// rendered pixels, so a truly transparent board would drop every tap that
/// lands in the gaps between keys (#198).
enum BoardSurfaceStyle: String, Codable {
    case color
    case glass
}

/// How a key is painted.
///
/// Here `glass` *is* a material: native Liquid Glass on iOS 26, the `.bar`
/// material on older systems.
enum KeySurfaceStyle: String, Codable {
    case color
    case glass
}
