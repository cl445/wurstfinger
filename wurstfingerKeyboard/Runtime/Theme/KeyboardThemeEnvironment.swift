//
//  KeyboardThemeEnvironment.swift
//  Wurstfinger
//
//  Environment plumbing for the resolved theme.
//

import SwiftUI

extension EnvironmentValues {
    /// The resolved theme, injected once by `DataDrivenKeyboardRootView`.
    @Entry var keyboardTheme: ResolvedTheme = BuiltInThemes.classic.resolved()
}
