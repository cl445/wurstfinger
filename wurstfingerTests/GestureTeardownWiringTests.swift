//
//  GestureTeardownWiringTests.swift
//  WurstfingerTests
//
//  Pins the `onDisappear` teardown of both gesture modifiers.
//
//  `LongPressSchedulerTests` covers the primitive — `abandon()` drops the
//  armed work item and the consumed flag — but nothing covered the wiring that
//  calls it. A mutation run removed the `abandonSequence()` call from both
//  `onDisappear` hooks and the entire test target stayed green (review
//  2026-08-09, finding 15), which is exactly the regression that lets a key
//  torn down mid-hold fire its digit 0.7 s later into whatever mode replaced
//  it.
//
//  The hook only runs on a real view lifecycle, so these tests drive one:
//  the modifier goes on screen in its own window and is then removed. Arming
//  the long press through the real gesture would need touch events this target
//  cannot synthesize, so the scheduler is injected pre-armed instead — that
//  injection point exists for this test and is documented as such on both
//  initializers.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import WurstfingerApp

@MainActor
@Suite(.serialized)
struct GestureTeardownWiringTests {
    @Test func keyGestureRecognizerTeardownDisarmsTheLongPress() {
        let scheduler = armedScheduler()
        defer { scheduler.cancel() }

        let lifecycle = hostThenRemove(
            Color.clear.modifier(KeyGestureRecognizer(
                onGestureRecognized: { _ in },
                onTouchDown: {},
                aspectRatio: 1,
                onLongPress: { false },
                trail: nil,
                isActive: .constant(false),
                longPress: scheduler
            ))
        )

        expectRanTeardown(lifecycle)
        #expect(!scheduler.isScheduled)
        #expect(!scheduler.consumedTouch)
    }

    @Test func slideGestureHandlerTeardownDisarmsTheLongPress() {
        let scheduler = armedScheduler()
        defer { scheduler.cancel() }

        let lifecycle = hostThenRemove(
            Color.clear.modifier(SlideGestureHandler(
                slideType: .moveCursor,
                onSlide: { _ in },
                onTouchDown: {},
                onLongPress: { false },
                trail: nil,
                isActive: .constant(false),
                longPress: scheduler
            ))
        )

        expectRanTeardown(lifecycle)
        #expect(!scheduler.isScheduled)
        #expect(!scheduler.consumedTouch)
    }

    // MARK: - Fixtures

    /// A scheduler armed far beyond the test's own lifetime and already
    /// carrying the consumed flag. Both halves are what `abandon()` clears,
    /// and the delay makes sure a *fired* timer can never be mistaken for a
    /// teardown that disarmed one.
    private func armedScheduler() -> LongPressScheduler {
        let scheduler = LongPressScheduler()
        scheduler.runFire { true }
        scheduler.schedule(after: 60) { false }
        #expect(scheduler.isScheduled)
        #expect(scheduler.consumedTouch)
        return scheduler
    }

    /// Records the SwiftUI lifecycle the host actually delivered, so a
    /// failure distinguishes "the teardown did not disarm the scheduler" from
    /// "this environment never tore the view down at all".
    private final class Lifecycle {
        var appeared = false
        var disappeared = false
    }

    private func expectRanTeardown(_ lifecycle: Lifecycle) {
        #expect(lifecycle.appeared, "the hosted view never rendered, so no teardown hook could run")
        #expect(lifecycle.disappeared, "SwiftUI never delivered onDisappear to the hosted view")
    }

    // MARK: - View lifecycle

    /// Puts `content` on screen in its own window, waits for it to appear,
    /// then removes it and waits for the teardown to land.
    private func hostThenRemove(_ content: some View) -> Lifecycle {
        let lifecycle = Lifecycle()
        let window = makeWindow()
        let host = UIHostingController(
            rootView: AnyView(
                content
                    .onAppear { lifecycle.appeared = true }
                    .onDisappear { lifecycle.disappeared = true }
            )
        )
        defer {
            window.rootViewController = nil
            window.isHidden = true
        }

        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        drainRunLoop(until: { lifecycle.appeared })

        // Removed twice over, because either route reaches the hook and which
        // one SwiftUI takes is a version detail: first the content is replaced
        // inside the same host, then the whole hierarchy is dropped.
        host.rootView = AnyView(Color.clear)
        host.view.layoutIfNeeded()
        drainRunLoop(until: { lifecycle.disappeared })
        window.rootViewController = nil
        drainRunLoop(until: { lifecycle.disappeared })

        return lifecycle
    }

    /// A window of the host app's scene when there is one — a scene-less
    /// window does not reliably run SwiftUI's appearance callbacks.
    private func makeWindow() -> UIWindow {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else {
            return UIWindow(frame: bounds)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = bounds
        return window
    }

    /// Drains the main runloop in short slices until `condition` holds or the
    /// deadline passes. Fast when SwiftUI delivers promptly, tolerant when a
    /// loaded CI runner delays a render pass.
    private func drainRunLoop(deadline: TimeInterval = 2.0, until condition: () -> Bool) {
        let end = Date().addingTimeInterval(deadline)
        while !condition(), Date() < end {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
