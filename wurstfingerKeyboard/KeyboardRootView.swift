//
//  KeyboardRootView.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import CoreGraphics
import SwiftUI

/// Main keyboard view containing the MessagEase 3x3 grid layout
struct KeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    var scaleAnchor: UnitPoint = .bottom
    var frameAlignment: Alignment = .bottom
    var overrideWidth: CGFloat? = nil

    /// Registry for tracking key positions (for cross-key gesture resolution)
    @StateObject private var keyPositionRegistry = KeyPositionRegistry()

    var body: some View {
        // At aspectRatio 1.5 (default), use original height of 54pt
        // Lower ratio = taller keys, higher ratio = shorter keys
        let keyHeight = KeyboardConstants.Calculations.keyHeight(aspectRatio: viewModel.keyAspectRatio)

        // Calculate horizontal position offset
        let screenBounds = UIScreen.main.bounds
        let screenShortestSide = min(screenBounds.width, screenBounds.height)
        let currentWidth = overrideWidth ?? screenBounds.width
        
        // Constrain the base width to the device's shortest side (portrait width)
        // This prevents the keyboard from stretching in landscape
        let baseWidth = min(currentWidth, screenShortestSide)
        
        let availableSpace = currentWidth - (baseWidth * viewModel.keyboardScale)
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        ZStack {
            // Background layer that always fills the entire space
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: KeyboardConstants.Layout.gridVerticalSpacing) {
                // Rows 0-2: Standard letter/number rows
                ForEach(0..<3, id: \.self) { rowIndex in
                    HStack(spacing: KeyboardConstants.Layout.gridHorizontalSpacing) {
                        if viewModel.utilityColumnLeading {
                            utilityButton(forRow: rowIndex, keyHeight: keyHeight)
                        }

                        keyCells(forRow: rowIndex, keyHeight: keyHeight)

                        if !viewModel.utilityColumnLeading {
                            utilityButton(forRow: rowIndex, keyHeight: keyHeight)
                        }
                    }
                }

                // Row 3: Space bar row
                HStack(spacing: KeyboardConstants.Layout.gridHorizontalSpacing) {
                    if viewModel.utilityColumnLeading {
                        utilityButton(forRow: 3, keyHeight: keyHeight)
                    }

                    // For numbers layer: show "0" key cell + space spans 2 columns
                    // For letters layer: space spans 3 columns
                    if viewModel.activeLayer == .numbers {
                        keyCells(forRow: 3, keyHeight: keyHeight)
                    }

                    // Calculate space bar width based on column span
                    let keyWidth = keyHeight * viewModel.keyAspectRatio
                    let spaceColumnSpan = viewModel.activeLayer == .numbers ? 2 : 3
                    let spaceWidth = (keyWidth * CGFloat(spaceColumnSpan)) +
                                     (KeyboardConstants.Layout.gridHorizontalSpacing * CGFloat(spaceColumnSpan - 1))

                    SpaceKeyButton(viewModel: viewModel, keyHeight: keyHeight)
                        .frame(width: spaceWidth)

                    if !viewModel.utilityColumnLeading {
                        utilityButton(forRow: 3, keyHeight: keyHeight)
                    }
                }
            }
            .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
            .padding(.top, KeyboardConstants.Layout.verticalPaddingTop)
            .padding(.bottom, KeyboardConstants.Layout.verticalPaddingBottom)
            .frame(width: baseWidth, alignment: frameAlignment)
            .scaleEffect(viewModel.keyboardScale, anchor: scaleAnchor)
            .offset(x: horizontalOffset)
        }
        .onPreferenceChange(KeyPositionPreferenceKey.self) { positions in
            for (keyIndex, frame) in positions {
                keyPositionRegistry.register(key: keyIndex, frame: frame)
            }
        }
    }

    private func scaledMainLabelSize(for keyHeight: CGFloat) -> CGFloat {
        // Scale proportionally with key height
        let scaledSize = KeyboardConstants.FontSizes.mainLabelBaseSize * (keyHeight / KeyboardConstants.FontSizes.mainLabelReferenceHeight)
        return min(max(scaledSize, KeyboardConstants.FontSizes.mainLabelMinSize), KeyboardConstants.FontSizes.mainLabelMaxSize)
    }

    /// Returns the utility button for a given row (0=globe, 1=symbols, 2=delete, 3=return)
    @ViewBuilder
    private func utilityButton(forRow row: Int, keyHeight: CGFloat) -> some View {
        switch row {
        case 0: // Globe button
            KeyboardButton(
                height: keyHeight,
                aspectRatio: viewModel.keyAspectRatio,
                label: Image(systemName: "globe"),
                overlay: EmptyView(),
                config: KeyboardButtonConfig(),
                callbacks: KeyboardButtonCallbacks(
                    onTap: viewModel.handleAdvanceToNextInputMode,
                    onCircular: { viewModel.handleUtilityCircularGesture(.globe, direction: $0) }
                )
            )
        case 1: // Symbols toggle button
            KeyboardButton(
                height: keyHeight,
                aspectRatio: viewModel.keyAspectRatio,
                label: Text(viewModel.symbolToggleLabel),
                overlay: EmptyView(),
                config: KeyboardButtonConfig(highlighted: viewModel.isSymbolsToggleActive, accessibilityIdentifier: "symbols"),
                callbacks: KeyboardButtonCallbacks(onTap: viewModel.toggleSymbols)
            )
        case 2: // Delete button
            DeleteKeyButton(viewModel: viewModel, keyHeight: keyHeight, aspectRatio: viewModel.keyAspectRatio)
        case 3: // Return button
            KeyboardButton(
                height: keyHeight,
                aspectRatio: viewModel.keyAspectRatio,
                label: Text("⏎"),
                overlay: EmptyView(),
                config: KeyboardButtonConfig(),
                callbacks: KeyboardButtonCallbacks(onTap: viewModel.handleReturn)
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func keyCells(forRow rowIndex: Int, keyHeight: CGFloat) -> some View {
        if rowIndex < viewModel.rows.count {
            ForEach(Array(viewModel.rows[rowIndex].enumerated()), id: \.element.id) { columnIndex, key in
                let keyIndex = KeyIndex(row: rowIndex, column: columnIndex)
                KeyboardButton(
                    height: keyHeight,
                    aspectRatio: viewModel.keyAspectRatio,
                    label: Text(viewModel.displayText(for: key)),
                    overlay: KeyHintOverlay(key: key, viewModel: viewModel, keyHeight: keyHeight),
                    config: KeyboardButtonConfig(fontSize: scaledMainLabelSize(for: keyHeight)),
                    callbacks: KeyboardButtonCallbacks(
                        onSwipe: { viewModel.handleKeySwipe(key, direction: $0) },
                        onSwipeReturn: { viewModel.handleKeySwipeReturn(key, direction: $0) },
                        onCircular: { viewModel.handleCircularGesture(for: key, direction: $0) },
                        onCrossKeyGesture: { result in
                            handleCrossKeyGesture(result, fromKey: key)
                        }
                    ),
                    keyIndex: keyIndex,
                    positionRegistry: keyPositionRegistry
                )
                .trackKeyPosition(keyIndex, in: .global)
            }
        } else {
            EmptyView()
        }
    }

    /// Handles a gesture that was redirected from another key
    private func handleCrossKeyGesture(_ result: CrossKeyGestureResult, fromKey: MessagEaseKey) {
        // Find the target key based on the resolved KeyIndex
        guard result.targetKey.row >= 0,
              result.targetKey.row < viewModel.rows.count,
              result.targetKey.column >= 0,
              result.targetKey.column < viewModel.rows[result.targetKey.row].count else {
            // Invalid target, fall back to original key
            GestureDebugLog.log("CROSS-KEY: Invalid target \(result.targetKey), using original")
            if result.isCircular, let dir = result.circularDirection {
                viewModel.handleCircularGesture(for: fromKey, direction: dir)
            } else if result.isReturn {
                viewModel.handleKeySwipeReturn(fromKey, direction: result.direction)
            } else {
                viewModel.handleKeySwipe(fromKey, direction: result.direction)
            }
            return
        }

        let targetKey = viewModel.rows[result.targetKey.row][result.targetKey.column]
        GestureDebugLog.log("CROSS-KEY: Redirecting to \(targetKey.center)")

        if result.isCircular, let dir = result.circularDirection {
            viewModel.handleCircularGesture(for: targetKey, direction: dir)
        } else if result.isReturn {
            viewModel.handleKeySwipeReturn(targetKey, direction: result.direction)
        } else {
            viewModel.handleKeySwipe(targetKey, direction: result.direction)
        }
    }
}
