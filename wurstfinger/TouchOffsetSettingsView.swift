//
//  TouchOffsetSettingsView.swift
//  wurstfinger
//
//  Settings subpage for the learned touch-offset correction (spec §6):
//  the master toggle, a visualization of the learned per-key offsets read from
//  the persisted snapshot, a regime selector, and reset controls. All data is
//  local; the visualization shows the last persisted snapshot (§5.1).
//

import CoreGraphics
import SwiftUI

struct TouchOffsetSettingsView: View {
    @AppStorage(SettingsKey.touchOffsetEnabled.rawValue, store: SharedDefaults.store)
    private var enabled = false

    @State private var posture: PostureClass = .twoThumb
    @State private var snapshot: TouchOffsetSnapshot = .empty(schemaVersion: TouchOffsetStore.currentSchemaVersion)
    @State private var showResetDialog = false

    private let store = TouchOffsetStore(defaults: SharedDefaults.store)
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
                Picker("Hand posture", selection: $posture) {
                    Text("Two thumbs").tag(PostureClass.twoThumb)
                    Text("Left hand").tag(PostureClass.oneThumbLeft)
                    Text("Right hand").tag(PostureClass.oneThumbRight)
                }
                .pickerStyle(.segmented)

                OffsetMapView(arrangement: arrangement, offsets: appliedOffsets, sampleCount: sampleCount)
                    .frame(height: 230)
                    .padding(.vertical, 4)
            } header: {
                Text("Learned adjustments")
            } footer: {
                Text(totalSamples > 0
                    ? "\(totalSamples) taps learned for this posture. The red arrow shows how far "
                    + "each key's target has moved; fainter means less data."
                    : "No data yet for this posture — type with the keyboard to teach it.")
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
