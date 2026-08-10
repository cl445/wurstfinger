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
enum ThemeRowAction {
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
    private var separateDarkSlot = false

    /// Which slot the gallery currently edits and previews. Only meaningful
    /// while `separateDarkSlot` is on; otherwise selection writes both slots.
    @State private var editingAppearance: ColorScheme = .light

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayout.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayout.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayout.defaultKeyboardPosition

    /// User-created themes, reloaded from the store after every edit.
    @State private var userThemes: [KeyboardThemeDefinition] = ThemeStore.userThemes()

    /// The theme open in the editor sheet, if any.
    @State private var editSession: ThemeEditSession?

    /// The user theme the row-level delete button is asking about.
    @State private var themePendingDeletion: KeyboardThemeDefinition?

    /// A theme handed to the editor. A duplicate is *not* persisted before the
    /// editor opens — Save creates it — so cancelling leaves no orphaned
    /// "… Copy" behind, and the editor needs to know which case it is in.
    private struct ThemeEditSession: Identifiable {
        var theme: KeyboardThemeDefinition
        var isNewTheme: Bool

        var id: String {
            theme.id
        }
    }

    /// The theme id the gallery currently reflects: the dark slot while editing
    /// dark mode, otherwise the light slot (which both slots share when the
    /// separate-dark-slot toggle is off).
    private var activeThemeId: String {
        separateDarkSlot && editingAppearance == .dark ? selectedThemeDark : selectedThemeLight
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
                appearanceOverride: separateDarkSlot ? editingAppearance : nil
            )
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    appearanceSection
                    builtInSection
                    userThemesSection
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editSession) { session in
            ThemeEditorView(
                theme: session.theme,
                isNewTheme: session.isNewTheme,
                onSave: { updated in save(updated, isNewTheme: session.isNewTheme) },
                onDelete: { id in delete(id: id) }
            )
        }
        .confirmationDialog(
            "Delete this theme?",
            isPresented: Binding(
                get: { themePendingDeletion != nil },
                set: { if !$0 { themePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Theme", role: .destructive) {
                if let theme = themePendingDeletion { delete(id: theme.id) }
                themePendingDeletion = nil
            }
        }
    }

    /// Toggle for assigning a separate dark-mode theme, plus the light/dark
    /// segment that picks which slot the gallery edits.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use a different theme in Dark Mode", isOn: $separateDarkSlot)
                .padding(.horizontal, 16)
                .onChange(of: separateDarkSlot) { _, isOn in
                    if !isOn {
                        // Collapse back to one selection.
                        selectedThemeDark = selectedThemeLight
                        editingAppearance = .light
                    }
                }

            if separateDarkSlot {
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
    @ViewBuilder private func rowActionButton(
        _ action: ThemeRowAction,
        for theme: KeyboardThemeDefinition
    ) -> some View {
        switch action {
        case .select:
            EmptyView()
        case .duplicate:
            iconButton("plus.square.on.square") { duplicate(theme) }
                .accessibilityLabel("Duplicate")
        case .edit:
            iconButton("pencil") { editSession = ThemeEditSession(theme: theme, isNewTheme: false) }
                .accessibilityLabel("Edit")
        case .delete:
            iconButton("trash") { themePendingDeletion = theme }
                .foregroundStyle(.red)
                .accessibilityLabel("Delete")
        }
    }

    /// A glyph-only control with a hit area around it — the icons sit next to
    /// each other and a bare SF Symbol is far under the 44 pt minimum.
    private func iconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
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

    /// Opens a user-owned copy in the editor without persisting it. Saving
    /// creates it; cancelling leaves the store untouched.
    private func duplicate(_ theme: KeyboardThemeDefinition) {
        editSession = ThemeEditSession(
            theme: ThemeStore.duplicate(theme, existing: userThemes),
            isNewTheme: true
        )
    }

    private func save(_ theme: KeyboardThemeDefinition, isNewTheme: Bool) {
        ThemeStore.saveUserTheme(theme)
        reloadUserThemes()
        applySlots(Self.slots(
            afterSaving: theme.id,
            isNewTheme: isNewTheme,
            light: selectedThemeLight,
            dark: selectedThemeDark,
            separateDarkSlot: separateDarkSlot,
            editingAppearance: editingAppearance
        ))
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
            separateDarkSlot: separateDarkSlot,
            editingAppearance: editingAppearance
        ))
    }

    private func applySlots(_ slots: (light: String, dark: String)) {
        selectedThemeLight = slots.light
        selectedThemeDark = slots.dark
    }

    /// The two slot ids after assigning `themeId` to the slot being edited.
    /// With the separate-dark-slot toggle off, both slots follow one selection.
    static func slots(
        selecting themeId: String,
        light: String,
        dark: String,
        separateDarkSlot: Bool,
        editingAppearance: ColorScheme
    ) -> (light: String, dark: String) {
        guard separateDarkSlot else { return (themeId, themeId) }
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
        separateDarkSlot: Bool,
        editingAppearance: ColorScheme
    ) -> (light: String, dark: String) {
        guard isNewTheme else { return (light, dark) }
        return slots(
            selecting: themeId,
            light: light,
            dark: dark,
            separateDarkSlot: separateDarkSlot,
            editingAppearance: editingAppearance
        )
    }

    private func reloadUserThemes() {
        userThemes = ThemeStore.userThemes()
    }
}

/// Miniature key over the theme's own board, rendered through the same
/// resolved values and surface styles the keyboard uses. It has to draw the
/// board and the glass material, not just a fill: with glass a per-surface
/// style, a glass copy and a Classic copy of the same palette carry identical
/// colors and would otherwise be indistinguishable in the list.
private struct ThemeSwatch: View {
    let theme: KeyboardThemeDefinition

    /// Mirrors `KeyView.glassTint`, which is private to the keyboard: without
    /// it the swatch's glass reads as an empty hole at this size.
    private static let glassTint = Color.gray.opacity(0.12)

    private static let size: CGFloat = 44
    private static let keyInset: CGFloat = 7
    private static let keyRadius: CGFloat = 6

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

    /// The same two branches `KeyView` renders: native Liquid Glass on iOS 26,
    /// the `.bar` material below it, a plain fill for a color key.
    @ViewBuilder private func key(_ resolved: ResolvedTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.keyRadius)
        if resolved.hasGlassKeys, #available(iOS 26.0, *) {
            letter(resolved)
                .glassEffect(.regular.tint(Self.glassTint), in: shape)
        } else if resolved.hasGlassKeys {
            shape.fill(.bar).overlay(letter(resolved))
        } else {
            shape.fill(resolved.keyColor).overlay(letter(resolved))
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
