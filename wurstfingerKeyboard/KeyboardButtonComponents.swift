//
//  KeyboardButtonComponents.swift
//  Wurstfinger
//
//  Shared components for keyboard button rendering and configuration
//

import SwiftUI

/// Configuration options for keyboard buttons
struct KeyboardButtonConfig {
    let highlighted: Bool
    let fontSize: CGFloat
    let inactiveBackground: Color
    let activeBackground: Color
    let accessibilityLabel: Text?
    let accessibilityIdentifier: String?

    init(
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.utilityLabel,
        inactiveBackground: Color = Color(.secondarySystemBackground),
        activeBackground: Color = Color(.tertiarySystemFill),
        accessibilityLabel: Text? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.inactiveBackground = inactiveBackground
        self.activeBackground = activeBackground
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

/// Callback closures for keyboard button interactions
struct KeyboardButtonCallbacks {
    var onTap: (() -> Void)? = nil
    var onSwipe: ((KeyboardDirection) -> Void)? = nil
    var onSwipeReturn: ((KeyboardDirection) -> Void)? = nil
    var onCircular: ((KeyboardCircularDirection) -> Void)? = nil
}

/// Visual key cap component used as the base for all keyboard buttons
struct KeyCap<Content: View>: View {
    let height: CGFloat
    let aspectRatio: CGFloat?
    let background: Color
    let highlighted: Bool
    let fontSize: CGFloat
    private let content: Content

    @AppStorage("keyboardStyle", store: SharedDefaults.store)
    private var keyboardStyleRaw = KeyboardStyle.classic.rawValue

    private var keyboardStyle: KeyboardStyle {
        KeyboardStyle(rawValue: keyboardStyleRaw) ?? .classic
    }

    init(
        height: CGFloat,
        aspectRatio: CGFloat? = nil,
        background: Color = Color(.secondarySystemBackground),
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.defaultLabel,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.aspectRatio = aspectRatio
        self.background = background
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .frame(minWidth: KeyboardConstants.KeyDimensions.minWidth, maxWidth: aspectRatio.map { height * $0 } ?? .infinity, minHeight: height, maxHeight: height)
            .background(keyBackground)
    }

    @ViewBuilder
    private var keyBackground: some View {
        if keyboardStyle == .liquidGlass, #available(iOS 26.0, *) {
            // Liquid Glass style on iOS 26+
            RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                .fill(highlighted ? Color.accentColor.opacity(0.25) : .clear)
                .glassEffect(.regular, in: .rect(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        } else {
            // Classic style (or fallback for older iOS)
            RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                .fill(highlighted ? Color.accentColor.opacity(0.25) : background)
        }
    }
}
