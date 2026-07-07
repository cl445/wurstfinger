//
//  KeyboardHealthView.swift
//  wurstfinger
//
//  Renders the keyboard extension's health log (see KeyboardHealthLog) so
//  memory headroom and launch activity can be inspected on-device, without
//  a Mac attached.
//

import SwiftUI

struct KeyboardHealthView: View {
    @State private var entries: [KeyboardHealthLog.Entry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                emptySection
            } else {
                summarySection
                entriesSection
            }
        }
        .navigationTitle("Keyboard Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .refreshable { reload() }
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        KeyboardHealthLog.shared.clear()
                        reload()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var emptySection: some View {
        Section {
            Text("No events recorded yet. Open the keyboard once, then pull to refresh.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Events", value: "\(entries.count)")
            if let peak = entries.max(by: { $0.usedMB < $1.usedMB }) {
                LabeledContent("Peak memory", value: memoryText(for: peak))
            }
            if let last = entries.last {
                LabeledContent("Last event", value: last.date.formatted(date: .abbreviated, time: .standard))
            }
        } header: {
            Text("Summary")
        } footer: {
            Text(
                // swiftlint:disable:next line_length
                "Every keyboard appearance records at least one entry. If the system keyboard showed instead of Wurstfinger and no entry exists for that moment, iOS did not launch the extension at all — typically due to system memory pressure."
            )
        }
    }

    private var entriesSection: some View {
        Section("Events (newest first)") {
            ForEach(entries.reversed()) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.label)
                            .font(.callout.monospaced())
                        Spacer()
                        Text(memoryText(for: entry))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundColor(memoryColor(for: entry))
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func reload() {
        entries = KeyboardHealthLog.shared.entries()
    }

    /// "used / available" in MB; available is omitted when the API returned 0.
    private func memoryText(for entry: KeyboardHealthLog.Entry) -> String {
        let used = String(format: "%.1f MB", entry.usedMB)
        guard entry.availableMB > 0 else { return used }
        return used + String(format: " / %.1f free", entry.availableMB)
    }

    /// Flags entries that were close to the jetsam limit when recorded.
    private func memoryColor(for entry: KeyboardHealthLog.Entry) -> Color {
        guard entry.availableMB > 0 else { return .primary }
        switch entry.availableMB {
        case ..<5: return .red
        case ..<15: return .orange
        default: return .primary
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardHealthView()
    }
}
