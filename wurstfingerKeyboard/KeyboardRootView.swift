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
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                if viewModel.utilityColumnLeading {
                    utilityButton(
                        height: 54,
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
                        height: 54,
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
                    utilityButton(height: 54, highlighted: viewModel.isSymbolsToggleActive) {
                        Text(viewModel.symbolToggleLabel)
                    } action: {
                        viewModel.toggleSymbols()
                    }
                }

                keyCells(forRow: 1)

                if !viewModel.utilityColumnLeading {
                    utilityButton(height: 54, highlighted: viewModel.isSymbolsToggleActive) {
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
                    utilityButton(height: 54) {
                        Text("⏎")
                    } action: {
                        viewModel.handleReturn()
                    }
                }

                keyCells(forRow: 3)
                spaceKey(columnSpan: viewModel.spaceColumnSpan)

                if !viewModel.utilityColumnLeading {
                    utilityButton(height: 54) {
                        Text("⏎")
                    } action: {
                        viewModel.handleReturn()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        fontSize: CGFloat = 22,
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
        fontSize: CGFloat = 18,
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
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 12)
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

    private let dragActivationThreshold: CGFloat = 8
    private let selectionActivationThreshold: CGFloat = 24

    var body: some View {
        KeyCap(
            height: 54,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: 22
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
                    if !isSelecting, abs(value.translation.height) >= selectionActivationThreshold {
                        isSelecting = true
                        hasDragged = true
                        viewModel.beginSpaceSelection()
                    }

                    viewModel.updateSpaceDrag(deltaX: deltaX)

                    lastTranslation = value.translation

                    if !hasDragged, !isSelecting, abs(value.translation.width) >= dragActivationThreshold {
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

    private let dragActivationThreshold: CGFloat = 8
    private let slideActivationThreshold: CGFloat = 28
    private let wordSwipeThreshold: CGFloat = 40
    private let verticalTolerance: CGFloat = 28
    private let repeatInterval: TimeInterval = 0.08
    private let repeatDelay: TimeInterval = 0.35

    var body: some View {
        KeyCap(
            height: 54,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: 22
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
                       abs(totalTranslation.width) >= slideActivationThreshold,
                       abs(totalTranslation.height) <= verticalTolerance {
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
                        if abs(totalTranslation.width) >= wordSwipeThreshold {
                            hasDragged = true
                        } else if abs(totalTranslation.width) >= dragActivationThreshold {
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
                        let isWordSwipe = translation.width <= -wordSwipeThreshold &&
                            abs(translation.height) <= verticalTolerance

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
            LongPressGesture(minimumDuration: repeatDelay)
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
        repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { _ in
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

    private let minSwipeLength: CGFloat = 30
    private let circleCompletionTolerance: CGFloat = 16

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

                    if positions.count > 60 {
                        positions.removeFirst(positions.count - 60)
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

                    if positions.count > 60 {
                        positions.removeFirst(positions.count - 60)
                    }

                    let maxDistance = maxOffset.magnitude()

                    if let onCircularGesture,
                       maxDistance >= minSwipeLength,
                       let circle = KeyboardGestureRecognizer.circularDirection(
                           positions: positions,
                           circleCompletionTolerance: circleCompletionTolerance,
                           minSwipeLength: minSwipeLength
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

    private let minSwipeLength: CGFloat = 30
    private let finalOffsetMultiplier: CGFloat = 0.71
    private let circleCompletionTolerance: CGFloat = 16

    var body: some View {
        KeyCap(
            height: 54,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: 22
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

                    if positions.count > 60 {
                        positions.removeFirst(positions.count - 60)
                    }

                    if point.magnitude() > maxOffset.magnitude() {
                        maxOffset = point
                    }

                    isActive = true
                }
                .onEnded { value in
                    let finalPoint = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(finalPoint)

                    if positions.count > 60 {
                        positions.removeFirst(positions.count - 60)
                    }

                    let maxDistance = maxOffset.magnitude()
                    let finalDistance = finalPoint.magnitude()

                    let finalOffsetThreshold = minSwipeLength * finalOffsetMultiplier

                    let maxDirection = KeyboardDirection.direction(
                        for: CGSize(width: maxOffset.x, height: maxOffset.y),
                        tolerance: 0
                    )

                    let circle = KeyboardGestureRecognizer.circularDirection(
                        positions: positions,
                        circleCompletionTolerance: circleCompletionTolerance,
                        minSwipeLength: minSwipeLength
                    )

                    let finalDirection = KeyboardDirection.direction(
                        for: value.translation,
                        tolerance: minSwipeLength
                    )

                    if let circle, maxDistance >= minSwipeLength {
                        viewModel.handleCircularGesture(for: key, direction: circle)
                        resetGestureState()
                        return
                    }

                    let finalOffsetSmallEnough = finalDistance <= finalOffsetThreshold || finalDirection != maxDirection

                    if maxDistance >= minSwipeLength, finalOffsetSmallEnough {
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
            .font(.system(size: emphasis ? 11 : 10, weight: emphasis ? .semibold : .medium, design: .rounded))
            .foregroundStyle(emphasis ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.8))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .allowsHitTesting(false)
    }

    private func position(for direction: KeyboardDirection, returning: Bool, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        let margin: CGFloat = returning ? 22 : 10

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
