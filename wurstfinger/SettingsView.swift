//
//  SettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("utilityColumnLeading", store: UserDefaults(suiteName: "group.com.wurstfinger.shared"))
    private var utilityColumnLeading = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(isOn: $utilityColumnLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Utility Keys on Left")
                                .font(.body)

                            Text("Places globe, symbols, delete and return on the left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Changes position of utility column with globe, symbols, delete and return keys.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Layout")
                        Spacer()
                        Text("German (MessagEase)")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/cl445/wurstfinger/blob/main/LICENSE")!) {
                        HStack {
                            Text("License")
                            Spacer()
                            Text("MIT")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: ImprintView()) {
                        Text("Imprint")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
