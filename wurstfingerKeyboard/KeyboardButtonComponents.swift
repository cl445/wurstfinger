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
            .background(
                RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                    .fill(highlighted ? Color.accentColor.opacity(0.25) : background)
            )
    }
}
