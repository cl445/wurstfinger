//
//  HomeView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct HomeView: View {
    private let githubURL = URL(string: "https://github.com/cl445/wurstfinger")!
    private let issuesURL = URL(string: "https://github.com/cl445/wurstfinger/issues")!

    @AppStorage("onboarding.keyboardInstalled", store: SharedDefaults.store)
    private var keyboardInstalled = false

    /// Refresh trigger so the setup state is re-evaluated when the app
    /// returns to the foreground (e.g. after enabling the keyboard in iOS
    /// Settings and coming back).
    @Environment(\.scenePhase) private var scenePhase
    @State private var setupRefreshTrigger = false

    /// The keyboard extension syncs its Full Access status the first time it
    /// runs, so a synced value proves the keyboard has been enabled and used.
    /// Combined with the manual onboarding checkbox this decides whether the
    /// setup call-to-action still needs to be front and center.
    private var isSetUp: Bool {
        _ = setupRefreshTrigger
        return keyboardInstalled
            || SharedDefaults.store.object(forKey: SettingsKey.keyboardFullAccess.rawValue) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo/Icon
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)

                // Title
                Text("Wurstfinger")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Tagline
                Text("The Keyboard for Fat Fingers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Quick Actions
                VStack(spacing: 12) {
                    if isSetUp {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Keyboard is set up")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            NavigationLink(destination: OnboardingContentView()) {
                                Text("Setup")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        NavigationLink(destination: GestureGuideView()) {
                            HStack {
                                Image(systemName: "hand.draw")
                                Text("Learn the Gestures")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    } else {
                        NavigationLink(destination: OnboardingContentView()) {
                            HStack {
                                Image(systemName: "list.number")
                                Text("Set Up the Keyboard")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        NavigationLink(destination: GestureGuideView()) {
                            HStack {
                                Image(systemName: "hand.draw")
                                Text("Learn the Gestures")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 12) {
                        Link(destination: githubURL) {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("GitHub")
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        Link(destination: issuesURL) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble")
                                Text("Issues")
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Wurstfinger")
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    setupRefreshTrigger.toggle()
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
