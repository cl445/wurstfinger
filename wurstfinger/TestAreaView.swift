//
//  TestAreaView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

/// Visualizes the gesture path
struct GesturePathView: View {
    let path: [CGPoint]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let scale: CGFloat = 1.0 // 1 point = 1 pixel

            ZStack {
                // Grid lines
                Path { p in
                    p.move(to: CGPoint(x: center.x, y: 0))
                    p.addLine(to: CGPoint(x: center.x, y: geo.size.height))
                    p.move(to: CGPoint(x: 0, y: center.y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: center.y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                // Path
                if path.count >= 2 {
                    Path { p in
                        let first = path[0]
                        p.move(to: CGPoint(x: center.x + first.x * scale, y: center.y + first.y * scale))
                        for point in path.dropFirst() {
                            p.addLine(to: CGPoint(x: center.x + point.x * scale, y: center.y + point.y * scale))
                        }
                    }
                    .stroke(Color.accentColor, lineWidth: 2)

                    // Start point (green)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .position(x: center.x + path[0].x * scale, y: center.y + path[0].y * scale)

                    // End point (red)
                    if let last = path.last {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: center.x + last.x * scale, y: center.y + last.y * scale)
                    }

                    // Peak point (orange) - point with max magnitude
                    if let peak = path.max(by: { sqrt($0.x*$0.x + $0.y*$0.y) < sqrt($1.x*$1.x + $1.y*$1.y) }) {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .position(x: center.x + peak.x * scale, y: center.y + peak.y * scale)
                    }
                }

                // Direction labels
                Text("↑").position(x: center.x, y: 10).foregroundColor(.secondary).font(.caption)
                Text("↓").position(x: center.x, y: geo.size.height - 10).foregroundColor(.secondary).font(.caption)
                Text("←").position(x: 10, y: center.y).foregroundColor(.secondary).font(.caption)
                Text("→").position(x: geo.size.width - 10, y: center.y).foregroundColor(.secondary).font(.caption)
            }
        }
    }
}

struct TestAreaView: View {
    @State private var testText: String = ""
    @State private var gestureLogs: [String] = []
    @State private var gesturePath: [CGPoint] = []
    @State private var showGestureLog: Bool = false
    @State private var containerStatus: String = ""
    @FocusState private var isTextFieldFocused: Bool

    let logRefreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private func writeTestLog() {
        // Test if we can write to the shared container
        let suiteName = "group.de.akator.wurstfinger.shared"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let testURL = containerURL.appendingPathComponent("gesture_log.txt")
            containerStatus = "Container: \(containerURL.path)\n"

            // Try to write
            let testEntry = "[\(Date())] TEST from App\n"
            do {
                if FileManager.default.fileExists(atPath: testURL.path) {
                    let handle = try FileHandle(forWritingTo: testURL)
                    handle.seekToEndOfFile()
                    if let data = testEntry.data(using: .utf8) {
                        handle.write(data)
                    }
                    handle.closeFile()
                    containerStatus += "Appended to existing file ✓"
                } else {
                    try testEntry.write(to: testURL, atomically: true, encoding: .utf8)
                    containerStatus += "Created new file ✓"
                }
            } catch {
                containerStatus += "Write error: \(error.localizedDescription)"
            }
        } else {
            containerStatus = "ERROR: Container URL is nil!"
        }

        // Refresh logs
        gestureLogs = GestureDebugLog.getAll()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
                            .frame(minHeight: 150)
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
                    HStack(spacing: 12) {
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

                        Button(action: { showGestureLog.toggle() }) {
                            HStack {
                                Image(systemName: showGestureLog ? "eye.slash" : "eye")
                                Text("Log")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(showGestureLog ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(showGestureLog ? .white : .primary)
                            .cornerRadius(12)
                        }

                        Button(action: { writeTestLog() }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Test")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Container Status (for debugging)
                    if !containerStatus.isEmpty {
                        Text(containerStatus)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    // Gesture Debug Log
                    if showGestureLog {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Gesture Log")
                                    .font(.headline)
                                Spacer()
                                Button("Clear") {
                                    GestureDebugLog.clear()
                                    gestureLogs = []
                                    gesturePath = []
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal)

                            // Path Visualization
                            GesturePathView(path: gesturePath)
                                .frame(height: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)

                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(gestureLogs.reversed(), id: \.self) { log in
                                        Text(log)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(height: 120)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        .onReceive(logRefreshTimer) { _ in
                            gestureLogs = GestureDebugLog.getAll()
                            gesturePath = GestureDebugLog.getPath()
                        }
                        .onAppear {
                            gestureLogs = GestureDebugLog.getAll()
                            gesturePath = GestureDebugLog.getPath()
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
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
