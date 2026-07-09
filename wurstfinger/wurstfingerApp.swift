//
//  wurstfingerApp.swift
//  wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import SwiftUI

@main
struct wurstfingerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let screenshotMode: ScreenshotMode

    private enum ScreenshotMode {
        case none
        case keyboardOnly // SCREENSHOT_MODE - keyboard showcase only
        case appStore // APPSTORE_SCREENSHOT_MODE - keyboard with chat UI
    }

    init() {
        // Migrate a legacy keyboardScale into keyboardWidthPoints BEFORE
        // registering defaults: a registered width would make the key appear
        // present and mask a pending migration.
        LayoutSettings.migrateLegacyScaleIfNeeded(in: SharedDefaults.store)

        let defaults: [String: Any] = [
            SettingsKey.keyAspectRatio.rawValue: DeviceLayoutUtils.defaultKeyAspectRatio,
            SettingsKey.keyboardWidthPoints.rawValue: DeviceLayoutUtils.defaultKeyboardWidth,
            SettingsKey.keyboardHorizontalPosition.rawValue: DeviceLayoutUtils.defaultKeyboardPosition
        ]
        SharedDefaults.store.register(defaults: defaults)
        ThemeStore.migrateIfNeeded()

        // Determine screenshot mode from launch arguments
        let args = ProcessInfo.processInfo.arguments
        if args.contains("APPSTORE_SCREENSHOT_MODE") {
            screenshotMode = .appStore
        } else if args.contains("SCREENSHOT_MODE") {
            screenshotMode = .keyboardOnly
        } else {
            screenshotMode = .none
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch screenshotMode {
                case .appStore:
                    AppStoreScreenshotView()
                case .keyboardOnly:
                    KeyboardShowcaseView()
                case .none:
                    ContentView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // The keyboard extension writes the language selection while
                // the app is backgrounded (globe-key cycling). Refresh the
                // shared singleton on foreground so the settings UI never acts
                // on stale state.
                if newPhase == .active {
                    LanguageSettings.shared.reloadFromStore()
                }
            }
        }
    }
}
