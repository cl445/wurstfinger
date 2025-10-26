//
//  ContentView.swift
//  wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            OnboardingView()
                .tabItem {
                    Label("Setup", systemImage: "list.number")
                }

            TestAreaView()
                .tabItem {
                    Label("Test", systemImage: "keyboard")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
