//
//  HomeView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
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

                // Development Notice
                VStack(spacing: 8) {
                    Label("Work in Progress", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("This keyboard is in early development. Contributions welcome!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Quick Actions
                VStack(spacing: 12) {
                    NavigationLink(destination: OnboardingView()) {
                        HStack {
                            Image(systemName: "list.number")
                            Text("Setup Instructions")
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

                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/cl445/wurstfinger")!) {
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

                        Link(destination: URL(string: "https://github.com/cl445/wurstfinger/issues")!) {
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeView()
}
