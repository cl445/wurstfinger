//
//  GestureTrailRecorder.swift
//  Wurstfinger
//
//  Collects touch positions for the gesture trail and tells the overlay when
//  there is something to draw.
//

import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// Identity of one gesture modifier, used to decide which touch sequence owns
/// the shared trail. Each recognizer holds its own in `@StateObject`, so it is
/// created once per key rather than on every body evaluation and is stable for
/// as long as that key exists. It publishes nothing; the conformance exists
/// only for `@StateObject`'s deferred construction.
final class GestureTrailToken: ObservableObject {}

/// Per-keyboard collector for the gesture trail.
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

    /// Whether the overlay should be rendering. True from the moment a touch
    /// goes down with the setting on — a press that never moves is drawn as
    /// the head of the trail standing still — and false while the setting is
    /// off or once the fade-out has finished.
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

    /// Starts recording a new touch sequence. `token` identifies the
    /// recognizer it came from.
    func begin(at location: CGPoint, from token: GestureTrailToken) {
        // First finger down wins the trail and keeps it until its sequence
        // ends. A concurrent second touch is ignored rather than drawn as
        // a second trail: one stroke matches the system keyboard, and the
        // overlay renders a single path.
        guard owner == nil else { return }
        owner = token
        beginTouch(at: location)
    }

    /// Records one drag sample of the sequence started by `begin`.
    func extend(to location: CGPoint, from token: GestureTrailToken) {
        guard owner === token, isRecording else { return }
        trail.extend(to: location, time: now())
    }

    /// Ends the current touch: the trail freezes where the finger left it and
    /// fades out. A tap freezes as its dot, which is the only feedback this
    /// keyboard gives for a press — it has no key pop-up.
    func finish(from token: GestureTrailToken) {
        guard owner === token else { return }
        // Released before the `isRecording` check so a touch taken while the
        // setting was off still hands the trail back to the next gesture.
        owner = nil
        guard isRecording else { return }
        isRecording = false
        trail.release(at: now())
        scheduleFadeOut()
    }

    /// Discards the trail immediately, without a fade. Used for the paths that
    /// end a touch without a gesture: a system cancellation and the teardown
    /// of a key that was mid-gesture (which reaches neither `onEnded` nor the
    /// cancel path).
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
        setVisible(true)
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

/// Owns one `GestureTrailRecorder` for the lifetime of a view.
///
/// `@State` rebuilds its initial value on every `body` evaluation and throws
/// it away again; `@StateObject` takes it as an autoclosure and evaluates it
/// once. Going through a holder that publishes nothing keeps that without
/// subscribing the grid to the recorder — an `isVisible` flip would otherwise
/// re-render all ~40 keys twice per gesture.
final class GestureTrailStore: ObservableObject {
    let recorder = GestureTrailRecorder()
}
