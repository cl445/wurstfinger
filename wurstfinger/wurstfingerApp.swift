//
//  wurstfingerApp.swift
//  wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import SwiftUI

@main
struct wurstfingerApp: App {
    private let screenshotMode: ScreenshotMode

    private enum ScreenshotMode {
        case none
        case keyboardOnly      // SCREENSHOT_MODE - keyboard showcase only
        case appStore          // APPSTORE_SCREENSHOT_MODE - keyboard with chat UI
    }

    init() {
        let defaults: [String: Any] = [
            "keyAspectRatio": DeviceLayoutUtils.defaultKeyAspectRatio,
            "keyboardScale": DeviceLayoutUtils.defaultKeyboardScale,
            "keyboardHorizontalPosition": DeviceLayoutUtils.defaultKeyboardPosition
        ]
        SharedDefaults.store.register(defaults: defaults)

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
            switch screenshotMode {
            case .appStore:
                AppStoreScreenshotView()
            case .keyboardOnly:
                KeyboardShowcaseView()
            case .none:
                ContentView()
            }
        }
    }
}
