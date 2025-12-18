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
    @ObservedObject var viewModel: KeyboardViewModel
    let keyHeight: CGFloat

    private let directions: [KeyboardDirection] = KeyboardDirection.allCases.filter { $0 != .center }

    // Calculate dynamic font size based on available space
    private var hintFontSize: CGFloat {
        // Scale proportionally with key height, but apply min/max bounds
        let scaledSize = KeyboardConstants.FontSizes.hintBaseSize * (keyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        return min(max(scaledSize, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
    }

    private var hintEmphasisSize: CGFloat {
        return hintFontSize * KeyboardConstants.FontSizes.hintEmphasisMultiplier
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Scale padding proportionally with font size
            let scaledHorizontalPadding = KeyboardConstants.FontSizes.hintBaseHorizontalPadding * (hintFontSize / KeyboardConstants.FontSizes.hintReferenceFontSize)
            let scaledVerticalPadding = KeyboardConstants.FontSizes.hintBaseVerticalPadding * (hintFontSize / KeyboardConstants.FontSizes.hintReferenceFontSize)

            ForEach(directions, id: \.self) { direction in
                if let label = key.primaryLabel(for: direction, isCapsLock: viewModel.isCapsLockActive) {
                    // Hide down icon on r-key when not in caps mode
                    if shouldShowLabel(for: direction) {
                        let displayLabel = transformLabel(label, activeLayer: viewModel.activeLayer)
                        hintText(displayLabel, isLetter: isLetter(displayLabel))
                            .fixedSize()
                            .padding(edgePadding(for: direction,
                                                horizontal: scaledHorizontalPadding,
                                                vertical: scaledVerticalPadding))
                            .frame(width: size.width, height: size.height, alignment: alignment(for: direction))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func shouldShowLabel(for direction: KeyboardDirection) -> Bool {
        // Only show down arrow on r-key when caps is active (upper layer)
        if key.center.lowercased() == "r" && direction == .down {
            return viewModel.activeLayer == .upper
        }
        return true
    }

    private func transformLabel(_ label: String, activeLayer: KeyboardLayer) -> String {
        // Transform label based on active layer (for shift/caps)
        guard isLetter(label) else { return label }

        switch activeLayer {
        case .upper:
            return label.uppercased()
        case .lower:
            return label.lowercased()
        case .numbers, .symbols:
            return label
        }
    }

    private func isLetter(_ text: String) -> Bool {
        // Check if the text is a letter (any alphabet, including non-Latin scripts)
        guard let firstChar = text.first else { return false }
        return firstChar.isLetter
    }

    private func hintText(_ text: String, isLetter: Bool) -> some View {
        // Three-tier color system similar to MessagEase:
        // 1. Center character (not shown here): primary color (highest priority)
        // 2. Letter hints: medium priority - between primary and secondary
        // 3. Symbol hints: lowest priority - more muted

        let color: Color
        let opacity: CGFloat
        let weight: Font.Weight

        if isLetter {
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

    private func edgePadding(for direction: KeyboardDirection, horizontal: CGFloat, vertical: CGFloat) -> EdgeInsets {
        switch direction {
        case .up:
            return EdgeInsets(top: vertical, leading: 0, bottom: 0, trailing: 0)
        case .down:
            return EdgeInsets(top: 0, leading: 0, bottom: vertical, trailing: 0)
        case .left:
            return EdgeInsets(top: 0, leading: horizontal, bottom: 0, trailing: 0)
        case .right:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: horizontal)
        case .upLeft:
            return EdgeInsets(top: vertical, leading: horizontal, bottom: 0, trailing: 0)
        case .upRight:
            return EdgeInsets(top: vertical, leading: 0, bottom: 0, trailing: horizontal)
        case .downLeft:
            return EdgeInsets(top: 0, leading: horizontal, bottom: vertical, trailing: 0)
        case .downRight:
            return EdgeInsets(top: 0, leading: 0, bottom: vertical, trailing: horizontal)
        case .center:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
    }

    private func alignment(for direction: KeyboardDirection) -> Alignment {
        switch direction {
        case .up:
            return .top
        case .down:
            return .bottom
        case .left:
            return .leading
        case .right:
            return .trailing
        case .upLeft:
            return .topLeading
        case .upRight:
            return .topTrailing
        case .downLeft:
            return .bottomLeading
        case .downRight:
            return .bottomTrailing
        case .center:
            return .center
        }
    }
}

/// Overlay for globe key showing swipe hints (globe left, keyboard dismiss down)
struct GlobeKeyHintOverlay: View {
    let keyHeight: CGFloat

    // SF Symbols need smaller size than text hints to appear proportional
    private var symbolFontSize: CGFloat {
        let scaledSize = KeyboardConstants.FontSizes.hintBaseSize * (keyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        let baseSize = min(max(scaledSize, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
        return baseSize * 0.75  // SF Symbols are visually larger than text
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
