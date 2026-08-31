//
//  ThemeContrast.swift
//  WurstfingerTests
//
//  WCAG luminance and contrast over resolved theme colors. Shared by the two
//  assertions that keep a palette change from making something invisible: the
//  gesture trail against its key, and the key against its board.
//
//  Ratios, not luminance deltas. The two diverge at the light end — a #F2F2F7
//  key with a 6 %-black trail is a delta of ~0.11 but a ratio of ~1.13:1, i.e.
//  invisible — and the ratio is the number the palette was tuned against.
//

import SwiftUI
import Testing
@testable import WurstfingerApp

enum ThemeContrast {
    /// The color's rendered components in one specific appearance. Explicit,
    /// because a semantic role resolves against the ambient trait collection
    /// otherwise and the test would silently measure only one of the two.
    static func components(of color: ThemeColor, in colorScheme: ColorScheme) -> HexColor.Components? {
        guard let resolved = color.resolvedColor(in: colorScheme),
              let hex = HexColor.string(from: resolved) else { return nil }
        return HexColor.parse(hex)
    }

    /// WCAG relative luminance of `components` composited over the opaque
    /// `background`.
    static func luminance(of components: HexColor.Components, over background: UInt32) -> Double {
        func channel(_ packed: UInt32, _ shift: UInt32) -> Double {
            Double((packed >> shift) & 0xFF) / 255
        }
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let weights: [(UInt32, Double)] = [(16, 0.2126), (8, 0.7152), (0, 0.0722)]
        return weights.reduce(0) { total, entry in
            let mixed = components.alpha * channel(components.rgb, entry.0)
                + (1 - components.alpha) * channel(background, entry.0)
            return total + entry.1 * linear(mixed)
        }
    }

    /// WCAG contrast ratio of `foreground` drawn over the opaque `background`.
    static func ratio(of foreground: HexColor.Components, over background: HexColor.Components) -> Double {
        let front = luminance(of: foreground, over: background.rgb)
        let back = luminance(of: background, over: background.rgb)
        return (max(front, back) + 0.05) / (min(front, back) + 0.05)
    }
}
