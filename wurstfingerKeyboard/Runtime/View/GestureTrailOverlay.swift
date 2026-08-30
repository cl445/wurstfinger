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
///
/// ## Why this is a `Shape` and not a `Canvas`
///
/// It was a `Canvas`, which is the obvious tool for immediate-mode drawing and
/// the wrong one here. `Canvas` exists to draw *many* elements without paying
/// for a view each; this draws exactly one filled contour. What it cost
/// instead, measured on device across three independent keyboard appearances:
/// **+27 to +31 MB, one frame after the first rendered trail**, released again
/// only when the SwiftUI graph is torn down — so every single appearance paid
/// it anew. In an extension with a ~177 MB per-process jetsam limit that is
/// most of the budget, and it is what made the keyboard silently stop
/// appearing after a while. The trail also drew unreliably, which is the same
/// story from the other side: near the limit the allocation cannot be
/// satisfied and the trail stays blank.
///
/// A `Shape` never touches that rendering path. `GestureTrailGeometry` already
/// returns a `Path`, so the change is only in who fills it.
struct GestureTrailOverlay: View {
    @ObservedObject var recorder: GestureTrailRecorder

    /// Width of the ribbon at the finger, scaled from the rendered key size by
    /// `headWidth(for:)`.
    let headWidth: CGFloat

    /// The active theme's `gestureTrail` color.
    let trailColor: Color

    var body: some View {
        // Nothing is rendered — and no display-linked timer runs — unless a
        // trail is in flight.
        if recorder.isVisible {
            // Capped rather than free-running: `.animation` alone redraws at
            // the display's rate, which is 120 Hz on this hardware, and the
            // trail is a soft shape whose motion nobody can read at that rate.
            // Half of it looks identical and halves the work per gesture.
            TimelineView(.animation(minimumInterval: KeyboardConstants.GestureTrail.minimumFrameInterval)) { timeline in
                frame(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .allowsHitTesting(false)
            // Purely decorative: it echoes a gesture the user is making right
            // now, so it has nothing to announce and must not sit between
            // VoiceOver and the keys underneath.
            .accessibilityHidden(true)
        }
    }

    /// One rendered frame of the trail.
    ///
    /// Deliberately not a `@ViewBuilder`: the sample selection is ordinary code
    /// that wants statements, and an empty point list already renders as an
    /// empty path, so there is nothing for a conditional branch to do.
    private func frame(at now: TimeInterval) -> some View {
        let trail = recorder.trail
        // The recorder drops a faded-out trail from a main-queue work item, so
        // a busy main thread can hand this a trail whose fade already expired.
        // Those frames would build the full ribbon only to fill it at zero
        // opacity; skip the geometry instead.
        let points = trail.isFinished(at: now) ? [] : trail.visiblePoints(at: now)
        // One fill of one closed contour, so the alpha is uniform even where
        // the path crosses itself.
        return GestureTrailShape(points: points, headWidth: headWidth)
            .fill(Self.fillColor(trailColor, fade: trail.fadeOpacity(at: now)))
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
    /// the fade-out. Kept as a static seam so the fade stays unit-testable
    /// without rendering anything.
    static func fillColor(_ base: Color, fade: Double) -> Color {
        base.opacity(fade)
    }
}

/// The trail's ribbon as a plain `Shape`.
///
/// Holds no drawing logic of its own — `GestureTrailGeometry.shape(through:
/// headWidth:)` is the single source of the contour, shared with the geometry
/// tests. This type exists purely to hand that `Path` to SwiftUI's retained
/// renderer instead of to a `Canvas` (see `GestureTrailOverlay`).
struct GestureTrailShape: Shape {
    let points: [CGPoint]
    let headWidth: CGFloat

    func path(in _: CGRect) -> Path {
        GestureTrailGeometry.shape(through: points, headWidth: headWidth)
    }
}
