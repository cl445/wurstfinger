//
//  DataDrivenKeyboardRootView.swift
//  Wurstfinger
//
//  Root SwiftUI view that renders the data-driven keyboard using
//  KeyboardGridView. Replaces KeyboardRootView as the hosting target
//  in KeyboardViewController.
//

import SwiftUI

/// Root view for the data-driven keyboard path. Reads mode and arrangement
/// from the ViewModel and delegates all gesture callbacks back to it.
struct DataDrivenKeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    /// Optional width override used by InteractiveKeyboardPreview.
    /// When nil, falls back to `viewModel.viewWidth`.
    var overrideWidth: CGFloat?

    @AppStorage(SettingsKey.keyboardStyle.rawValue, store: SharedDefaults.store)
    private var keyboardStyle: KeyboardStyle = .classic

    var body: some View {
        let screenBounds = DeviceLayoutUtils.screenBounds
        let screenShortestSide = min(screenBounds.width, screenBounds.height)
        let currentWidth = overrideWidth ?? viewModel.viewWidth
        let baseWidth = min(currentWidth, screenShortestSide)
        let scaledWidth = baseWidth * viewModel.keyboardScale
        let availableSpace = currentWidth - scaledWidth
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        ZStack {
            keyboardBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let mode = viewModel.activeModeFromDefinition,
               let arrangement = mode.arrangement(for: viewModel.currentContext) {
                KeyboardGridView(
                    arrangement: arrangement,
                    keys: mode.keys,
                    onGesture: { key, gesture, isReturn in
                        viewModel.handleGesture(gesture, keyId: key.id, isReturn: isReturn)
                    },
                    onTouchDown: {
                        viewModel.feedbackTap()
                    },
                    onSlide: { key, phase in
                        viewModel.handleSlide(key, phase: phase)
                    }
                )
                .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
                .padding(.top, KeyboardConstants.Layout.verticalPaddingTop)
                .padding(.bottom, KeyboardConstants.Layout.verticalPaddingBottom)
                .frame(width: scaledWidth)
                .offset(x: horizontalOffset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Background

    @ViewBuilder
    private var keyboardBackground: some View {
        switch keyboardStyle {
        case .classic:
            Color(.systemBackground)
        case .liquidGlass:
            // A keyboard extension's input view only delivers touches that land
            // on an actually-rendered surface; fully transparent regions pass
            // through (iOS 26 Liquid Glass keyboards are semi-transparent). With
            // a pure `Color.clear` root the inter-key gaps render nothing, so
            // taps there never reach SwiftUI — dead zones that appear only in the
            // real extension + Liquid Glass (Classic's opaque fill is immune).
            // A `contentShape` alone is not enough (it is a hit region, not a
            // rendered surface), so paint a near-invisible fill: the whole
            // keyboard becomes a real surface that delivers gap touches, while
            // the keys on top still win the hit-test. ~2% opacity over the
            // system glass backdrop is visually indistinguishable from clear.
            Color(.systemBackground).opacity(0.02)
        }
    }
}
