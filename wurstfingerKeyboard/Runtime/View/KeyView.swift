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

    @AppStorage(SettingsKey.keyboardStyle.rawValue, store: SharedDefaults.store)
    private var keyboardStyle: KeyboardStyle = .classic

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var keyboardScale: Double = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var keyAspectRatio: Double = DeviceLayoutUtils.defaultKeyAspectRatio

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
        let base = ZStack {
            background
            label
            hintOverlay
        }
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

        if usesSlideGesture {
            base.modifier(SlideGestureHandler(
                slideType: key.slideType,
                onSlide: { phase in onSlide?(key, phase) },
                onTouchDown: { onTouchDown?() },
                isActive: $isActive
            ))
        } else {
            base.modifier(KeyGestureRecognizer(
                onGestureRecognized: { classification in
                    onGesture(key, classification.gesture, classification.isReturn)
                },
                onTouchDown: { onTouchDown?() },
                // Account for the spanned cell: a multi-row/-column key is not
                // 1×1, so scale the base aspect ratio by columnSpan/rowSpan
                // (spanRatio) to classify swipes against the real geometry.
                aspectRatio: CGFloat(keyAspectRatio) * spanRatio,
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

    /// Effective key height accounting for both keyboard scale and aspect ratio.
    private var effectiveKeyHeight: CGFloat {
        KeyboardConstants.Calculations.keyHeight(aspectRatio: keyAspectRatio) * keyboardScale
    }

    /// Scaled font size proportional to effective key height.
    private var scaledFontSize: CGFloat {
        let base = Self.baseFontSize(for: key.style)
        let scaled = base * (effectiveKeyHeight / KeyboardConstants.FontSizes.mainLabelReferenceHeight)
        return min(max(scaled, KeyboardConstants.FontSizes.mainLabelMinSize), KeyboardConstants.FontSizes.mainLabelMaxSize)
    }

    /// Scaled hint font size proportional to effective key height.
    private var scaledHintFontSize: CGFloat {
        let base = KeyboardConstants.FontSizes.hintBaseSize
        let scaled = base * (effectiveKeyHeight / KeyboardConstants.FontSizes.hintReferenceHeight)
        return min(max(scaled, KeyboardConstants.FontSizes.hintMinSize), KeyboardConstants.FontSizes.hintMaxSize)
    }

    /// Whether the key should be rendered as an icon-only key (no text label).
    static func isIconOnly(style: KeyStyle) -> Bool {
        style == .utility
    }

    /// Background fill for the key.
    static func backgroundColor(for style: KeyStyle, active: Bool = false) -> Color {
        if active {
            return Color(.tertiarySystemFill)
        }
        return Color(.secondarySystemBackground)
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

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
        switch keyboardStyle {
        case .classic:
            shape.fill(Self.backgroundColor(for: key.style, active: isActive))
        case .liquidGlass:
            shape.fill(.bar)
                .overlay(
                    shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
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
                    .foregroundColor(.primary)
            } else {
                Text(primaryLabel)
                    .font(font)
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Hint Overlay

    /// Mapping from swipe `GestureType` to the SwiftUI `Alignment` where
    /// the hint label should be placed.
    private static let hintAlignments: [GestureType: Alignment] = [
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
        default: nil
        }
    }

    /// Directional edge padding for hint labels. Padding is only applied on
    /// the edges where the hint is aligned, keeping hints close to the key
    /// border and away from the center label.
    private static func hintEdgePadding(
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
                                .foregroundStyle(Color.primary.opacity(0.5))
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
                    .foregroundStyle(Color.primary.opacity(0.5))
            } else {
                // Copy / paste / cut: smaller, lighter to avoid visual clutter
                Image(systemName: iconName)
                    .font(.system(size: scaledHintFontSize * 0.6, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.45))
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
                .foregroundStyle(
                    isLetter
                        ? Color.primary.opacity(0.65)
                        : Color.secondary.opacity(0.55)
                )
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}
