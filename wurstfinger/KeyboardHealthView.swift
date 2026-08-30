//
//  KeyboardHealthView.swift
//  wurstfinger
//
//  Renders the keyboard extension's health log (see KeyboardHealthLog) so
//  memory headroom and launch activity can be inspected on-device, without
//  a Mac attached.
//
//  English only, like the rest of the Expert section — see docs/localization.md.
//

import SwiftUI

struct KeyboardHealthView: View {
    @State private var entries: [KeyboardHealthLog.Entry] = []

    /// Everything the keyboard process itself recorded — the log minus the
    /// tombstone `KeyboardHealthLog.clear()` leaves behind. That tombstone
    /// exists to date the entries around it, not to be one: it carries no
    /// footprint and describes no keyboard cycle, so the empty state, the
    /// event count and the peak all ignore it and a freshly cleared log still
    /// reads as empty. The rows below do show it — that is where it earns its
    /// keep.
    private var recordedEntries: [KeyboardHealthLog.Entry] {
        entries.filter { $0.label != KeyboardHealthLog.clearedLabel }
    }

    /// Two different lists, deliberately: the empty state and the summary
    /// key off `recordedEntries`, the rows off `entries`. A log holding
    /// nothing but the tombstone is therefore *empty* here — the clear did
    /// take, and saying otherwise would undo what the tombstone is for. The
    /// tombstone becomes visible at the moment it explains something: once a
    /// sample queued before the clear lands behind it, the rows show both.
    var body: some View {
        List {
            if recordedEntries.isEmpty {
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
            if !recordedEntries.isEmpty {
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

    /// Counts and peak over the keyboard's own events only. The tombstone
    /// carries no footprint, so including it would report an event that never
    /// happened and a 0 MB peak.
    private var summarySection: some View {
        Section {
            LabeledContent("Events", value: "\(recordedEntries.count)")
            if let peak = recordedEntries.max(by: { $0.usedMB < $1.usedMB }) {
                LabeledContent("Peak memory", value: memoryText(for: peak))
            }
            if let last = recordedEntries.last {
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

    /// The rows, newest first — over `entries`, so the tombstone appears
    /// among them and dates the entries on either side of it.
    private var entriesSection: some View {
        Section {
            // The legend sits above the rows, not in the section footer: the
            // log holds up to 300 entries, and guidance printed below all of
            // them is guidance nobody reaches. Collapsed it costs one line.
            DisclosureGroup("How to read a cycle") {
                Text(Self.cycleLegend)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ForEach(entries.reversed()) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.label)
                            .font(.callout.monospaced())
                        Spacer()
                        // The tombstone has no memory column: it was stamped
                        // by this app, not by the keyboard process.
                        if entry.label != KeyboardHealthLog.clearedLabel {
                            Text(memoryText(for: entry))
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundColor(memoryColor(for: entry))
                        }
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Events (newest first)")
        }
    }

    // MARK: - Helpers

    /// What a reader needs to know before drawing conclusions from a cycle.
    /// Every claim here is one the code or a measurement backs; where a
    /// question is open (host-lifecycle entries on real hardware, see
    /// `KeyboardViewController.observeHostLifecycle`) it says so rather than
    /// inviting an inference from silence.
    private static let cycleLegend = """
    viewDidDisappear is measured while the freed memory is still being \
    reclaimed and reads a little high. A postShedSettled entry about two \
    seconds later is the honest figure for what the keyboard carries into \
    suspension — but it is deliberately dropped when the keyboard comes back \
    before it fires, or when the process was frozen and the sample would only \
    have been taken long after the fact. A cycle without one is normal.

    A viewDidAppear followed straight by a fresh viewDidLoad.start means the \
    host app was killed while the keyboard was up — iOS reports nothing back \
    on that path, so no cleanup ran.

    hostDidEnterBackground and hostWillEnterForeground did not appear in any \
    measured cycle on the iOS 26 Simulator; whether a real device delivers \
    them at all is unverified. Their absence says nothing either way.

    logCleared is not a keyboard event: it marks where this screen wiped the \
    log. An entry shown above it — a postShedSettled, typically — is a sample \
    that a dismissal had already queued inside the keyboard process finally \
    landing, not a clear that failed. Clearing runs here and cannot reach \
    across into that process.
    """

    private func reload() {
        entries = KeyboardHealthLog.shared.entries()
    }

    /// "used / available" in MB; available is omitted when the API returned 0.
    private func memoryText(for entry: KeyboardHealthLog.Entry) -> String {
        let used = String(format: "%.1f MB", entry.usedMB)
        guard entry.availableMB > 0 else { return used }
        return used + String(format: " / %.1f free", entry.availableMB)
    }

    /// Headroom below which an entry is flagged as jetsam-critical.
    private static let criticalHeadroomMB: Double = 5
    /// Headroom below which an entry is flagged as jetsam-near.
    private static let warningHeadroomMB: Double = 15

    /// Flags entries that were close to the jetsam limit when recorded.
    private func memoryColor(for entry: KeyboardHealthLog.Entry) -> Color {
        guard entry.availableMB > 0 else { return .primary }
        switch entry.availableMB {
        case ..<Self.criticalHeadroomMB: return .red
        case ..<Self.warningHeadroomMB: return .orange
        default: return .primary
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardHealthView()
    }
}
