//
//  KeyView.swift
//  Wurstfinger
//
//  Generic key view that renders any KeyConfig with style-based appearance
//  and full gesture recognition.
//

import SwiftUI

/// Generic key view that renders any `KeyConfig`.
///
/// Visual appearance is driven by `key.style`. Hints derive directly from
/// `key.bindings`, so only the gestures actually defined on a key are shown.
/// Gesture recognition uses `KeyGestureRecognizer` for the same preprocessing
/// pipeline as the legacy `KeyboardButton`.
struct KeyView: View {
    let key: KeyConfig
    let onGesture: (KeyConfig, GestureType, Bool) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?
    var spanRatio: CGFloat = 1.0

    @State private var isActive = false

    var body: some View {
        keyContent
    }

    @ViewBuilder
    private var keyContent: some View {
        let base = ZStack {
            background
            label
            hintOverlay
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .contentShape(Rectangle().inset(by: -KeyboardTouchArea.padding))

        if usesSlideGesture {
            base.modifier(SlideGestureHandler(
                slideType: key.slideType,
                onSlide: { phase in onSlide?(key, phase) },
                onTouchDown: { onTouchDown?() },
                isActive: $isActive
            ))
        } else {
            base.modifier(KeyGestureRecognizer(
                onGestureRecognized: { classification in
                    onGesture(key, classification.gesture, classification.isReturn)
                },
                onTouchDown: { onTouchDown?() },
                aspectRatio: spanRatio,
                isActive: $isActive
            ))
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
    static func backgroundColor(for style: KeyStyle, active: Bool = false) -> Color {
        if active {
            return Color(.systemGray3)
        }
        switch style {
        case .primary, .accent:
            return Color(.systemGray5)
        case .secondary:
            return Color(.systemGray6)
        case .utility, .spacebar:
            return Color(.systemGray4)
        }
    }

    // MARK: - Gesture Selection

    /// Whether this key uses slide gesture handling instead of standard
    /// gesture classification.
    private var usesSlideGesture: Bool {
        key.slideType != .none && onSlide != nil
    }

    // MARK: - View Construction

    private var background: some View {
        RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
            .fill(Self.backgroundColor(for: key.style, active: isActive))
    }

    private var label: some View {
        Text(primaryLabel)
            .font(.system(size: Self.fontSize(for: key.style), weight: .regular))
            .foregroundColor(.primary)
    }

    // MARK: - Hint Overlay

    /// Mapping from swipe `GestureType` to the SwiftUI `Alignment` where
    /// the hint label should be placed.
    private static let hintAlignments: [GestureType: Alignment] = [
        .swipeUp: .top,
        .swipeDown: .bottom,
        .swipeLeft: .leading,
        .swipeRight: .trailing,
        .swipeUpLeft: .topLeading,
        .swipeUpRight: .topTrailing,
        .swipeDownLeft: .bottomLeading,
        .swipeDownRight: .bottomTrailing,
    ]

    private var hintOverlay: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ForEach(Array(key.bindings.keys), id: \.self) { gesture in
                if let binding = key.bindings[gesture],
                   let alignment = Self.hintAlignments[gesture] {
                    Text(binding.label)
                        .font(.system(
                            size: KeyboardConstants.FontSizes.hintBaseSize,
                            weight: .regular
                        ))
                        .foregroundColor(.secondary)
                        .fixedSize()
                        .padding(4)
                        .frame(
                            width: size.width,
                            height: size.height,
                            alignment: alignment
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
