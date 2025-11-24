//
//  KeyboardButton.swift
//  Wurstfinger
//
//  Generic keyboard button with gesture recognition for swipes, taps, and circular gestures
//

import SwiftUI

/// Main keyboard button component with comprehensive gesture recognition
struct KeyboardButton<Label: View, Overlay: View>: View {
    let height: CGFloat
    let aspectRatio: CGFloat
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
            aspectRatio: aspectRatio,
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
        .if(config.accessibilityIdentifier != nil) { view in
            view.accessibilityIdentifier(config.accessibilityIdentifier!)
        }
        .accessibilityAddTraits(.isButton)
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
                        tolerance: 0,
                        aspectRatio: aspectRatio
                    )
                    let finalDirection = KeyboardDirection.direction(
                        for: value.translation,
                        tolerance: KeyboardConstants.Gesture.minSwipeLength,
                        aspectRatio: aspectRatio
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
