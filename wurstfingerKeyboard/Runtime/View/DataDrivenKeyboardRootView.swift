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

    /// Explicit theme for showcase/screenshot rendering. When set, the
    /// stored selection is bypassed entirely — screenshots can never be
    /// recolored by leftover simulator state.
    var themeOverride: KeyboardThemeDefinition?

    @AppStorage(SettingsKey.selectedThemeLight.rawValue, store: SharedDefaults.store)
    private var selectedThemeLight = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.selectedThemeDark.rawValue, store: SharedDefaults.store)
    private var selectedThemeDark = BuiltInThemes.classic.id

    @Environment(\.colorScheme) private var colorScheme

    /// Resolved once here for the whole keyboard; key views read it from the
    /// environment. Fallback cascade: assigned slot → other slot → Classic.
    private var resolvedTheme: ResolvedTheme {
        if let themeOverride {
            return themeOverride.resolved()
        }
        let (primaryId, secondaryId) = colorScheme == .dark
            ? (selectedThemeDark, selectedThemeLight)
            : (selectedThemeLight, selectedThemeDark)
        let definition = ThemeStore.theme(id: primaryId)
            ?? ThemeStore.theme(id: secondaryId)
            ?? BuiltInThemes.classic
        return definition.resolved()
    }

    var body: some View {
        let currentWidth = overrideWidth ?? viewModel.viewWidth
        // Single geometry source: the resolved metrics drive the keyboard
        // width here and the row/cell sizes in the grid, so they can never
        // desynchronize (the old split between the view-model width path and
        // @AppStorage-read row heights was review finding M8/H3).
        let metrics = viewModel.layoutMetrics(forContainerWidth: currentWidth)
        let availableSpace = currentWidth - metrics.keyboardWidth
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        let theme = resolvedTheme
        ZStack {
            keyboardBackground(theme)
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
        .environment(\.keyboardTheme, theme)
    }

    // MARK: - Background

    /// Minimum board opacity that still receives touches. A keyboard extension
    /// only delivers touches over rendered pixels, and UIKit hit-testing
    /// ignores anything with `alpha <= 0.01`, so a glass theme's board can't be
    /// fully transparent or the inter-key gaps go dead (#198). This is just
    /// above that threshold: enough to stay tappable, faint enough that the
    /// `UIInputView(.keyboard)` backdrop shows through essentially unchanged.
    private static let glassBoardOpacity = 0.02

    /// The board behind the keys.
    ///
    /// Glass themes paint an almost-invisible neutral fill over the
    /// `UIInputView(.keyboard)` backdrop: the backdrop supplies the system
    /// keyboard look, while this thin fill keeps the gaps tappable (see
    /// `glassBoardOpacity`). Color themes paint their board as a plain `Color`
    /// — matching the pre-engine board exactly, since `Color` and
    /// `Rectangle().fill` have different ideal sizes and the difference would
    /// shift the whole keyboard in the height-free showcase layout.
    @ViewBuilder
    private func keyboardBackground(_ theme: ResolvedTheme) -> some View {
        if theme.usesGlassMaterial {
            Color.gray.opacity(Self.glassBoardOpacity)
        } else {
            switch theme.boardBackground {
            case let .color(color):
                color
            case .material:
                Rectangle().fill(.bar)
            }
        }
    }
}
