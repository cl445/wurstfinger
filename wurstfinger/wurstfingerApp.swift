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
