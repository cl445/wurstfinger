//
//  KeyView.swift
//  Wurstfinger
//
//  Generic key view that renders any KeyConfig with style-based appearance.
//

import SwiftUI

/// Generic key view that renders any `KeyConfig`.
///
/// Visual appearance is driven by `key.style`. Hints derive directly from
/// `key.bindings`, so only the gestures actually defined on a key are shown.
///
/// PR 9 introduces this view as additive infrastructure. The legacy
/// `KeyboardButton` continues to drive the existing `KeyboardRootView` until
/// PR 12 wires the data-driven path through `KeyboardGridView`.
struct KeyView: View {
    let key: KeyConfig
    let onGesture: (KeyConfig, GestureType) -> Void

    var body: some View {
        ZStack {
            background
            label
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .contentShape(Rectangle())
        .onTapGesture {
            onGesture(key, .tap)
        }
    }

    // MARK: - Style

    /// Primary text shown on the key. Falls back to the binding label or the
    /// key id (so unconfigured keys are still visible during development).
    var primaryLabel: String {
        if let tap = key.bindings[.tap] {
            return tap.label
        }
        return key.id
    }

    var accessibilityLabel: String {
        if let tap = key.bindings[.tap], let custom = tap.accessibilityLabel {
            return custom
        }
        return primaryLabel
    }

    /// Font size derived from the visual style. Pure function so it can be
    /// unit tested without rendering the SwiftUI tree.
    static func fontSize(for style: KeyStyle) -> CGFloat {
        switch style {
        case .primary:
            KeyboardConstants.FontSizes.mainLabelBaseSize
        case .secondary:
            KeyboardConstants.FontSizes.hintBaseSize
        case .utility:
            KeyboardConstants.FontSizes.utilityLabel
        case .spacebar:
            KeyboardConstants.FontSizes.defaultLabel
        case .accent:
            KeyboardConstants.FontSizes.mainLabelBaseSize
        }
    }

    /// Whether the key should be rendered as an icon-only key (no text label).
    static func isIconOnly(style: KeyStyle) -> Bool {
        style == .utility
    }

    /// Background fill for the key. Highlighted styles get a slightly tinted
    /// background to distinguish them from primary keys.
    static func backgroundColor(for style: KeyStyle) -> Color {
        switch style {
        case .primary, .accent:
            Color(.systemGray5)
        case .secondary:
            Color(.systemGray6)
        case .utility, .spacebar:
            Color(.systemGray4)
        }
    }

    // MARK: - View Construction

    private var background: some View {
        RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
            .fill(Self.backgroundColor(for: key.style))
    }

    @ViewBuilder
    private var label: some View {
        if Self.isIconOnly(style: key.style) {
            // Utility keys are rendered as icons. The exact icon resolution
            // is handled by call sites in PR 12; for now show the binding
            // label as a placeholder so previews remain meaningful.
            Text(primaryLabel)
                .font(.system(size: Self.fontSize(for: key.style), weight: .regular))
                .foregroundColor(.primary)
        } else {
            Text(primaryLabel)
                .font(.system(size: Self.fontSize(for: key.style), weight: .regular))
                .foregroundColor(.primary)
        }
    }
}
