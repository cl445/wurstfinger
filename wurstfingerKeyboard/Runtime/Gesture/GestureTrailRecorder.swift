//
//  GestureTrailRecorder.swift
//  Wurstfinger
//
//  Collects touch positions for the swipe trail and tells the overlay when
//  there is something to draw.
//

import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// Identity of one gesture modifier, used to decide which touch sequence owns
/// the shared trail. Each recognizer holds its own in `@State`, so it is stable
/// for as long as that key exists.
final class GestureTrailToken {}

/// Per-keyboard collector for the swipe trail.
///
/// Owned by `KeyboardGridView`, fed by the gesture modifiers with positions in
/// the shared `coordinateSpace`, and read by `GestureTrailOverlay`.
///
/// It publishes only `isVisible`, which flips at most twice per gesture. The
/// sample buffer itself is a plain property that the overlay re-reads every
/// frame from its `TimelineView`. Publishing per sample would invalidate every
/// observer at the drag sample rate — up to 120 Hz — and the grid owns this
/// object, so that would re-render all ~40 keys per sample.
final class GestureTrailRecorder: ObservableObject {
    /// The coordinate space every recorded point is expressed in. Registered
    /// by `KeyboardGridView` on the grid layout, which is both an ancestor of
    /// every `KeyView` and the exact bounds the overlay draws in, so recorded
    /// points need no offset correction to be drawn.
    static let coordinateSpace = NamedCoordinateSpace.named("wurstfinger.gestureTrail")

    /// Whether the overlay should be rendering. False for taps (below the
    /// activation distance), while the setting is off, and once the fade-out
    /// has finished.
    @Published private(set) var isVisible = false

    /// The trail to draw. Unpublished, so drag samples cannot invalidate the
    /// grid; the overlay re-reads it each frame.
    private(set) var trail = GestureTrail()

    private let defaults: UserDefaults
    private let now: () -> TimeInterval

    /// Whether the setting was on when the current touch went down. Sampled
    /// once per gesture so a toggle flipped mid-swipe cannot leave a
    /// half-recorded trail behind.
    private var isRecording = false

    /// The gesture modifier whose touch sequence currently owns the trail.
    ///
    /// One recorder is shared by every key, and on a thumb keyboard two touch
    /// sequences overlap routinely. Without an owner the second thumb's touch
    /// down would restart the stroke and its release would freeze it, so the
    /// trail would jump between the fingers and vanish under the one still
    /// moving. Weak, so a key torn down mid-gesture releases the trail rather
    /// than blocking it forever.
    private weak var owner: GestureTrailToken?

    private var fadeOut: DispatchWorkItem?

    init(
        defaults: UserDefaults = SharedDefaults.store,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.defaults = defaults
        self.now = now
    }

    /// Records one drag sample. `isTouchDown` marks the first sample of a new
    /// touch sequence, as reported by the gesture state machines; `token`
    /// identifies the recognizer it came from.
    func record(_ location: CGPoint, isTouchDown: Bool, from token: GestureTrailToken) {
        if isTouchDown {
            // First finger down wins the trail and keeps it until its sequence
            // ends. A concurrent second touch is ignored rather than drawn as
            // a second trail: one stroke matches the system keyboard, and the
            // overlay renders a single path.
            guard owner == nil else { return }
            owner = token
            beginTouch(at: location)
            return
        }
        guard owner === token, isRecording else { return }
        trail.extend(to: location, time: now())
        // Suppress taps: every keystroke on this keyboard begins as a touch
        // down, so drawing from the first sample would flash a dot under every
        // letter typed.
        if !isVisible, trail.maxDisplacement >= KeyboardConstants.GestureTrail.activationDistance {
            setVisible(true)
        }
    }

    /// Ends the current touch. A trail that became visible freezes and fades
    /// out; one that stayed below the activation distance is dropped silently.
    func finish(from token: GestureTrailToken) {
        guard owner === token else { return }
        // Released before the `isRecording` check so a touch taken while the
        // setting was off still hands the trail back to the next gesture.
        owner = nil
        guard isRecording else { return }
        isRecording = false
        guard isVisible else {
            trail.clear()
            return
        }
        trail.release(at: now())
        scheduleFadeOut()
    }

    /// Discards the trail immediately, without a fade. Used for the paths that
    /// end a touch without a gesture: a system cancellation, a long press that
    /// consumed the touch, and the teardown of a key that was mid-gesture
    /// (which reaches neither `onEnded` nor the cancel path).
    func cancel(from token: GestureTrailToken) {
        // Also gates the recognizers' unconditional cancel paths: a key whose
        // gesture never started is not the owner and must not clear a trail
        // another key is drawing.
        guard owner === token else { return }
        owner = nil
        isRecording = false
        fadeOut?.cancel()
        fadeOut = nil
        trail.clear()
        setVisible(false)
    }

    // MARK: - Private

    private func beginTouch(at location: CGPoint) {
        fadeOut?.cancel()
        fadeOut = nil
        trail.clear()
        setVisible(false)
        // Read the setting per touch rather than observing the store: the host
        // app can flip the toggle while the extension is alive, and one
        // dictionary lookup per gesture is far cheaper than the re-render an
        // observed value would cost on every key.
        isRecording = defaults.bool(forKey: SettingsKey.gestureTrailEnabled.rawValue)
        guard isRecording else { return }
        trail.begin(at: location, time: now())
    }

    private func scheduleFadeOut() {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            fadeOut = nil
            trail.clear()
            setVisible(false)
        }
        fadeOut = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + KeyboardConstants.GestureTrail.fadeOutDuration,
            execute: item
        )
    }

    /// Publishes only on an actual transition: the recorder is observed by the
    /// overlay, so a redundant publish per drag sample would invalidate it at
    /// the drag sample rate.
    private func setVisible(_ value: Bool) {
        guard isVisible != value else { return }
        isVisible = value
    }
}
