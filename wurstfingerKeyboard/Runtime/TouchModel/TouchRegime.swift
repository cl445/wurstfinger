//
//  TouchRegime.swift
//  Wurstfinger
//
//  Discrete learning regime for the touch-offset correction (spec §3.1).
//  A separate offset model is maintained per regime. Both axes are known at
//  runtime *without* detection: orientation comes from the controller, the
//  posture class is *derived* from the user's keyboard size/position settings
//  (iOS gives third-party keyboards no posture state — see §11.1).
//

import Foundation

/// Screen-orientation dimension of a regime.
enum RegimeOrientation: String, Codable, CaseIterable {
    case portrait
    case landscape
}

/// Biomechanical posture class, *derived* from settings (§3.1).
/// `Floating` (iPad) is intentionally **not** a v1 class — it falls through
/// `derivePosture` into the nearest class (§3.1).
enum PostureClass: String, Codable, CaseIterable {
    /// Two-thumb typing — wide/centered keyboard. Uses a left/right split
    /// reach surface (§3.2).
    case twoThumb
    /// One-handed, keyboard narrow and shifted left.
    case oneThumbLeft
    /// One-handed, keyboard narrow and shifted right.
    case oneThumbRight

    /// Whether this posture uses the left/right split reach surface (§3.2).
    var usesSplitSurface: Bool {
        self == .twoThumb
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

/// Thresholds for `derivePosture`. Calibrated on device (§10).
struct PostureThresholds: Equatable {
    /// Below this keyboard scale the keyboard counts as "narrow"
    /// (one-thumb candidate).
    let narrowScale: Double
    /// Horizontal-position deviation from center (0.5) that counts as "offset".
    let offsetMargin: Double
    /// Hysteresis band that resists switching regime near a boundary,
    /// preventing data-splitting flicker (§3.1, §10).
    let hysteresis: Double

    static let `default` = PostureThresholds(
        narrowScale: 0.55,
        offsetMargin: 0.18,
        hysteresis: 0.05
    )
}

enum PostureResolver {
    /// Maps the known settings `(scale, position)` to a posture class.
    ///
    /// Partition (§3.1):
    /// ```
    /// narrow = scale < narrowScale
    /// left   = position < 0.5 - offsetMargin ;  right = position > 0.5 + offsetMargin
    /// → oneThumbLeft   if narrow && left
    ///   oneThumbRight  if narrow && right
    ///   twoThumb       otherwise   (incl. "narrow & centered" — Default)
    /// ```
    ///
    /// Hysteresis (when `previous` is given): each boundary is biased to *resist
    /// leaving* the current class, so a setting hovering near a threshold does
    /// not flap between regimes.
    ///
    /// - Parameters:
    ///   - scale: `keyboardScale` (≈ 0.25…1.0).
    ///   - position: `keyboardHorizontalPosition` (0…1, 0.5 = centered).
    ///   - previous: the currently active posture (for hysteresis); `nil` = no
    ///     hysteresis (nominal classification).
    static func derivePosture(
        scale: Double,
        position: Double,
        thresholds: PostureThresholds = .default,
        previous: PostureClass? = nil
    ) -> PostureClass {
        let h = previous == nil ? 0 : thresholds.hysteresis
        let prevIsOneThumb = previous == .oneThumbLeft || previous == .oneThumbRight

        // Narrow boundary: if currently one-thumb, stay narrow longer (+h);
        // if currently two-thumb, require clearer narrowness to switch (−h).
        let narrowBoundary = thresholds.narrowScale + (prevIsOneThumb ? h : -h)
        let narrow = scale < narrowBoundary

        // Offset boundaries: keep the current side longer (−h margin = wider
        // region); make entering a side harder (+h margin = tighter region).
        let leftMargin = thresholds.offsetMargin + (previous == .oneThumbLeft ? -h : h)
        let rightMargin = thresholds.offsetMargin + (previous == .oneThumbRight ? -h : h)
        let left = position < 0.5 - leftMargin
        let right = position > 0.5 + rightMargin

        if narrow && left { return .oneThumbLeft }
        if narrow && right { return .oneThumbRight }
        return .twoThumb
    }
}
