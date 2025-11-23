//
//  wurstfingerApp.swift
//  wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import SwiftUI

@main
struct wurstfingerApp: App {
    @State private var showScreenshotMode = ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")

    init() {
        let defaults: [String: Any] = [
            "keyAspectRatio": DeviceLayoutUtils.defaultKeyAspectRatio,
            "keyboardScale": DeviceLayoutUtils.defaultKeyboardScale,
            "keyboardHorizontalPosition": DeviceLayoutUtils.defaultKeyboardPosition
        ]
        SharedDefaults.store.register(defaults: defaults)
    }

    var body: some Scene {
        WindowGroup {
            if showScreenshotMode {
                KeyboardShowcaseView()
            } else {
                ContentView()
            }
        }
    }
}
