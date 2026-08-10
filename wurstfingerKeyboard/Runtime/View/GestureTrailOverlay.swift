//
//  GestureTrailOverlay.swift
//  Wurstfinger
//
//  Draws the optional gesture trail on top of the key grid: a dot under a
//  press, a tapered ribbon under a swipe.
//

import SwiftUI

/// Renders the trail recorded by `GestureTrailRecorder`.
///
/// Sits in an `.overlay` on the grid layout, which is also where the recorder's
/// coordinate space is registered — so the recorded points map onto this view's
/// bounds one to one, with no padding or offset correction.
struct GestureTrailOverlay: View {
    @ObservedObject var recorder: GestureTrailRecorder

    /// Width of the ribbon at the finger, scaled from the rendered key size by
    /// `headWidth(for:)`.
    let headWidth: CGFloat

    /// The active theme's `gestureTrail` color, passed in rather than read
    /// from `@Environment` here: `TimelineView` calls the `Canvas` renderer
    /// once per frame *without* re-evaluating `body`, so a property-wrapper
    /// access from that escaping closure is the "Accessing Environment outside
    /// of being installed on a View" trap — and a stale value would stay wrong
    /// for the whole gesture.
    let trailColor: Color

    var body: some View {
        // Nothing is rendered — and no display-linked timer runs — unless a
        // trail is in flight.
        if recorder.isVisible {
            // Captured as a plain value here, outside the per-frame closure.
            let color = trailColor
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    draw(in: &context, at: timeline.date.timeIntervalSinceReferenceDate, color: color)
                }
            }
            .allowsHitTesting(false)
            // Purely decorative: it echoes a gesture the user is making right
            // now, so it has nothing to announce and must not sit between
            // VoiceOver and the keys underneath.
            .accessibilityHidden(true)
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

    /// The color one frame fills with: the theme's own alpha, dimmed only by
    /// the fade-out. Separate from `draw` because a `GraphicsContext` cannot be
    /// built outside a `Canvas`, so this is the only testable seam.
    static func fillColor(_ base: Color, fade: Double) -> Color {
        base.opacity(fade)
    }

    private func draw(in context: inout GraphicsContext, at now: TimeInterval, color: Color) {
        let trail = recorder.trail
        // The recorder drops a faded-out trail from a main-queue work item, so
        // a busy main thread can hand this a trail whose fade already expired.
        // Those frames would build the full ribbon only to fill it at zero
        // opacity; bail before the geometry instead.
        guard !trail.isFinished(at: now) else { return }
        let points = trail.visiblePoints(at: now)
        guard !points.isEmpty else { return }

        let path = GestureTrailGeometry.shape(through: points, headWidth: headWidth)
        // One fill of one closed contour, so the alpha is uniform even where
        // the path crosses itself.
        context.fill(path, with: .color(Self.fillColor(color, fade: trail.fadeOpacity(at: now))))
    }
}
