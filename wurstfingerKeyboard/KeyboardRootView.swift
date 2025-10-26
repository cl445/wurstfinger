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

    var body: some View {
        Grid(horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
             verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing) {
            GridRow {
                if viewModel.utilityColumnLeading {
                    utilityButton(
                        height: KeyboardConstants.KeyDimensions.height,
                        onCircularGesture: { direction in
                            viewModel.handleUtilityCircularGesture(.globe, direction: direction)
                        }
                    ) {
                        Image(systemName: "globe")
                    } action: {
                        viewModel.handleAdvanceToNextInputMode()
                    }
                }

                keyCells(forRow: 0)

                if !viewModel.utilityColumnLeading {
                    utilityButton(
                        height: KeyboardConstants.KeyDimensions.height,
                        onCircularGesture: { direction in
                            viewModel.handleUtilityCircularGesture(.globe, direction: direction)
                        }
                    ) {
                        Image(systemName: "globe")
                    } action: {
                        viewModel.handleAdvanceToNextInputMode()
                    }
                }
            }

            GridRow {
                if viewModel.utilityColumnLeading {
                    utilityButton(height: KeyboardConstants.KeyDimensions.height,
                                highlighted: viewModel.isSymbolsToggleActive) {
                        Text(viewModel.symbolToggleLabel)
                    } action: {
                        viewModel.toggleSymbols()
                    }
                }

                keyCells(forRow: 1)

                if !viewModel.utilityColumnLeading {
                    utilityButton(height: KeyboardConstants.KeyDimensions.height,
                                highlighted: viewModel.isSymbolsToggleActive) {
                        Text(viewModel.symbolToggleLabel)
                    } action: {
                        viewModel.toggleSymbols()
                    }
                }
            }

            GridRow {
                if viewModel.utilityColumnLeading {
                    DeleteKeyButton(viewModel: viewModel)
                }

                keyCells(forRow: 2)

                if !viewModel.utilityColumnLeading {
                    DeleteKeyButton(viewModel: viewModel)
                }
            }

            GridRow {
                if viewModel.utilityColumnLeading {
                    utilityButton(height: KeyboardConstants.KeyDimensions.height) {
                        Text("⏎")
                    } action: {
                        viewModel.handleReturn()
                    }
                }

                keyCells(forRow: 3)
                spaceKey(columnSpan: viewModel.spaceColumnSpan)

                if !viewModel.utilityColumnLeading {
                    utilityButton(height: KeyboardConstants.KeyDimensions.height) {
                        Text("⏎")
                    } action: {
                        viewModel.handleReturn()
                    }
                }
            }
        }
        .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
        .padding(.vertical, KeyboardConstants.Layout.verticalPadding)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func keyCells(forRow index: Int) -> some View {
        if index < viewModel.rows.count {
            ForEach(viewModel.rows[index]) { key in
                KeyButton(
                    key: key,
                    display: viewModel.displayText(for: key),
                    viewModel: viewModel
                )
            }
        } else {
            EmptyView()
        }
    }

    private func spaceKey(columnSpan: Int) -> some View {
        SpaceKeyButton(viewModel: viewModel)
            .gridCellColumns(columnSpan)
    }

    private func utilityButton(
        height: CGFloat,
        fontSize: CGFloat = KeyboardConstants.FontSizes.utilityLabel,
        highlighted: Bool = false,
        onCircularGesture: ((KeyboardCircularDirection) -> Void)? = nil,
        @ViewBuilder label: () -> some View,
        action: @escaping () -> Void
    ) -> some View {
        UtilityKeyButton(
            height: height,
            highlighted: highlighted,
            fontSize: fontSize,
            onTap: action,
            onCircularGesture: onCircularGesture,
            label: label
        )
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
            .frame(minWidth: KeyboardConstants.KeyDimensions.minWidth, maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                    .fill(highlighted ? Color.accentColor.opacity(0.25) : background)
            )
    }
}

private struct SpaceKeyButton: View {
    let viewModel: KeyboardViewModel

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var isSelecting = false
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        KeyCap(
            height: KeyboardConstants.KeyDimensions.height,
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
            height: KeyboardConstants.KeyDimensions.height,
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

private struct UtilityKeyButton<Content: View>: View {
    let height: CGFloat
    let highlighted: Bool
    let fontSize: CGFloat
    let onTap: () -> Void
    let onCircularGesture: ((KeyboardCircularDirection) -> Void)?
    private let content: Content

    @State private var isActive = false
    @State private var positions: [CGPoint] = []
    @State private var maxOffset: CGPoint = .zero

    init(
        height: CGFloat,
        highlighted: Bool,
        fontSize: CGFloat,
        onTap: @escaping () -> Void,
        onCircularGesture: ((KeyboardCircularDirection) -> Void)?,
        @ViewBuilder label: () -> Content
    ) {
        self.height = height
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.onTap = onTap
        self.onCircularGesture = onCircularGesture
        self.content = label()
    }

    var body: some View {
        KeyCap(
            height: height,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            highlighted: highlighted,
            fontSize: fontSize
        ) {
            content
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

                    if let onCircularGesture,
                       maxDistance >= KeyboardConstants.Gesture.minSwipeLength,
                       let circle = KeyboardGestureRecognizer.circularDirection(
                           positions: positions,
                           circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
                           minSwipeLength: KeyboardConstants.Gesture.minSwipeLength
                       ) {
                        onCircularGesture(circle)
                    } else {
                        onTap()
                    }
                }
        )
    }

    private func resetGestureState() {
        positions.removeAll(keepingCapacity: false)
        maxOffset = .zero
        isActive = false
    }
}

private struct KeyButton: View {
    let key: MessagEaseKey
    let display: String
    let viewModel: KeyboardViewModel

    @State private var isActive = false
    @State private var positions: [CGPoint] = []
    @State private var maxOffset: CGPoint = .zero

    var body: some View {
        KeyCap(
            height: KeyboardConstants.KeyDimensions.height,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Text(display)
        }
        .overlay(KeyHintOverlay(key: key))
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
                    let finalPoint = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(finalPoint)

                    if positions.count > KeyboardConstants.Gesture.positionBufferSize {
                        positions.removeFirst(positions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    let maxDistance = maxOffset.magnitude()
                    let finalDistance = finalPoint.magnitude()

                    let finalOffsetThreshold = KeyboardConstants.Gesture.minSwipeLength * KeyboardConstants.Gesture.finalOffsetMultiplier

                    let maxDirection = KeyboardDirection.direction(
                        for: CGSize(width: maxOffset.x, height: maxOffset.y),
                        tolerance: 0
                    )

                    let circle = KeyboardGestureRecognizer.circularDirection(
                        positions: positions,
                        circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
                        minSwipeLength: KeyboardConstants.Gesture.minSwipeLength
                    )

                    let finalDirection = KeyboardDirection.direction(
                        for: value.translation,
                        tolerance: KeyboardConstants.Gesture.minSwipeLength
                    )

                    if let circle, maxDistance >= KeyboardConstants.Gesture.minSwipeLength {
                        viewModel.handleCircularGesture(for: key, direction: circle)
                        resetGestureState()
                        return
                    }

                    let finalOffsetSmallEnough = finalDistance <= finalOffsetThreshold || finalDirection != maxDirection

                    if maxDistance >= KeyboardConstants.Gesture.minSwipeLength, finalOffsetSmallEnough {
                        if maxDirection != .center {
                            viewModel.handleKeySwipeReturn(key, direction: maxDirection)
                        } else {
                            viewModel.handleKeySwipe(key, direction: finalDirection)
                        }
                    } else {
                        viewModel.handleKeySwipe(key, direction: finalDirection)
                    }

                    resetGestureState()
                }
        )
    }

    private func resetGestureState() {
        positions.removeAll(keepingCapacity: false)
        maxOffset = .zero
        isActive = false
    }
}

private struct KeyHintOverlay: View {
    let key: MessagEaseKey

    private let directions: [KeyboardDirection] = KeyboardDirection.allCases.filter { $0 != .center }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ForEach(directions, id: \.self) { direction in
                if let label = key.primaryLabel(for: direction) {
                    hintText(label, emphasis: false)
                        .position(position(for: direction, returning: false, in: size))
                }
            }
        }
        .allowsHitTesting(false)
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
