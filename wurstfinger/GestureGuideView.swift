//
//  GestureGuideView.swift
//  wurstfinger
//
//  A compact cheat sheet for every gesture the keyboard understands.
//  Content mirrors the actual bindings in `CommonKeys` and the gesture
//  runtime — keep it in sync when gestures change.
//

import SwiftUI

struct GestureGuideView: View {
    var body: some View {
        List {
            Section {
                GestureGuideRow(
                    icon: "hand.tap",
                    color: .blue,
                    title: "Tap",
                    description: String(localized: "Types the large character in the center of a key.")
                )

                GestureGuideRow(
                    icon: "arrow.up.right",
                    color: .blue,
                    title: "Swipe",
                    description: String(localized: "Types the small character shown in that direction on the key.")
                )

                GestureGuideRow(
                    icon: "arrow.uturn.backward",
                    color: .blue,
                    title: "Return Swipe",
                    description: String(localized: "Swipe away and back without lifting your finger to get the key's alternate character.")
                )

                GestureGuideRow(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    color: .blue,
                    title: "Circle",
                    description: String(localized: "Draw a small circle on a letter key to type it as an uppercase letter.")
                )
            } header: {
                Text("Letters & Symbols")
            }

            Section {
                GestureGuideRow(
                    icon: "arrow.left.and.right",
                    color: .green,
                    title: "Space Drag",
                    description: String(localized: "Hold and drag the space key to move the cursor through your text.")
                )

                GestureGuideRow(
                    icon: "delete.left",
                    color: .green,
                    title: "Delete Drag",
                    description: String(localized: "Hold and drag the delete key to keep deleting — the further you drag, the more it removes.")
                )

                GestureGuideRow(
                    icon: "doc.on.clipboard",
                    color: .green,
                    title: "Clipboard",
                    description: String(localized: "On the 123 key: swipe up to copy, up-right to cut, down to paste.")
                )
            } header: {
                Text("Editing")
            }

            Section {
                GestureGuideRow(
                    icon: "globe",
                    color: .purple,
                    title: "Globe Key",
                    description: String(
                        // swiftlint:disable:next line_length
                        localized: "Swipe left to switch to the next system keyboard, swipe right to change the language, swipe down to hide the keyboard."
                    )
                )
            } header: {
                Text("Switching")
            } footer: {
                Text("Try all gestures safely in the Test tab or the settings preview.")
            }
        }
        .navigationTitle("Gestures")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GestureGuideRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        GestureGuideView()
    }
}
