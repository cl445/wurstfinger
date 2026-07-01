//
//  TouchRegime.swift
//  Wurstfinger
//
//  Discrete learning regime for the touch-offset correction (spec §3.1).
//  A separate offset model is maintained per regime. Orientation comes from the
//  controller; the posture class is **chosen explicitly by the user** (setting
//  `touchOffsetPosture`) rather than auto-detected — iOS gives third-party
//  keyboards no posture state, and deriving it from keyboard size/position
//  proved unreliable (and a wrong split can actively mis-correct, §3.1/§11.1).
//

import Foundation

/// Screen-orientation dimension of a regime.
enum RegimeOrientation: String, Codable, CaseIterable {
    case portrait
    case landscape
}

/// Biomechanical posture class, **chosen explicitly by the user** (§3.1).
/// `Floating` (iPad) is intentionally **not** a v1 class.
enum PostureClass: String, Codable, CaseIterable {
    /// One-handed, right thumb (single pivot bottom-right). Default: one-handed
    /// use is the common case, right thumb the most common hand (§3.1).
    case oneThumbRight
    /// One-handed, left thumb (single pivot bottom-left).
    case oneThumbLeft
    /// Two-thumb typing. Uses a left/right split reach surface (§3.2).
    case twoThumb

    /// Whether this posture uses the left/right split reach surface (§3.2).
    var usesSplitSurface: Bool {
        self == .twoThumb
    }

    /// The declared default when the user has not chosen yet (§3.1).
    static var defaultDeclared: PostureClass {
        .oneThumbRight
    }

    /// Parses a persisted setting string, falling back to the declared default
    /// for missing/unknown values (§6.3). Single source of truth for how the
    /// stored `touchOffsetPosture` string maps to a posture, shared by the
    /// runtime regime lookup and the settings UI.
    init(settingValue raw: String?) {
        self = raw.flatMap(PostureClass.init(rawValue:)) ?? .defaultDeclared
    }
}

/// A learning regime: the discrete context in which a separate touch-offset
/// model lives. Stable, hashable key used for persistence (§7).
struct TouchRegime: Hashable, Codable {
    let orientation: RegimeOrientation
    let posture: PostureClass

    /// Stable string key for the persistence map (§7).
    var key: String {
        "\(orientation.rawValue).\(posture.rawValue)"
    }
}
