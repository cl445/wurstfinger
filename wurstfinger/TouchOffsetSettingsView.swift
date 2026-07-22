//
//  TouchOffsetSettingsView.swift
//  wurstfinger
//
//  Settings subpage for the learned touch-offset correction (spec §6):
//  the master toggle, a compact explicit hand-posture choice that selects the
//  active learning regime (§6.3), a visualization of the learned per-key offsets
//  read from the persisted snapshot, a link to the statistics subpage, and reset
//  controls. All data is local; the visualization shows the last persisted
//  snapshot (§5.1).
//

import CoreGraphics
import SwiftUI

struct TouchOffsetSettingsView: View {
    @AppStorage(SettingsKey.touchOffsetEnabled.rawValue, store: SharedDefaults.store)
    private var enabled = false

    /// The user's explicit hand posture — a real decision that selects the
    /// active learning regime, not just a view filter (§3.1/§6.3).
    @AppStorage(SettingsKey.touchOffsetPosture.rawValue, store: SharedDefaults.store)
    private var posture: PostureClass = .oneThumbRight
    @State private var snapshot: TouchOffsetSnapshot = .empty(schemaVersion: TouchOffsetStore.currentSchemaVersion)
    @State private var showResetDialog = false

    private let store = TouchOffsetStore(defaults: SharedDefaults.store)
    private let telemetryStore = GestureTelemetryStore(defaults: SharedDefaults.store)
    private let arrangement = StandardArrangements.grid3x3[.portrait]

    private var regime: TouchRegime {
        TouchRegime(orientation: .portrait, posture: posture)
    }

    private var regimeKeys: [String: KeyOffsetState] {
        snapshot.regimes[regime.key] ?? [:]
    }

    private var totalSamples: Int {
        regimeKeys.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Correct my typing", isOn: $enabled)
            } footer: {
                Text("Learns where you tend to tap each key and quietly adjusts the "
                    + "touch targets to match. Everything is learned **on this device** "
                    + "and never leaves it.")
            }

            Section {
                Picker("How do you type?", selection: $posture) {
                    Text("One hand — right thumb").tag(PostureClass.oneThumbRight)
                    Text("One hand — left thumb").tag(PostureClass.oneThumbLeft)
                    Text("Two thumbs").tag(PostureClass.twoThumb)
                }
            } footer: {
                Text("Wurstfinger keeps a **separate** profile per posture, because a thumb "
                    + "reaching across the keyboard lands differently than two thumbs. A wrong "
                    + "choice can nudge keys the wrong way, so this isn't auto-detected.")
            }

            Section {
                OffsetMapView(arrangement: arrangement, offsets: appliedOffsets, sampleCount: sampleCount)
                    .frame(height: 230)
                    .padding(.vertical, 4)
            } header: {
                Text("Learned adjustments")
            } footer: {
                Text(totalSamples > 0
                    ? "\(totalSamples) taps learned for this posture. The red arrow shows how far "
                    + "each key's target has moved; fainter means less data."
                    : "No data yet for this posture — type this way and the keyboard learns it.")
            }

            Section {
                NavigationLink("Statistics") {
                    TouchOffsetStatsView(regimeKey: regime.key)
                }
            } footer: {
                Text("See whether correction is helping and the per-gesture correction rates.")
            }

            Section {
                Button("Reset this posture", role: .destructive) {
                    store.reset(regimeKey: regime.key)
                    reload()
                }
                .disabled(totalSamples == 0)
                Button("Reset everything", role: .destructive) {
                    showResetDialog = true
                }
            }
        }
        .navigationTitle("Touch correction")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog("Reset all learned corrections?", isPresented: $showResetDialog, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                store.resetAll()
                telemetryStore.reset()
                reload()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var appliedOffsets: [String: CGVector] {
        TouchOffsetModel(regime: regime, snapshot: snapshot).allOffsets()
    }

    private func sampleCount(_ keyId: String) -> Int {
        regimeKeys[keyId]?.count ?? 0
    }

    private func reload() {
        snapshot = store.load()
    }
}

/// Read-only statistics subpage (§8/§13): the A/B proxy metric and the
/// per-gesture correction rates for the active posture. Loaded fresh from the
/// persisted telemetry snapshot on appear.
private struct TouchOffsetStatsView: View {
    let regimeKey: String

    @State private var telemetry: TelemetrySnapshot = .empty(schemaVersion: GestureTelemetryStore.currentSchemaVersion)
    private let telemetryStore = GestureTelemetryStore(defaults: SharedDefaults.store)

    private var counterfactual: CounterfactualMetric {
        telemetry.counterfactual[regimeKey] ?? CounterfactualMetric()
    }

    var body: some View {
        Form {
            Section {
                if counterfactual.taps == 0 {
                    Text("No taps recorded yet — keep typing with this posture.")
                        .foregroundStyle(.secondary)
                } else {
                    let helping = counterfactual.errorRateWith <= counterfactual.errorRateWithout
                    rateRow("With correction", counterfactual.errorRateWith, tint: helping ? .green : .red)
                    rateRow("Without correction", counterfactual.errorRateWithout, tint: .secondary)
                }
            } header: {
                Text("Error rate")
            } footer: {
                Text("Estimated backspace rate **with** the correction vs. what it would have "
                    + "been **without** it — inferred per tap from whether correction changed a "
                    + "key you then kept or deleted. Lower with correction means it's helping. "
                    + "(\(counterfactual.taps) taps · \(counterfactual.caught) caught · "
                    + "\(counterfactual.caused) caused)")
            }

            if let classes = telemetry.classes[regimeKey], !classes.isEmpty {
                Section {
                    ForEach(classes.keys.sorted(), id: \.self) { key in
                        if let stats = classes[key] {
                            LabeledContent(key) {
                                Text("\(percent(stats.correctionRate)) · \(stats.total)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    Text("Gesture correction rates")
                } footer: {
                    Text("How often each gesture class gets corrected (rate · sample count). "
                        + "A high rate hints at a mis-tuned threshold for that gesture.")
                }
            } else {
                Section {
                    Text("No gesture data yet for this posture.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { telemetry = telemetryStore.load() }
    }

    private func rateRow(_ title: LocalizedStringKey, _ rate: Double, tint: Color) -> some View {
        LabeledContent(title) {
            Text(percent(rate))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private func percent(_ rate: Double) -> String {
        String(format: "%.1f%%", rate * 100)
    }
}

/// Draws the keyboard grid with a red arrow per key from its true center to the
/// learned (shifted) point; opacity encodes confidence (sample count).
private struct OffsetMapView: View {
    let arrangement: GridArrangement?
    let offsets: [String: CGVector]
    let sampleCount: (String) -> Int

    var body: some View {
        Canvas { context, size in
            guard let arrangement else { return }
            let cells = GridLayoutSolver.solve(arrangement)
            let columns = CGFloat(max(arrangement.columns, 1))
            let rows = CGFloat(max(GridLayoutSolver.rowCount(arrangement), 1))
            let cellW = size.width / columns
            let cellH = size.height / rows

            for cell in cells {
                let rect = CGRect(
                    x: CGFloat(cell.column) * cellW,
                    y: CGFloat(cell.row) * cellH,
                    width: CGFloat(cell.columnSpan) * cellW,
                    height: CGFloat(cell.rowSpan) * cellH
                ).insetBy(dx: 2, dy: 2)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 5),
                    with: .color(.secondary.opacity(0.12))
                )

                let center = CGPoint(x: rect.midX, y: rect.midY)
                guard let offset = offsets[cell.keyId], offset.dx != 0 || offset.dy != 0 else { continue }
                let opacity = min(Double(sampleCount(cell.keyId)) / 20.0, 1.0)

                // True center crosshair.
                var cross = Path()
                cross.move(to: CGPoint(x: center.x - 3, y: center.y))
                cross.addLine(to: CGPoint(x: center.x + 3, y: center.y))
                cross.move(to: CGPoint(x: center.x, y: center.y - 3))
                cross.addLine(to: CGPoint(x: center.x, y: center.y + 3))
                context.stroke(cross, with: .color(.secondary.opacity(0.45)), lineWidth: 1)

                // Arrow to the learned point.
                let end = CGPoint(x: center.x + offset.dx * cellW, y: center.y + offset.dy * cellH)
                var line = Path()
                line.move(to: center)
                line.addLine(to: end)
                context.stroke(line, with: .color(.red.opacity(opacity)), lineWidth: 2)
                context.fill(
                    Path(ellipseIn: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)),
                    with: .color(.red.opacity(opacity))
                )
            }
        }
        .accessibilityLabel("Learned touch-offset map")
    }
}
