//
//  TestAreaView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct TestAreaView: View {
    @State private var testText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // How to switch keyboard
                VStack(alignment: .leading, spacing: 12) {
                    Label("Switch Keyboard", systemImage: "info.circle")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)

                        Text("Tap the globe icon on your keyboard to switch between installed keyboards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                // Test Text Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Field")
                        .font(.headline)
                        .padding(.horizontal)

                    TextEditor(text: $testText)
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 200)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor, lineWidth: isTextFieldFocused ? 2 : 0)
                        )
                        .overlay(
                            Group {
                                if testText.isEmpty && !isTextFieldFocused {
                                    Text("Tap here to open keyboard...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                        .padding(.horizontal)
                }

                // Quick Actions
                Button(action: { testText = "" }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
                        isTextFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }
}

#Preview {
    TestAreaView()
}
