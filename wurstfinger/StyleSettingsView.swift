//
//  StyleSettingsView.swift
//  wurstfinger
//
//  Theme selection for the keyboard appearance.
//

import SwiftUI

/// What a theme row in the gallery offers. Built-ins are immutable templates,
/// so the list is derived once (`StyleSettingsView.rowActions(for:)`) instead
/// of being re-decided by every control — one shared row builder serves both
/// sections, which is exactly where an edit or delete control could otherwise
/// leak onto a built-in.
enum ThemeRowAction: CaseIterable {
    case select
    case duplicate
    case edit
    case delete
}

struct StyleSettingsView: View {
    @AppStorage(SettingsKey.selectedThemeLight.rawValue, store: SharedDefaults.store)
    private var selectedThemeLight = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.selectedThemeDark.rawValue, store: SharedDefaults.store)
    private var selectedThemeDark = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.themeSeparateDarkSlot.rawValue, store: SharedDefaults.store)
    private var hasSeparateDarkSlot = false

    /// Which slot the gallery currently edits and previews. Only meaningful
    /// while `hasSeparateDarkSlot` is on; otherwise everything reads and writes
    /// the light slot and the dark one is left untouched.
    @State private var editingAppearance: ColorScheme = .light

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayout.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayout.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayout.defaultKeyboardPosition

    /// 44 pt grown with the user's text size; clamped by `iconTargetSide(scaledFrom:)`.
    @ScaledMetric(relativeTo: .body) private var scaledIconTarget: CGFloat = 44

    /// User-created themes, reloaded from the store after every edit.
    @State private var userThemes: [KeyboardThemeDefinition] = ThemeStore.userThemes()

    /// The theme open in the editor sheet, if any.
    @State private var editSession: ThemeEditSession?

    /// The user theme the row-level delete button is asking about.
    @State private var themePendingDeletion: KeyboardThemeDefinition?

    /// The row a save just created, so the gallery can scroll it into view.
    @State private var themeToRevealId: String?

    /// A theme handed to the editor. A duplicate is *not* persisted before the
    /// editor opens — Save creates it — so cancelling leaves no orphaned
    /// "… Copy" behind, and the editor needs to know which case it is in.
    struct ThemeEditSession: Identifiable, Equatable {
        var theme: KeyboardThemeDefinition
        var isNewTheme: Bool

        var id: String {
            theme.id
        }
    }

    /// The theme id the gallery currently reflects: the dark slot while editing
    /// dark mode, otherwise the light slot (the only slot the resolver reads
    /// while the separate-dark-slot toggle is off).
    ///
    /// Static, like the write side in `slots(selecting:…)`: this decides which
    /// row wears the checkmark and which theme the preview renders, so getting
    /// the flag wrong here shows the user a theme they are not editing.
    static func activeThemeId(
        light: String,
        dark: String,
        hasSeparateDarkSlot: Bool,
        editingAppearance: ColorScheme
    ) -> String {
        hasSeparateDarkSlot && editingAppearance == .dark ? dark : light
    }

    /// The appearance the gallery previews and the editor designs against, or
    /// nil while one theme serves both slots (then the device decides).
    ///
    /// Static for the same reason, and this one is load-bearing twice over:
    /// every color well in the editor is seeded from the theme *as it renders
    /// in this appearance*, and the well freezes what it was seeded with as a
    /// fixed hex. Returning `.light` where nil belongs would hand a user on a
    /// dark device a whole palette of light-mode values, permanently.
    static func appearanceOverride(hasSeparateDarkSlot: Bool, editingAppearance: ColorScheme) -> ColorScheme? {
        hasSeparateDarkSlot ? editingAppearance : nil
    }

    private var activeThemeId: String {
        Self.activeThemeId(
            light: selectedThemeLight,
            dark: selectedThemeDark,
            hasSeparateDarkSlot: hasSeparateDarkSlot,
            editingAppearance: editingAppearance
        )
    }

    private var appearanceOverride: ColorScheme? {
        Self.appearanceOverride(hasSeparateDarkSlot: hasSeparateDarkSlot, editingAppearance: editingAppearance)
    }

    /// Everything the gallery lists, built-ins first.
    private var allThemes: [KeyboardThemeDefinition] {
        BuiltInThemes.all + userThemes
    }

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview — forced into the edited appearance so the dark
            // slot can be previewed on a light device (and vice versa).
            InteractiveKeyboardPreview(
                aspectRatio: $previewAspectRatio,
                width: $previewWidth,
                position: $previewPosition,
                appearanceOverride: appearanceOverride
            )
            .padding(.horizontal, 16)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 24) {
                        appearanceSection
                        builtInSection
                        userThemesSection
                    }
                    .padding(.vertical, 8)
                }
                // A theme saved from the editor is appended to "My Themes",
                // which on a phone sits below the fold: without this the only
                // visible result of Duplicate → Save is the checkmark leaving
                // the built-in row it was copied from.
                .onChange(of: themeToRevealId) { _, id in
                    guard let id else { return }
                    withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                    themeToRevealId = nil
                }
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editSession) { session in
            ThemeEditorView(
                theme: session.theme,
                isNewTheme: session.isNewTheme,
                // The editor designs for one slot and has to render in that
                // slot's appearance and the user's real geometry — otherwise a
                // dark-slot theme is judged against a light board at stock
                // width, and every color picked there is wrong where it lands.
                appearanceOverride: appearanceOverride,
                previewAspectRatio: $previewAspectRatio,
                previewWidth: $previewWidth,
                previewPosition: $previewPosition,
                onSave: { updated in save(updated, isNewTheme: session.isNewTheme) },
                onDelete: { id in delete(id: id) }
            )
        }
        // `presenting:` rather than reading `themePendingDeletion` back inside
        // the action: the derived `isPresented` binding nils the state, and
        // nothing defines whether SwiftUI writes it before or after the button
        // runs. Captured payload, no ordering assumption.
        .confirmationDialog(
            "Delete this theme?",
            isPresented: Binding(
                get: { themePendingDeletion != nil },
                set: { if !$0 { themePendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: themePendingDeletion
        ) { theme in
            Button(String(localized: "Delete \(theme.displayName)"), role: .destructive) {
                delete(id: theme.id)
            }
        }
    }

    /// Toggle for assigning a separate dark-mode theme, plus the light/dark
    /// segment that picks which slot the gallery edits.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use a different theme in Dark Mode", isOn: $hasSeparateDarkSlot)
                .padding(.horizontal, 16)
                .onChange(of: hasSeparateDarkSlot) { _, isOn in
                    // Only the editing focus resets. The dark slot is left
                    // exactly as it is: the resolver ignores it while the flag
                    // is off (`ThemeStore.theme(lightId:darkId:hasSeparateDarkSlot:for:)`),
                    // so collapsing it into the light id would buy nothing and
                    // cost the user their dark assignment on a single tap.
                    if !isOn { editingAppearance = .light }
                }

            if hasSeparateDarkSlot {
                Picker("Editing appearance", selection: $editingAppearance) {
                    Label("Light Mode", systemImage: "sun.max").tag(ColorScheme.light)
                    Label("Dark Mode", systemImage: "moon").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
        }
    }

    /// The three compiled-in themes. They are templates: selectable and
    /// duplicable, never editable.
    private var builtInSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Style")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(BuiltInThemes.all) { theme in
                themeRow(theme)
            }

            // Keyed off the resolved surface style, not the built-in id: a user
            // copy with glass keys hits the same fallback.
            if activeTheme.resolved().hasGlassKeys {
                if #unavailable(iOS 26.0) {
                    Text("Liquid Glass is designed for iOS 26 and later. On earlier versions a simplified translucent style is used.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                }
            }

            Text("Included themes can't be changed. Duplicate one to make a theme you can edit.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }

    /// User-created themes. Shown even while empty, so the section the
    /// immutability footer points at actually exists.
    private var userThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Themes")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(userThemes) { theme in
                themeRow(theme)
            }
        }
    }

    /// The theme the gallery currently shows as selected, or Classic when the
    /// stored id no longer resolves.
    private var activeTheme: KeyboardThemeDefinition {
        allThemes.first { $0.id == activeThemeId } ?? BuiltInThemes.classic
    }

    // MARK: - Rows

    /// The controls a row offers for `theme`. Built-ins are immutable
    /// templates, so duplicating is the only route from one to a theme the
    /// user can change.
    static func rowActions(for theme: KeyboardThemeDefinition) -> [ThemeRowAction] {
        theme.isBuiltIn ? [.select, .duplicate] : [.select, .duplicate, .edit, .delete]
    }

    /// One theme row, shared by both sections: swatch, name, selection state,
    /// and one visible icon button per action the theme allows. The context
    /// menu repeats them as a second route.
    private func themeRow(_ theme: KeyboardThemeDefinition) -> some View {
        let actions = Self.rowActions(for: theme)
        let isSelected = activeThemeId == theme.id
        return HStack(spacing: 8) {
            Button {
                select(theme)
            } label: {
                selectLabel(theme, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            // The checkmark is purely visual; VoiceOver needs the trait.
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])

            ForEach(actions.filter { $0 != .select }, id: \.self) { action in
                rowActionButton(action, for: theme)
            }
        }
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal, 8)
        .contextMenu { themeMenu(for: theme) }
        // Scroll anchor for a freshly saved theme (see `themeToRevealId`).
        .id(theme.id)
    }

    private func selectLabel(_ theme: KeyboardThemeDefinition, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ThemeSwatch(theme: theme)

            VStack(alignment: .leading, spacing: 4) {
                Text(theme.displayName)
                    .font(.body)
                    .foregroundColor(.primary)

                if let description = theme.displayDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// A visible affordance for one row action. Duplicating used to live in the
    /// context menu only — a long press with no hint — and it is now the only
    /// route to an editable theme.
    ///
    /// Every label names its theme. Without it the rotor and the Item Chooser
    /// list one "Delete" per user theme, all identical, for an action with no
    /// undo. Same pattern as `LanguageSelectionView`'s "Disable %@".
    @ViewBuilder private func rowActionButton(
        _ action: ThemeRowAction,
        for theme: KeyboardThemeDefinition
    ) -> some View {
        if let icon = Self.icon(for: action) {
            switch action {
            case .select:
                EmptyView()
            case .duplicate:
                iconButton(icon) { duplicate(theme) }
                    .accessibilityLabel(String(localized: "Duplicate \(theme.displayName)"))
            case .edit:
                iconButton(icon) { editSession = ThemeEditSession(theme: theme, isNewTheme: false) }
                    .accessibilityLabel(String(localized: "Edit \(theme.displayName)"))
            case .delete:
                iconButton(icon) { themePendingDeletion = theme }
                    .accessibilityLabel(String(localized: "Delete \(theme.displayName)"))
            }
        }
    }

    /// Glyph and tint of a row action's icon button. `.select` has none — the
    /// whole row is its control.
    ///
    /// The tint belongs in this table because it has to reach `iconButton` and
    /// be applied there, exactly once: a `.foregroundStyle` wrapped *around*
    /// the button loses to the one inside it, which is how the destructive
    /// trash came to render in the accent tint, indistinguishable from
    /// duplicate and edit.
    static func icon(for action: ThemeRowAction) -> RowIcon? {
        switch action {
        case .select: nil
        case .duplicate: RowIcon(systemImage: "plus.square.on.square", tint: .accentColor)
        case .edit: RowIcon(systemImage: "pencil", tint: .accentColor)
        // The one irreversible, undo-less action in the row. Red is its only
        // cue beyond the glyph.
        case .delete: RowIcon(systemImage: "trash", tint: .red)
        }
    }

    struct RowIcon: Equatable {
        var systemImage: String
        var tint: Color
    }

    /// Side of a row icon's hit area for a Dynamic-Type-scaled 44 pt, clamped.
    ///
    /// The lower bound holds the 44 pt minimum target at the small text sizes,
    /// where the scaled value drops below it. The upper bound is what makes
    /// three of these fit a phone at AX5 — a fully scaled target would be
    /// ~137 pt wide and the row would run off the screen.
    static func iconTargetSide(scaledFrom scaled: CGFloat) -> CGFloat {
        min(max(scaled, 44), 64)
    }

    /// Fraction of the hit area the glyph is drawn at, so the two can never
    /// diverge — see `iconButton`.
    static let iconGlyphFraction: CGFloat = 0.45

    /// A glyph-only control with a hit area around it.
    ///
    /// Both the area and the glyph scale with Dynamic Type, and the glyph is
    /// sized *from* the area rather than from the ambient font. `.frame` does
    /// not clip a non-resizable `Image`: with a fixed 36×44 box an AX5 glyph
    /// rendered ~60 pt and spilled ~12 pt past each edge, so the visible trash
    /// overlapped the pencil's hit region and tapping it opened the editor.
    ///
    /// The tint arrives as a parameter and is applied here and nowhere else —
    /// see `icon(for:)`.
    private func iconButton(_ icon: RowIcon, action: @escaping () -> Void) -> some View {
        let side = Self.iconTargetSide(scaledFrom: scaledIconTarget)
        return Button(action: action) {
            Image(systemName: icon.systemImage)
                .font(.system(size: side * Self.iconGlyphFraction))
                .frame(width: side, height: side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(icon.tint)
    }

    // MARK: - Theme actions

    /// Second route to the same actions, from the same list, so the menu can
    /// never offer more than the row does.
    private func themeMenu(for theme: KeyboardThemeDefinition) -> some View {
        ForEach(Self.rowActions(for: theme).filter { $0 != .select }, id: \.self) { action in
            switch action {
            case .select:
                EmptyView()
            case .duplicate:
                Button {
                    duplicate(theme)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
            case .edit:
                Button {
                    editSession = ThemeEditSession(theme: theme, isNewTheme: false)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            case .delete:
                Button(role: .destructive) {
                    themePendingDeletion = theme
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    /// The editor session a Duplicate tap opens: a user-owned copy of `theme`
    /// that is **not** written to `defaults`. Save creates it, so cancelling
    /// leaves no orphaned "… Copy" behind.
    ///
    /// Static and defaults-injected so that promise is actually testable — the
    /// instance method below is unreachable from a test, and asserting on
    /// `ThemeStore.duplicate` instead only proves that a pure function is pure.
    static func editSession(
        duplicating theme: KeyboardThemeDefinition,
        defaults: UserDefaults = SharedDefaults.store
    ) -> ThemeEditSession {
        ThemeEditSession(
            theme: ThemeStore.duplicate(theme, existing: ThemeStore.userThemes(defaults: defaults)),
            isNewTheme: true
        )
    }

    private func duplicate(_ theme: KeyboardThemeDefinition) {
        editSession = Self.editSession(duplicating: theme)
    }

    private func save(_ theme: KeyboardThemeDefinition, isNewTheme: Bool) {
        ThemeStore.saveUserTheme(theme)
        reloadUserThemes()
        applySlots(Self.slots(
            afterSaving: theme.id,
            isNewTheme: isNewTheme,
            light: selectedThemeLight,
            dark: selectedThemeDark,
            hasSeparateDarkSlot: hasSeparateDarkSlot,
            editingAppearance: editingAppearance
        ))
        themeToRevealId = theme.id
    }

    private func delete(id: String) {
        ThemeStore.deleteUserTheme(id: id)
        reloadUserThemes()
    }

    /// Assigns the theme to the slot being edited.
    private func select(_ theme: KeyboardThemeDefinition) {
        applySlots(Self.slots(
            selecting: theme.id,
            light: selectedThemeLight,
            dark: selectedThemeDark,
            hasSeparateDarkSlot: hasSeparateDarkSlot,
            editingAppearance: editingAppearance
        ))
    }

    private func applySlots(_ slots: (light: String, dark: String)) {
        selectedThemeLight = slots.light
        selectedThemeDark = slots.dark
    }

    /// The two slot ids after assigning `themeId` to the slot being edited.
    ///
    /// With the separate-dark-slot toggle off only the light slot is written.
    /// Mirroring into the dark slot would render identically — the resolver
    /// ignores the dark slot in that state — but it would destroy a stored dark
    /// assignment on a tap, which is the same data loss the toggle itself was
    /// stopped from doing. Leaving the slot alone means switching the toggle
    /// back on restores the user's earlier dark choice instead of whatever was
    /// selected last, so a round trip through the toggle is lossless from
    /// either side.
    static func slots(
        selecting themeId: String,
        light: String,
        dark: String,
        hasSeparateDarkSlot: Bool,
        editingAppearance: ColorScheme
    ) -> (light: String, dark: String) {
        guard hasSeparateDarkSlot else { return (themeId, dark) }
        return editingAppearance == .dark ? (light, themeId) : (themeId, dark)
    }

    /// The two slot ids after saving. A new theme is always a fresh duplicate,
    /// and selecting it is the only visible result duplicating has — but an
    /// edit must leave the selection alone, or editing a theme parked in the
    /// dark slot would silently steal the light one.
    static func slots(
        afterSaving themeId: String,
        isNewTheme: Bool,
        light: String,
        dark: String,
        hasSeparateDarkSlot: Bool,
        editingAppearance: ColorScheme
    ) -> (light: String, dark: String) {
        guard isNewTheme else { return (light, dark) }
        return slots(
            selecting: themeId,
            light: light,
            dark: dark,
            hasSeparateDarkSlot: hasSeparateDarkSlot,
            editingAppearance: editingAppearance
        )
    }

    private func reloadUserThemes() {
        userThemes = ThemeStore.userThemes()
    }
}

/// Miniature key over the theme's own board, rendered through the same
/// resolved values and surface styles the keyboard uses. It has to draw the
/// board, the glass material, the corner radius and the border, not just a
/// fill: with glass a per-surface style, a glass copy and a Classic copy of the
/// same palette carry identical colors — and two copies that differ only in
/// radius or border would read as the same grey square, which is exactly the
/// indistinguishability this swatch exists to prevent.
struct ThemeSwatch: View {
    let theme: KeyboardThemeDefinition

    private static let size: CGFloat = 44
    private static let keyInset: CGFloat = 7

    /// Side of the drawn key.
    private static let keySize: CGFloat = size - 2 * keyInset

    /// Shrink factor from a rendered key to this miniature, so the theme's
    /// point values keep their *proportions* here. Used raw, a 12 pt radius
    /// would turn a 30 pt key into a pill.
    private static let keyScale = keySize / KeyboardConstants.KeyDimensions.height

    /// The theme's corner radius at swatch scale.
    static func swatchRadius(forKeyRadius radius: CGFloat) -> CGFloat {
        radius * keyScale
    }

    /// The theme's border width at swatch scale, but never thinner than a
    /// hairline: scaled down, a 0.5 pt border would vanish and a theme with a
    /// border would look like one without.
    static func swatchBorderWidth(forKeyBorderWidth width: CGFloat) -> CGFloat {
        max(width * keyScale, 0.5)
    }

    var body: some View {
        let resolved = theme.resolved()
        ZStack {
            resolved.boardBackground
            key(resolved)
                .padding(Self.keyInset)
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        // Decoration beside a label that already names the theme.
        .accessibilityHidden(true)
    }

    /// The same three branches `KeyView` renders, including which of them
    /// draws the border: native Liquid Glass on iOS 26 (no border — the effect
    /// replaces the background layer), the `.bar` material with the border
    /// below it, a plain fill with the border for a color key.
    @ViewBuilder private func key(_ resolved: ResolvedTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.swatchRadius(forKeyRadius: resolved.cornerRadius))
        if resolved.hasGlassKeys, #available(iOS 26.0, *) {
            letter(resolved)
                .glassEffect(.regular.tint(KeyView.glassTint), in: shape)
        } else if resolved.hasGlassKeys {
            filled(shape, with: .bar, resolved: resolved).overlay(letter(resolved))
        } else {
            filled(shape, with: resolved.keyColor, resolved: resolved).overlay(letter(resolved))
        }
    }

    /// Mirrors `KeyView.filled`: no border in the tree at all for a theme
    /// without one.
    @ViewBuilder private func filled(
        _ shape: RoundedRectangle,
        with fill: some ShapeStyle,
        resolved: ResolvedTheme
    ) -> some View {
        if let border = resolved.keyBorder, resolved.keyBorderWidth > 0 {
            shape.fill(fill)
                .overlay(shape.strokeBorder(
                    border,
                    lineWidth: Self.swatchBorderWidth(forKeyBorderWidth: resolved.keyBorderWidth)
                ))
        } else {
            shape.fill(fill)
        }
    }

    private func letter(_ resolved: ResolvedTheme) -> some View {
        Text(verbatim: "a")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(resolved.mainLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
