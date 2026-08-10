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

    // Single read site for the per-key render settings: one observation per
    // setting for the whole keyboard rather than one per key view. The root
    // re-renders on changes and passes fresh values down. The unstored-value
    // defaults come from `KeyRenderSettings.stock`, so this site and the
    // snapshot type agree on what an untouched installation renders.
    @AppStorage(SettingsKey.hideLetters.rawValue, store: SharedDefaults.store)
    private var hideLetters = KeyRenderSettings.stock.hideLetters

    @AppStorage(SettingsKey.hideStandardSymbols.rawValue, store: SharedDefaults.store)
    private var hideStandardSymbols = KeyRenderSettings.stock.hideStandardSymbols

    @AppStorage(SettingsKey.hideExtraSymbols.rawValue, store: SharedDefaults.store)
    private var hideExtraSymbols = KeyRenderSettings.stock.hideExtraSymbols

    @AppStorage(SettingsKey.longPressNumbersEnabled.rawValue, store: SharedDefaults.store)
    private var longPressNumbersEnabled = KeyRenderSettings.stock.longPressNumbersEnabled

    // The theme selection is observed at the same single site, for the same
    // reason: the resolved theme is handed down through the environment
    // instead of being re-read by every key.
    @AppStorage(SettingsKey.selectedThemeLight.rawValue, store: SharedDefaults.store)
    private var selectedThemeLight = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.selectedThemeDark.rawValue, store: SharedDefaults.store)
    private var selectedThemeDark = BuiltInThemes.classic.id

    /// The keyboard follows the system color scheme. A keyboard extension can
    /// also be asked for a specific appearance via
    /// `textDocumentProxy.keyboardAppearance`; wiring the slot selection to
    /// that instead of `colorScheme` is deferred to M2, when the gallery lets
    /// the light/dark slots actually diverge (today both hold one selection,
    /// so the distinction is a no-op).
    @Environment(\.colorScheme) private var colorScheme

    private var renderSettings: KeyRenderSettings {
        KeyRenderSettings(
            hideLetters: hideLetters,
            hideStandardSymbols: hideStandardSymbols,
            hideExtraSymbols: hideExtraSymbols,
            longPressNumbersEnabled: longPressNumbersEnabled
        )
    }

    /// Resolved once here for the whole keyboard; key views read it from the
    /// environment. Slot selection uses the shared `ThemeStore` cascade so the
    /// rendered path is the one the tests exercise.
    private var resolvedTheme: ResolvedTheme {
        if let themeOverride {
            return themeOverride.resolved()
        }
        return ThemeStore.theme(
            lightId: selectedThemeLight,
            darkId: selectedThemeDark,
            for: colorScheme
        ).resolved()
    }

    var body: some View {
        let currentWidth = overrideWidth ?? viewModel.viewWidth
        // Single geometry source: the resolved metrics drive the keyboard
        // width here and the row/cell sizes in the grid, so they can never
        // desynchronize — which a second, `@AppStorage`-read source of row
        // heights would allow.
        let metrics = viewModel.layoutMetrics(forContainerWidth: currentWidth)
        let availableSpace = currentWidth - metrics.keyboardWidth
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        let theme = resolvedTheme
        ZStack {
            // The board is never fully transparent, whatever the theme asks
            // for: a keyboard extension only delivers touches over rendered
            // pixels and UIKit hit-testing ignores `alpha <= 0.01`, so a clear
            // board would drop every tap that lands in an inter-key gap (#198).
            // The resolver floors a color board to
            // `KeyboardThemeDefinition.minimumBoardOpacity` and paints a glass
            // board as `glassBoardColor` — faint enough to read as clear over
            // the `UIInputView(.keyboard)` backdrop, opaque enough to stay live.
            //
            // It renders as a plain `Color`, matching the pre-engine board
            // exactly: `Color` and `Rectangle().fill` have different ideal
            // sizes, and in the height-free showcase layout that difference
            // would shift the whole keyboard.
            theme.boardBackground
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
                    isLanguageLabelShown: viewModel.hasMultipleLanguages,
                    renderSettings: renderSettings,
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
}
