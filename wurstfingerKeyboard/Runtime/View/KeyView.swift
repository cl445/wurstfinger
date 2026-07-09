//
//  KeyView.swift
//  Wurstfinger
//
//  Generic key view that renders any KeyConfig with style-based appearance
//  and full gesture recognition.
//

import SwiftUI

/// Generic key view that renders any `KeyConfig`.
///
/// Visual appearance is driven by `key.style`. Hints derive directly from
/// `key.bindings`, so only the gestures actually defined on a key are shown.
/// Keys with a `slideType` (space, delete) use `SlideGestureHandler` for
/// continuous drag tracking. All other keys use `KeyGestureRecognizer` for
/// swipe/tap/circular gesture classification.
struct KeyView: View {
    let key: KeyConfig
    let onGesture: (KeyConfig, GestureType, Bool) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?
    /// Handles a long press on this key; returns whether it dispatched an
    /// action (a handled long press consumes the touch). Long-press detection
    /// only runs when this is set and the user setting is enabled.
    var onLongPress: ((KeyConfig) -> Bool)?
    var spanRatio: CGFloat = 1.0

    /// Inset between the full touch cell and the key's visible bounds. The cell
    /// supplied by `KeyboardGridLayout` extends halfway into the gap toward each
    /// neighbour so there are no dead zones; insetting the drawn content by the
    /// same amount keeps the visible key exactly where it was. Defaults to zero.
    var visualInset: EdgeInsets = .init()

    @State private var isActive = false

    /// Resolved once in `DataDrivenKeyboardRootView` and injected here — key
    /// views never resolve theme data themselves.
    @Environment(\.keyboardTheme) private var theme

    /// Resolved layout metrics injected by `KeyboardGridView` (same reasoning
    /// as there: an `@AppStorage` read desynchronizes from the width path
    /// when the view model is configured programmatically). Feeds the gesture
    /// classification geometry and the font scaling. No default: every caller
    /// must pass the resolved metrics explicitly so a `.reference` fallback can
    /// never silently mask a wiring gap (production sites already do).
    var metrics: KeyboardLayoutMetrics

    /// Short language label (e.g. "DE") shown on the switch key, and whether to
    /// show it. Driven by the active keyboard locale via `KeyboardViewModel`
    /// (threaded through `KeyboardGridView`) rather than re-derived from shared
    /// defaults, so the hint stays correct even when startup loads a pinned
    /// language whose id differs from the stored selection.
    var languageLabel: String = ""
    var showLanguageLabel: Bool = false

    @AppStorage(SettingsKey.hideLetters.rawValue, store: SharedDefaults.store)
    private var hideLetters = false

    @AppStorage(SettingsKey.hideStandardSymbols.rawValue, store: SharedDefaults.store)
    private var hideStandardSymbols = false

    @AppStorage(SettingsKey.hideExtraSymbols.rawValue, store: SharedDefaults.store)
    private var hideExtraSymbols = false

    @AppStorage(SettingsKey.longPressNumbersEnabled.rawValue, store: SharedDefaults.store)
    private var longPressNumbersEnabled = false

    /// Whether the label of `binding` should be drawn, honouring the user's
    /// label-visibility toggles (numbers and functional keys always show).
    private func isLabelVisible(_ binding: KeyBinding) -> Bool {
        LabelCategory.of(binding).isVisible(
            hideLetters: hideLetters,
            hideStandardSymbols: hideStandardSymbols,
            hideExtraSymbols: hideExtraSymbols
        )
    }

    /// Maps emoji labels to SF Symbol names for utility keys.
    private static let sfSymbolMap: [String: String] = [
        "🌐": "globe",
        "⌫": "delete.backward",
        "↵": "return",
    ]

    var body: some View {
        keyContent
    }

    @ViewBuilder
    private var keyContent: some View {
        let base = keyLayers
            // Inset the drawn key from the touch cell by `visualInset`, so the
            // visible key keeps its position/size while the cell itself extends into
            // the inter-key gaps (see KeyboardGridLayout.gapInsets).
            .padding(visualInset)
            // Fill the cell frame imposed by KeyboardGridLayout. The layout sizes
            // rows from the same effective key height, so single-row keys are
            // unchanged while a spanning key (e.g. landscape return) grows to cover
            // multiple rows.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier(key.id)
            .accessibilityAddTraits(.isButton)
            // The whole cell is the touch target. Adjacent cells tile the surface
            // with no gaps, so a plain rectangle covers it fully.
            .contentShape(Rectangle())
            // Pin the key's alignment/padding surface to physical LTR so the
            // directional hints (`hintAlignments` / `hintEdgePadding`, which use
            // semantic leading/trailing) always match the physical swipe
            // directions — even when a host renders this key under an RTL locale
            // (e.g. KeyboardShowcaseView / AppStoreScreenshotView for localized
            // screenshots, or SwiftUI previews). Defense-in-depth alongside the
            // root pin in DataDrivenKeyboardRootView; nested identical pins are
            // harmless.
            .environment(\.layoutDirection, .leftToRight)

        if usesSlideGesture {
            base.modifier(SlideGestureHandler(
                slideType: key.slideType,
                onSlide: { phase in onSlide?(key, phase) },
                onTouchDown: { onTouchDown?() },
                onLongPress: longPressHandler,
                isActive: $isActive
            ))
        } else {
            base.modifier(KeyGestureRecognizer(
                onGestureRecognized: { classification in
                    onGesture(key, classification.gesture, classification.isReturn)
                },
                onTouchDown: { onTouchDown?() },
                // Account for the spanned cell: a multi-row/-column key is not
                // 1×1, so scale the rendered cell aspect ratio (from the same
                // metrics that size the cell) by columnSpan/rowSpan (spanRatio)
                // to classify swipes against the real geometry.
                aspectRatio: metrics.cellAspectRatio * spanRatio,
                onLongPress: longPressHandler,
                isActive: $isActive
            ))
        }
    }

    // MARK: - Style

    /// Primary text shown on the key. Falls back to the binding label or the
    /// key id (so unconfigured keys are still visible during development).
    var primaryLabel: String {
        if let tap = key.bindings[.tap] {
            return tap.label
        }
        return key.id
    }

    var accessibilityLabel: String {
        if let tap = key.bindings[.tap], let custom = tap.accessibilityLabel {
            return custom
        }
        return primaryLabel
    }

    /// Base font size derived from the visual style.
    static func baseFontSize(for style: KeyStyle) -> CGFloat {
        switch style {
        case .primary:
            KeyboardConstants.FontSizes.mainLabelBaseSize
        case .secondary:
            KeyboardConstants.FontSizes.hintBaseSize
        case .utility:
            KeyboardConstants.FontSizes.utilityLabel
        case .spacebar:
            KeyboardConstants.FontSizes.defaultLabel
        case .accent:
            KeyboardConstants.FontSizes.mainLabelBaseSize
        }
    }

    /// Scaled font size proportional to the rendered cell height
    /// (`metrics.fontScale` is cell height over the reference key height).
    private var scaledFontSize: CGFloat {
        let base = Self.baseFontSize(for: key.style)
        let scaled = base * metrics.fontScale
        return min(max(scaled, KeyboardConstants.FontSizes.mainLabelMinSize), KeyboardConstants.FontSizes.mainLabelMaxSize)
    }

    /// Scaled hint font size proportional to the rendered cell height.
    private var scaledHintFontSize: CGFloat {
        let base = KeyboardConstants.FontSizes.hintBaseSize
        let scaled = base * metrics.fontScale
        return min(max(scaled, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
    }

    /// Whether the key should be rendered as an icon-only key (no text label).
    static func isIconOnly(style: KeyStyle) -> Bool {
        style == .utility
    }

    // MARK: - Gesture Selection

    /// Whether this key uses slide gesture handling instead of standard
    /// gesture classification.
    private var usesSlideGesture: Bool {
        key.slideType != .none
    }

    /// Long-press handler for the gesture recognizer, or nil when the
    /// opt-in setting is off or no handler is wired up (preview contexts).
    private var longPressHandler: (() -> Bool)? {
        guard longPressNumbersEnabled, let onLongPress else { return nil }
        return { onLongPress(key) }
    }

    // MARK: - View Construction

    /// Whether this key should render as native Liquid Glass (iOS 26 with a
    /// material fill). The glass then wraps the label layer directly, so the
    /// label stays crisp and picks up glass vibrancy — applying it to a
    /// separate background layer instead blurs the label.
    private var usesNativeGlass: Bool {
        if #available(iOS 26.0, *) {
            return (isActive ? theme.keyFillActive : theme.keyFill) == .material
        }
        return false
    }

    /// A subtle neutral tint on the glass, so the keys gain a bit of presence
    /// and stand out from the backdrop instead of reading as fully clear glass
    /// — while staying native Liquid Glass that blends with the system row.
    private static let glassTint = Color.gray.opacity(0.12)

    /// The stacked key layers. Native glass wraps the label/hint content with
    /// `glassEffect` (label as content = crisp); every other style keeps the
    /// pre-engine order of a background layer beneath the labels.
    @ViewBuilder
    private var keyLayers: some View {
        if usesNativeGlass, #available(iOS 26.0, *) {
            ZStack {
                label
                hintOverlay
            }
            .glassEffect(.regular.tint(Self.glassTint), in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        } else {
            ZStack {
                background
                label
                hintOverlay
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
        let fill = isActive ? theme.keyFillActive : theme.keyFill
        switch fill {
        case let .color(color):
            colorBackground(shape, color)
        case .material:
            // Reached only before iOS 26 (native glass takes the other branch):
            // the bar material with a hairline border, pixel-identical to the
            // pre-engine Liquid Glass rendering.
            if let border = theme.keyBorder, theme.keyBorderWidth > 0 {
                shape.fill(.bar)
                    .overlay(shape.strokeBorder(border, lineWidth: theme.keyBorderWidth))
            } else {
                shape.fill(.bar)
            }
        }
    }

    /// Solid or translucent color fill, with an optional hairline border.
    @ViewBuilder
    private func colorBackground(_ shape: RoundedRectangle, _ color: Color) -> some View {
        if let border = theme.keyBorder, theme.keyBorderWidth > 0 {
            shape.fill(color)
                .overlay(shape.strokeBorder(border, lineWidth: theme.keyBorderWidth))
        } else {
            // No border overlay in the view tree at all — themes without a
            // border (Classic) render exactly as before the theme engine.
            shape.fill(color)
        }
    }

    /// Center label color: utility glyphs may differ from letter keys.
    private var labelColor: Color {
        key.style == .utility ? theme.utilityLabel : theme.mainLabel
    }

    @ViewBuilder
    private var label: some View {
        if key.style == .spacebar {
            // Spacebar renders blank — label is purely for accessibility.
            EmptyView()
        } else if let tap = key.bindings[.tap], !isLabelVisible(tap) {
            // The centre label is hidden by the label-visibility setting.
            EmptyView()
        } else {
            let font = Font.system(size: scaledFontSize, weight: .semibold, design: .rounded)
            if let sfName = Self.sfSymbolMap[primaryLabel] {
                Image(systemName: sfName)
                    .font(font)
                    .foregroundColor(labelColor)
            } else {
                Text(primaryLabel)
                    .font(font)
                    .foregroundColor(labelColor)
            }
        }
    }

    // MARK: - Hint Overlay

    /// Mapping from swipe `GestureType` to the SwiftUI `Alignment` where
    /// the hint label should be placed. These are PHYSICAL edges: the render
    /// tree is pinned to `.leftToRight` (see `keyContent`) so `.leading`
    /// resolves to the physical left and `.trailing` to the physical right
    /// regardless of the system language. Must never be mirrored for RTL —
    /// the swipe gesture classification is physical, so mirroring the hints
    /// would show a glyph on the opposite edge from the swipe that produces
    /// it. `internal` (not `private`) so the guard tests can lock the mapping.
    static let hintAlignments: [GestureType: Alignment] = [
        .swipeUp: .top,
        .swipeDown: .bottom,
        .swipeLeft: .leading,
        .swipeRight: .trailing,
        .swipeUpLeft: .topLeading,
        .swipeUpRight: .topTrailing,
        .swipeDownLeft: .bottomLeading,
        .swipeDownRight: .bottomTrailing,
    ]

    /// Maps certain key actions to SF Symbol names for hint rendering.
    private static func hintIcon(for action: KeyAction) -> String? {
        switch action {
        case .advanceToNextInputMode: "globe"
        case .dismissKeyboard: "keyboard.chevron.compact.down"
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .cut: "scissors"
        // Note: on the globe key `hintOverlay` renders the current-language
        // label (e.g. "DE") for this action instead — both occupy the same
        // directional slot, so the more informative label wins there. The
        // icon keeps the action→icon mapping complete for any other render
        // of a language-switch binding.
        case .switchToNextLanguage: "globe.badge.chevron.backward"
        default: nil
        }
    }

    /// Directional edge padding for hint labels. Padding is only applied on
    /// the edges where the hint is aligned, keeping hints close to the key
    /// border and away from the center label. The `leading`/`trailing` insets
    /// resolve to physical left/right because the render tree is pinned to
    /// `.leftToRight`; like `hintAlignments`, this table must not be mirrored
    /// for RTL. `internal` (not `private`) so the guard tests can lock it.
    static func hintEdgePadding(
        for gesture: GestureType, horizontal: CGFloat, vertical: CGFloat
    ) -> EdgeInsets {
        switch gesture {
        case .swipeUp:
            EdgeInsets(top: vertical, leading: 0, bottom: 0, trailing: 0)
        case .swipeDown:
            EdgeInsets(top: 0, leading: 0, bottom: vertical, trailing: 0)
        case .swipeLeft:
            EdgeInsets(top: 0, leading: horizontal, bottom: 0, trailing: 0)
        case .swipeRight:
            EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: horizontal)
        case .swipeUpLeft:
            EdgeInsets(top: vertical, leading: horizontal, bottom: 0, trailing: 0)
        case .swipeUpRight:
            EdgeInsets(top: vertical, leading: 0, bottom: 0, trailing: horizontal)
        case .swipeDownLeft:
            EdgeInsets(top: 0, leading: horizontal, bottom: vertical, trailing: 0)
        case .swipeDownRight:
            EdgeInsets(top: 0, leading: 0, bottom: vertical, trailing: horizontal)
        default:
            EdgeInsets()
        }
    }

    private var hintOverlay: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Scale padding proportionally with font size
            let fontRatio = scaledHintFontSize / KeyboardConstants.FontSizes.hintReferenceFontSize
            let hPad = KeyboardConstants.FontSizes.hintBaseHorizontalPadding * fontRatio
            let vPad = KeyboardConstants.FontSizes.hintBaseVerticalPadding * fontRatio

            ForEach(Array(key.bindings.keys), id: \.self) { gesture in
                // Render a hint when it has a text label, or when the action
                // maps to an icon (globe, dismiss, copy/cut/paste). Utility
                // icon hints carry an empty label on purpose — their glyph is
                // derived from the action, so gating on the label alone would
                // hide them entirely.
                if let binding = key.bindings[gesture],
                   let alignment = Self.hintAlignments[gesture] {
                    if binding.action == .switchToNextLanguage {
                        if showLanguageLabel {
                            Text(languageLabel)
                                .font(.system(size: scaledHintFontSize * 0.75, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.hintIconProminent)
                                .fixedSize()
                                .padding(Self.hintEdgePadding(for: gesture, horizontal: hPad, vertical: vPad))
                                .frame(
                                    width: size.width,
                                    height: size.height,
                                    alignment: alignment
                                )
                        }
                    } else if !binding.label.isEmpty || Self.hintIcon(for: binding.action) != nil,
                              isLabelVisible(binding) {
                        hintContent(for: binding)
                            .fixedSize()
                            .padding(Self.hintEdgePadding(for: gesture, horizontal: hPad, vertical: vPad))
                            .frame(
                                width: size.width,
                                height: size.height,
                                alignment: alignment
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Whether the icon is a "globe-style" hint (globe, dismiss) that gets
    /// larger, bolder styling vs. a "symbols-style" hint (copy, paste, cut).
    private static func isGlobeStyleIcon(for action: KeyAction) -> Bool {
        switch action {
        case .advanceToNextInputMode, .dismissKeyboard: true
        default: false
        }
    }

    @ViewBuilder
    private func hintContent(for binding: KeyBinding) -> some View {
        if let iconName = Self.hintIcon(for: binding.action) {
            if Self.isGlobeStyleIcon(for: binding.action) {
                // Globe / dismiss: larger, bolder for discoverability
                Image(systemName: iconName)
                    .font(.system(size: scaledHintFontSize * 0.75, weight: .medium))
                    .foregroundStyle(theme.hintIconProminent)
            } else {
                // Copy / paste / cut: smaller, lighter to avoid visual clutter
                Image(systemName: iconName)
                    .font(.system(size: scaledHintFontSize * 0.6, weight: .regular))
                    .foregroundStyle(theme.hintIconSubtle)
            }
        } else {
            // Text hint — letters get higher prominence than symbols
            let isLetter = binding.label.first?.isLetter ?? false
            Text(binding.label)
                .font(.system(
                    size: scaledHintFontSize,
                    weight: isLetter ? .medium : .regular,
                    design: .rounded
                ))
                .foregroundStyle(isLetter ? theme.hintLetter : theme.hintSymbol)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}
