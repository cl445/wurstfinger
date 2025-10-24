//
//  KeyboardRootView.swift
//  wurstfingerKeyboard
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
                keyCells(forRow: 0)
                utilityButton(height: 54) {
                    Image(systemName: "globe")
                } action: {
                    viewModel.handleAdvanceToNextInputMode()
                }
            }

            GridRow {
                keyCells(forRow: 1)
                utilityButton(height: 54, highlighted: viewModel.activeLayer == .symbols) {
                    Text(viewModel.activeLayer == .symbols ? "ABC" : "123")
                } action: {
                    viewModel.toggleSymbols()
                }
            }

            GridRow {
                keyCells(forRow: 2)
                utilityButton(height: 54) {
                    Image(systemName: "delete.left")
                } action: {
                    viewModel.handleDelete()
                }
            }

            GridRow {
                spaceKey
                utilityButton(height: 54) {
                    Text("⏎")
                } action: {
                    viewModel.handleReturn()
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

    private var spaceKey: some View {
        Button {
            viewModel.handleSpace()
        } label: {
            KeyCap(
                height: 54,
                fontSize: 22
            ) {
                Text("Leerzeichen")
            }
        }
        .buttonStyle(.plain)
        .gridCellColumns(3)
    }

    private func utilityButton(
        height: CGFloat,
        fontSize: CGFloat = 22,
        highlighted: Bool = false,
        @ViewBuilder label: () -> some View,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            KeyCap(height: height, highlighted: highlighted, fontSize: fontSize) {
                label()
            }
        }
        .buttonStyle(.plain)
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
