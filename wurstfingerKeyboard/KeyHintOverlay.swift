//
//  KeyHintOverlay.swift
//  Wurstfinger
//
//  Overlay that displays swipe hints on keyboard keys
//

import SwiftUI

/// Displays directional swipe hints as overlays on keyboard keys
struct KeyHintOverlay: View {
    let key: MessagEaseKey
    let activeLayer: KeyboardLayer
    let isCapsLockActive: Bool
    let locale: Locale
    let keyHeight: CGFloat
    let labelVisibility: LabelVisibilitySettings

    private let directions: [KeyboardDirection] = KeyboardDirection.allCases.filter { $0 != .center }

    // Calculate dynamic font size based on available space
    private var hintFontSize: CGFloat {
        // Scale proportionally with key height, but apply min/max bounds
        let scaledSize = KeyboardConstants.FontSizes.hintBaseSize * (keyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        return min(max(scaledSize, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
    }

    private var hintEmphasisSize: CGFloat {
        hintFontSize * KeyboardConstants.FontSizes.hintEmphasisMultiplier
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Scale padding proportionally with font size
            let fontRatio = hintFontSize / KeyboardConstants.FontSizes.hintReferenceFontSize
            let scaledHorizontalPadding = KeyboardConstants.FontSizes.hintBaseHorizontalPadding * fontRatio
            let scaledVerticalPadding = KeyboardConstants.FontSizes.hintBaseVerticalPadding * fontRatio

            ForEach(directions, id: \.self) { direction in
                if let label = key.primaryLabel(for: direction, isCapsLock: isCapsLockActive),
                   let output = key.output(for: direction) {
                    let category = output.labelCategory
                    // Hide down icon on r-key when not in caps mode
                    if shouldShowLabel(for: direction), labelVisibility.isVisible(category) {
                        let displayLabel = transformLabel(label, category: category)
                        hintText(displayLabel, category: category)
                            .fixedSize()
                            .padding(direction.edgePadding(
                                horizontal: scaledHorizontalPadding,
                                vertical: scaledVerticalPadding
                            ))
                            .frame(width: size.width, height: size.height, alignment: direction.hintAlignment)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func shouldShowLabel(for direction: KeyboardDirection) -> Bool {
        // Only show down arrow on r-key when caps is active (upper layer)
        if key.center.lowercased() == "r" && direction == .down {
            return activeLayer == .upper
        }
        return true
    }

    private func transformLabel(_ label: String, category: LabelCategory) -> String {
        // Transform label based on active layer (for shift/caps)
        guard category == .letter else { return label }

        switch activeLayer {
        case .upper:
            return label.uppercased(with: locale)
        case .lower:
            return label.lowercased(with: locale)
        case .numbers, .symbols:
            return label
        }
    }

    private func hintText(_ text: String, category: LabelCategory) -> some View {
        // Three-tier color system similar to MessagEase:
        // 1. Center character (not shown here): primary color (highest priority)
        // 2. Letter hints: medium priority - between primary and secondary
        // 3. Symbol hints: lowest priority - more muted

        let color: Color
        let opacity: CGFloat
        let weight: Font.Weight

        if category == .letter {
            // Letters: medium priority, blend between primary and secondary
            color = Color.primary
            opacity = 0.65
            weight = .medium
        } else {
            // Symbols: lower priority, more muted
            color = Color.secondary
            opacity = 0.55
            weight = .regular
        }

        return Text(text)
            .font(.system(size: hintFontSize, weight: weight, design: .rounded))
            .foregroundStyle(color.opacity(opacity))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .allowsHitTesting(false)
    }
}

/// Overlay for globe key showing swipe hints (globe left, keyboard dismiss down)
struct GlobeKeyHintOverlay: View {
    let keyHeight: CGFloat

    // SF Symbols need smaller size than text hints to appear proportional
    private var symbolFontSize: CGFloat {
        let scaledSize = KeyboardConstants.FontSizes.hintBaseSize * (keyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        let baseSize = min(max(scaledSize, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
        return baseSize * 0.75 // SF Symbols are visually larger than text
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalPadding: CGFloat = 4
            let verticalPadding: CGFloat = 3

            // Globe icon at left (swipe left for next keyboard)
            Image(systemName: "globe")
                .font(.system(size: symbolFontSize, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.5))
                .padding(.leading, horizontalPadding)
                .frame(width: size.width, height: size.height, alignment: .leading)

            // Keyboard dismiss icon at bottom (swipe down to dismiss)
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: symbolFontSize, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.5))
                .padding(.bottom, verticalPadding)
                .frame(width: size.width, height: size.height, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }
}

/// Displays text editing swipe hints on the symbols toggle key (123/ABC)
/// - Up: Copy
/// - Up-Right: Cut
/// - Down: Paste
struct SymbolsKeyHintOverlay: View {
    let keyHeight: CGFloat

    private var hintFontSize: CGFloat {
        let scaledSize = KeyboardConstants.FontSizes.hintBaseSize * (keyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        return min(max(scaledSize, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
    }

    private struct HintConfig {
        let direction: KeyboardDirection
        let iconName: String
    }

    private let hints: [HintConfig] = [
        HintConfig(direction: .up, iconName: "doc.on.doc"), // Copy
        HintConfig(direction: .upRight, iconName: "scissors"), // Cut
        HintConfig(direction: .down, iconName: "doc.on.clipboard"), // Paste
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fontRatio = hintFontSize / KeyboardConstants.FontSizes.hintReferenceFontSize
            let scaledHorizontalPadding = KeyboardConstants.FontSizes.hintBaseHorizontalPadding * fontRatio
            let scaledVerticalPadding = KeyboardConstants.FontSizes.hintBaseVerticalPadding * fontRatio

            ForEach(hints, id: \.direction) { hint in
                Image(systemName: hint.iconName)
                    .font(.system(size: hintFontSize * 0.6, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .padding(hint.direction.edgePadding(
                        horizontal: scaledHorizontalPadding,
                        vertical: scaledVerticalPadding
                    ))
                    .frame(width: size.width, height: size.height, alignment: hint.direction.hintAlignment)
            }
        }
        .allowsHitTesting(false)
    }
}
