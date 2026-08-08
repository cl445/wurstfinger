//
//  GestureTrailOverlay.swift
//  Wurstfinger
//
//  Draws the optional swipe trail on top of the key grid.
//

import SwiftUI

/// Renders the swipe trail recorded by `GestureTrailRecorder`.
///
/// Sits in an `.overlay` on the grid layout, which is also where the recorder's
/// coordinate space is registered — so the recorded points map onto this view's
/// bounds one to one, with no padding or offset correction.
struct GestureTrailOverlay: View {
    @ObservedObject var recorder: GestureTrailRecorder

    /// Width of the ribbon at the finger, scaled from the rendered key size by
    /// `headWidth(for:)`.
    let headWidth: CGFloat

    var body: some View {
        // Nothing is rendered — and no display-linked timer runs — unless a
        // trail is actually in flight. `isVisible` is the recorder's only
        // published property for exactly this reason.
        if recorder.isVisible {
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    draw(in: &context, at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Head width for a rendered key size, clamped so the trail stays
    /// proportionate on both a compact one-handed keyboard and a full-width
    /// iPad layout.
    static func headWidth(for metrics: KeyboardLayoutMetrics) -> CGFloat {
        let scaled = metrics.rowHeight * KeyboardConstants.GestureTrail.widthFraction
        return min(
            max(scaled, KeyboardConstants.GestureTrail.minWidth),
            KeyboardConstants.GestureTrail.maxWidth
        )
    }

    private func draw(in context: inout GraphicsContext, at now: TimeInterval) {
        let trail = recorder.trail
        let points = trail.visiblePoints(at: now)
        guard points.count >= 2 else { return }

        let path = GestureTrailGeometry.ribbon(
            through: GestureTrailGeometry.smoothed(points),
            headWidth: headWidth
        )
        // One fill of one closed contour, so the alpha is uniform even where
        // the path crosses itself — see GestureTrailGeometry.
        context.opacity = KeyboardConstants.GestureTrail.opacity * trail.fadeOpacity(at: now)
        context.fill(path, with: .color(.primary))
    }
}
