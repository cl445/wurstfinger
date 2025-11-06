//
//  KeyboardRootView.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import CoreGraphics
import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    var scaleAnchor: UnitPoint = .bottom
    var frameAlignment: Alignment = .bottom
    var overrideWidth: CGFloat? = nil

    var body: some View {
        // At aspectRatio 1.5 (default), use original height of 54pt
        // Lower ratio = taller keys, higher ratio = shorter keys
        let keyHeight = KeyboardConstants.KeyDimensions.height * (1.5 / viewModel.keyAspectRatio)

        // Calculate horizontal position offset
        let screenWidth = overrideWidth ?? UIScreen.main.bounds.width
        let availableSpace = screenWidth * (1 - viewModel.keyboardScale)
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        Grid(horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
             verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing) {
                GridRow {
                if viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Image(systemName: "globe"),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(),
                        callbacks: KeyboardButtonCallbacks(
                            onTap: viewModel.handleAdvanceToNextInputMode,
                            onCircular: { viewModel.handleUtilityCircularGesture(.globe, direction: $0) }
                        )
                    )
                }

                keyCells(forRow: 0, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Image(systemName: "globe"),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(),
                        callbacks: KeyboardButtonCallbacks(
                            onTap: viewModel.handleAdvanceToNextInputMode,
                            onCircular: { viewModel.handleUtilityCircularGesture(.globe, direction: $0) }
                        )
                    )
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Text(viewModel.symbolToggleLabel),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(highlighted: viewModel.isSymbolsToggleActive),
                        callbacks: KeyboardButtonCallbacks(onTap: viewModel.toggleSymbols)
                    )
                }

                keyCells(forRow: 1, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Text(viewModel.symbolToggleLabel),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(highlighted: viewModel.isSymbolsToggleActive),
                        callbacks: KeyboardButtonCallbacks(onTap: viewModel.toggleSymbols)
                    )
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    DeleteKeyButton(viewModel: viewModel, keyHeight: keyHeight)
                }

                keyCells(forRow: 2, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    DeleteKeyButton(viewModel: viewModel, keyHeight: keyHeight)
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Text("⏎"),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(),
                        callbacks: KeyboardButtonCallbacks(onTap: viewModel.handleReturn)
                    )
                }

                keyCells(forRow: 3, keyHeight: keyHeight)
                SpaceKeyButton(viewModel: viewModel, keyHeight: keyHeight)
                    .gridCellColumns(viewModel.spaceColumnSpan)

                if !viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        label: Text("⏎"),
                        overlay: EmptyView(),
                        config: KeyboardButtonConfig(),
                        callbacks: KeyboardButtonCallbacks(onTap: viewModel.handleReturn)
                    )
                }
            }
        }
        .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
        .padding(.vertical, KeyboardConstants.Layout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .background(Color(.systemBackground))
        .scaleEffect(viewModel.keyboardScale, anchor: scaleAnchor)
        .offset(x: horizontalOffset)
    }

    @ViewBuilder
    private func keyCells(forRow index: Int, keyHeight: CGFloat) -> some View {
        if index < viewModel.rows.count {
            ForEach(viewModel.rows[index]) { key in
                KeyboardButton(
                    height: keyHeight,
                    label: Text(viewModel.displayText(for: key)),
                    overlay: KeyHintOverlay(key: key, viewModel: viewModel),
                    config: KeyboardButtonConfig(fontSize: KeyboardConstants.FontSizes.keyLabel),
                    callbacks: KeyboardButtonCallbacks(
                        onSwipe: { viewModel.handleKeySwipe(key, direction: $0) },
                        onSwipeReturn: { viewModel.handleKeySwipeReturn(key, direction: $0) },
                        onCircular: { viewModel.handleCircularGesture(for: key, direction: $0) }
                    )
                )
            }
        } else {
            EmptyView()
        }
    }
}

private struct KeyCap<Content: View>: View {
    let height: CGFloat
    let background: Color
    let highlighted: Bool
    let fontSize: CGFloat
    private let content: Content

    init(
        height: CGFloat,
        background: Color = Color(.secondarySystemBackground),
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.defaultLabel,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.background = background
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .frame(minWidth: KeyboardConstants.KeyDimensions.minWidth, maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                    .fill(highlighted ? Color.accentColor.opacity(0.25) : background)
            )
    }
}

private struct KeyboardButtonConfig {
    let highlighted: Bool
    let fontSize: CGFloat
    let inactiveBackground: Color
    let activeBackground: Color
    let accessibilityLabel: Text?

    init(
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.utilityLabel,
        inactiveBackground: Color = Color(.secondarySystemBackground),
        activeBackground: Color = Color(.tertiarySystemFill),
        accessibilityLabel: Text? = nil
    ) {
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.inactiveBackground = inactiveBackground
        self.activeBackground = activeBackground
        self.accessibilityLabel = accessibilityLabel
    }
}

private struct KeyboardButtonCallbacks {
    var onTap: (() -> Void)? = nil
    var onSwipe: ((KeyboardDirection) -> Void)? = nil
    var onSwipeReturn: ((KeyboardDirection) -> Void)? = nil
    var onCircular: ((KeyboardCircularDirection) -> Void)? = nil
}

private struct KeyboardButton<Label: View, Overlay: View>: View {
    let height: CGFloat
    let label: Label
    let overlay: Overlay
    let config: KeyboardButtonConfig
    let callbacks: KeyboardButtonCallbacks

    @State private var isActive = false
    @State private var positions: [CGPoint] = []
    @State private var maxOffset: CGPoint = .zero

    var body: some View {
        KeyCap(
            height: height,
            background: isActive ? config.activeBackground : config.inactiveBackground,
            highlighted: config.highlighted,
            fontSize: config.fontSize
        ) {
            label
        }
        .overlay(overlay)
        .if(config.accessibilityLabel != nil) { view in
            view.accessibilityLabel(config.accessibilityLabel!)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if positions.isEmpty {
                        positions = [CGPoint.zero]
                        maxOffset = .zero
                    }

                    let point = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(point)

                    if positions.count > KeyboardConstants.Gesture.positionBufferSize {
                        positions.removeFirst(positions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    if point.magnitude() > maxOffset.magnitude() {
                        maxOffset = point
                    }

                    isActive = true
                }
                .onEnded { value in
                    defer { resetGestureState() }

                    let finalPoint = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(finalPoint)

                    if positions.count > KeyboardConstants.Gesture.positionBufferSize {
                        positions.removeFirst(positions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    let maxDistance = maxOffset.magnitude()
                    let finalDistance = finalPoint.magnitude()

                    // Check for circular gesture first
                    if let onCircular = callbacks.onCircular,
                       maxDistance >= KeyboardConstants.Gesture.minSwipeLength,
                       let circle = KeyboardGestureRecognizer.circularDirection(
                           positions: positions,
                           circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
                           minSwipeLength: KeyboardConstants.Gesture.minSwipeLength
                       ) {
                        onCircular(circle)
                        return
                    }

                    // Swipe gestures
                    let finalOffsetThreshold = KeyboardConstants.Gesture.minSwipeLength * KeyboardConstants.Gesture.finalOffsetMultiplier
                    let maxDirection = KeyboardDirection.direction(
                        for: CGSize(width: maxOffset.x, height: maxOffset.y),
                        tolerance: 0
                    )
                    let finalDirection = KeyboardDirection.direction(
                        for: value.translation,
                        tolerance: KeyboardConstants.Gesture.minSwipeLength
                    )

                    let finalOffsetSmallEnough = finalDistance <= finalOffsetThreshold || finalDirection != maxDirection

                    if maxDistance >= KeyboardConstants.Gesture.minSwipeLength, finalOffsetSmallEnough {
                        // Return swipe
                        if maxDirection != .center {
                            if let onSwipeReturn = callbacks.onSwipeReturn {
                                onSwipeReturn(maxDirection)
                            } else if let onSwipe = callbacks.onSwipe {
                                onSwipe(finalDirection)
                            } else if finalDirection == .center {
                                callbacks.onTap?()
                            }
                        } else {
                            handleDirectionalInput(direction: finalDirection)
                        }
                    } else {
                        handleDirectionalInput(direction: finalDirection)
                    }
                }
        )
    }

    private func handleDirectionalInput(direction: KeyboardDirection) {
        if let onSwipe = callbacks.onSwipe {
            onSwipe(direction)
        } else if direction == .center {
            callbacks.onTap?()
        } else if let onSwipeReturn = callbacks.onSwipeReturn {
            onSwipeReturn(direction)
        } else {
            callbacks.onTap?()
        }
    }

    private func resetGestureState() {
        positions.removeAll(keepingCapacity: false)
        maxOffset = .zero
        isActive = false
    }
}

private struct SpaceKeyButton: View {
    let viewModel: KeyboardViewModel
    let keyHeight: CGFloat

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var isSelecting = false
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        KeyCap(
            height: keyHeight,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Color.clear
        }
        .accessibilityLabel(Text("Leerzeichen"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragStarted {
                        dragStarted = true
                        viewModel.beginSpaceDrag()
                    }

                    let deltaX = value.translation.width - lastTranslation.width

                    if !isSelecting, abs(value.translation.height) >= KeyboardConstants.SpaceGestures.selectionActivationThreshold {
                        isSelecting = true
                        hasDragged = true
                        viewModel.beginSpaceSelection()
                    }

                    viewModel.updateSpaceDrag(deltaX: deltaX)

                    lastTranslation = value.translation

                    if !hasDragged, !isSelecting, abs(value.translation.width) >= KeyboardConstants.SpaceGestures.dragActivationThreshold {
                        hasDragged = true
                    }

                    isActive = true
                }
                .onEnded { _ in
                    if dragStarted {
                        viewModel.endSpaceDrag()
                    }

                    if !hasDragged, !isSelecting {
                        viewModel.handleSpace()
                    }

                    resetGestureState()
                }
        )
    }

    private func resetGestureState() {
        isActive = false
        dragStarted = false
        hasDragged = false
        isSelecting = false
        lastTranslation = .zero
    }
}

private struct DeleteKeyButton: View {
    let viewModel: KeyboardViewModel
    let keyHeight: CGFloat

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var isSliding = false
    @State private var lastTranslation: CGSize = .zero
    @State private var totalTranslation: CGSize = .zero
    @State private var isRepeating = false
    @State private var repeatTimer: Timer?
    @State private var repeatTriggered = false

    var body: some View {
        KeyCap(
            height: keyHeight,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Image(systemName: "delete.left")
        }
        .accessibilityLabel(Text("Löschen"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isRepeating {
                        stopRepeat()
                    }

                    if !dragStarted {
                        dragStarted = true
                    }

                    totalTranslation = value.translation

                    if !isSliding,
                       abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.slideActivationThreshold,
                       abs(totalTranslation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance {
                        isSliding = true
                        hasDragged = true
                        viewModel.beginDeleteDrag()
                        lastTranslation = totalTranslation
                        return
                    }

                    if isSliding {
                        let deltaX = totalTranslation.width - lastTranslation.width
                        viewModel.updateDeleteDrag(deltaX: deltaX)
                        lastTranslation = totalTranslation
                    } else {
                        if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.wordSwipeThreshold {
                            hasDragged = true
                        } else if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.dragActivationThreshold {
                            hasDragged = true
                        }
                    }

                    lastTranslation = value.translation
                    isActive = true
                }
                .onEnded { _ in
                    stopRepeat()

                    if isSliding {
                        viewModel.endDeleteDrag()
                    } else {
                        let translation = totalTranslation
                        let isWordSwipe = translation.width <= -KeyboardConstants.DeleteGestures.wordSwipeThreshold &&
                            abs(translation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance

                        if isWordSwipe {
                            viewModel.handleDeleteWord()
                        } else if !repeatTriggered && !hasDragged {
                            viewModel.handleDelete()
                        }
                    }

                    resetGestureState()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: KeyboardConstants.DeleteGestures.repeatDelay)
                .onEnded { _ in
                    if !isSliding {
                        startRepeat()
                    }
                }
        )
        .onDisappear {
            stopRepeat()
        }
    }

    private func startRepeat() {
        guard !isRepeating else { return }
        isRepeating = true
        repeatTriggered = false
        viewModel.handleDelete()
        repeatTriggered = true
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyboardConstants.DeleteGestures.repeatInterval, repeats: true) { _ in
            repeatTriggered = true
            viewModel.handleDelete()
        }
    }

    private func stopRepeat() {
        if isRepeating {
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
        isRepeating = false
    }

    private func resetGestureState() {
        stopRepeat()
        isActive = false
        dragStarted = false
        hasDragged = false
        isSliding = false
        lastTranslation = .zero
        totalTranslation = .zero
        repeatTriggered = false
    }
}

private struct KeyHintOverlay: View {
    let key: MessagEaseKey
    @ObservedObject var viewModel: KeyboardViewModel

    private let directions: [KeyboardDirection] = KeyboardDirection.allCases.filter { $0 != .center }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ForEach(directions, id: \.self) { direction in
                if let label = key.primaryLabel(for: direction, isCapsLock: viewModel.isCapsLockActive) {
                    // Hide down icon on r-key when not in caps mode
                    if shouldShowLabel(for: direction) {
                        hintText(label, emphasis: false)
                            .position(position(for: direction, returning: false, in: size))
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

    private func hintText(_ text: String, emphasis: Bool) -> some View {
        Text(text)
            .font(.system(size: emphasis ? KeyboardConstants.FontSizes.hintEmphasis : KeyboardConstants.FontSizes.hintNormal,
                         weight: emphasis ? .semibold : .medium, design: .rounded))
            .foregroundStyle(emphasis ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.8))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .allowsHitTesting(false)
    }

    private func position(for direction: KeyboardDirection, returning: Bool, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        let margin: CGFloat = returning ? KeyboardConstants.Layout.hintMarginReturning : KeyboardConstants.Layout.hintMargin

        switch direction {
        case .up:
            return CGPoint(x: width / 2, y: margin)
        case .down:
            return CGPoint(x: width / 2, y: height - margin)
        case .left:
            return CGPoint(x: margin, y: height / 2)
        case .right:
            return CGPoint(x: width - margin, y: height / 2)
        case .upLeft:
            return CGPoint(x: margin, y: margin)
        case .upRight:
            return CGPoint(x: width - margin, y: margin)
        case .downLeft:
            return CGPoint(x: margin, y: height - margin)
        case .downRight:
            return CGPoint(x: width - margin, y: height - margin)
        case .center:
            return CGPoint(x: width / 2, y: height / 2)
        }
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
