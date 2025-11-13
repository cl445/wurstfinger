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

    var body: some View {
        // At aspectRatio 1.5 (default), use original height of 54pt
        // Lower ratio = taller keys, higher ratio = shorter keys
        let keyHeight = KeyboardConstants.Calculations.keyHeight(aspectRatio: viewModel.keyAspectRatio)

        // Calculate horizontal position offset
        let screenWidth = overrideWidth ?? UIScreen.main.bounds.width
        let availableSpace = screenWidth * (1 - viewModel.keyboardScale)
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        ZStack {
            // Background layer that always fills the entire space
            Color(.systemBackground)
                .ignoresSafeArea()

            Grid(horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
             verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing) {
                GridRow {
                    if viewModel.utilityColumnLeading {
                        utilityButton(forRow: 0, keyHeight: keyHeight)
                    }

                    keyCells(forRow: 0, keyHeight: keyHeight)

                    if !viewModel.utilityColumnLeading {
                        utilityButton(forRow: 0, keyHeight: keyHeight)
                    }
                }

                GridRow {
                    if viewModel.utilityColumnLeading {
                        utilityButton(forRow: 1, keyHeight: keyHeight)
                    }

                    keyCells(forRow: 1, keyHeight: keyHeight)

                    if !viewModel.utilityColumnLeading {
                        utilityButton(forRow: 1, keyHeight: keyHeight)
                    }
                }

                GridRow {
                    if viewModel.utilityColumnLeading {
                        utilityButton(forRow: 2, keyHeight: keyHeight)
                    }

                    keyCells(forRow: 2, keyHeight: keyHeight)

                    if !viewModel.utilityColumnLeading {
                        utilityButton(forRow: 2, keyHeight: keyHeight)
                    }
                }

                GridRow {
                    if viewModel.utilityColumnLeading {
                        utilityButton(forRow: 3, keyHeight: keyHeight)
                    }

                    keyCells(forRow: 3, keyHeight: keyHeight)
                    SpaceKeyButton(viewModel: viewModel, keyHeight: keyHeight)
                        .gridCellColumns(viewModel.spaceColumnSpan)

                    if !viewModel.utilityColumnLeading {
                        utilityButton(forRow: 3, keyHeight: keyHeight)
                    }
                }
            }
            .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
            .padding(.vertical, KeyboardConstants.Layout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
            .scaleEffect(viewModel.keyboardScale, anchor: scaleAnchor)
            .offset(x: horizontalOffset)
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
                label: Text(viewModel.symbolToggleLabel),
                overlay: EmptyView(),
                config: KeyboardButtonConfig(highlighted: viewModel.isSymbolsToggleActive, accessibilityIdentifier: "symbols"),
                callbacks: KeyboardButtonCallbacks(onTap: viewModel.toggleSymbols)
            )
        case 2: // Delete button
            DeleteKeyButton(viewModel: viewModel, keyHeight: keyHeight)
        case 3: // Return button
            KeyboardButton(
                height: keyHeight,
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
    private func keyCells(forRow index: Int, keyHeight: CGFloat) -> some View {
        if index < viewModel.rows.count {
            ForEach(viewModel.rows[index]) { key in
                KeyboardButton(
                    height: keyHeight,
                    label: Text(viewModel.displayText(for: key)),
                    overlay: KeyHintOverlay(key: key, viewModel: viewModel, keyHeight: keyHeight),
                    config: KeyboardButtonConfig(fontSize: scaledMainLabelSize(for: keyHeight)),
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
