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
        let currentWidth = overrideWidth ?? viewModel.viewWidth
        // Single geometry source: the resolved metrics drive the keyboard
        // width here and the row/cell sizes in the grid, so they can never
        // desynchronize (the old split between the view-model width path and
        // @AppStorage-read row heights was review finding M8/H3).
        let metrics = viewModel.layoutMetrics(forContainerWidth: currentWidth)
        let availableSpace = currentWidth - metrics.keyboardWidth
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        ZStack {
            keyboardBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let mode = viewModel.activeModeFromDefinition,
               let arrangement = mode.arrangement(for: viewModel.currentContext) {
                KeyboardGridView(
                    arrangement: arrangement,
                    keys: mode.keys,
                    onGesture: { key, classification in
                        viewModel.handleGesture(
                            classification.gesture,
                            keyId: key.id,
                            isReturn: classification.isReturn,
                            touchdown: classification.touchdown,
                            features: classification.features
                        )
                    },
                    onTouchDown: {
                        viewModel.feedbackTap()
                    },
                    onSlide: { key, phase in
                        viewModel.handleSlide(key, phase: phase)
                    },
                    onLongPress: { key in
                        viewModel.handleGesture(.longPress, keyId: key.id, isReturn: false)
                    },
                    languageLabel: viewModel.currentLanguageLabel,
                    showLanguageLabel: viewModel.hasMultipleLanguages,
                    metrics: metrics
                )
                .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
                .padding(.top, KeyboardConstants.Layout.verticalPaddingTop)
                .padding(.bottom, KeyboardConstants.Layout.verticalPaddingBottom)
                .frame(width: metrics.keyboardWidth)
                .offset(x: horizontalOffset)
            }
        }
        .frame(maxWidth: .infinity)
        // Pin the entire keyboard render tree to physical LTR. Grid slot
        // positions, the horizontalOffset math above, and the atan2 gesture
        // classification are all physical/absolute, so this cannot affect
        // layout — it only stops the directional hint alignments/paddings
        // (which use semantic leading/trailing) from mirroring under an RTL
        // system language, keeping hints aligned with the physical swipe
        // directions. A lone hint glyph is direction-agnostic, so RTL text
        // still renders correctly. (Finding #4.)
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: - Background

    @ViewBuilder
    private var keyboardBackground: some View {
        switch keyboardStyle {
        case .classic:
            Color(.systemBackground)
        case .liquidGlass:
            // A keyboard extension's input view only delivers touches that land
            // on a rendered surface; fully transparent regions pass through. A
            // `Color.clear` root would drop taps that fall in the gaps between
            // keys, so paint a near-invisible fill instead: the whole keyboard
            // becomes a real surface that receives those touches while the keys
            // on top still win the hit-test. ~2% over the glass backdrop reads
            // as clear.
            Color(.systemBackground).opacity(0.02)
        }
    }
}
