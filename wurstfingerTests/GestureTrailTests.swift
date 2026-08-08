//
//  GestureTrailTests.swift
//  WurstfingerTests
//
//  Tests for the swipe trail: sample buffer, ribbon geometry and the
//  recorder that gates both on the user setting.
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import WurstfingerApp

// MARK: - Sample Buffer

struct GestureTrailBufferTests {
    @Test func beginSeedsOriginAndFirstSample() {
        var trail = GestureTrail()
        trail.begin(at: CGPoint(x: 10, y: 20), time: 100)
        #expect(trail.samples.count == 1)
        #expect(trail.origin == CGPoint(x: 10, y: 20))
        #expect(trail.maxDisplacement == 0)
        #expect(trail.releaseTime == nil)
    }

    @Test func extendBeforeBeginStartsTheTrail() {
        var trail = GestureTrail()
        trail.extend(to: CGPoint(x: 5, y: 5), time: 100)
        #expect(trail.origin == CGPoint(x: 5, y: 5))
        #expect(trail.samples.count == 1)
    }

    @Test func samplesCloserThanTheSpacingAreDropped() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.extend(to: CGPoint(x: 1, y: 0), time: 101, minimumSpacing: 4)
        trail.extend(to: CGPoint(x: 2, y: 0), time: 102, minimumSpacing: 4)
        #expect(trail.samples.count == 1)

        trail.extend(to: CGPoint(x: 4, y: 0), time: 103, minimumSpacing: 4)
        #expect(trail.samples.count == 2)
    }

    @Test func droppedSamplesStillAdvanceMaxDisplacement() {
        // Tap suppression must not depend on the decimation: a finger that
        // creeps outward in sub-spacing steps has still travelled.
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        for step in 1 ... 3 {
            trail.extend(to: CGPoint(x: CGFloat(step), y: 0), time: 100 + Double(step), minimumSpacing: 4)
        }
        #expect(trail.samples.count == 1)
        #expect(trail.maxDisplacement == 3)
    }

    @Test func maxDisplacementIsARunningMaximum() {
        // An out-and-back return swipe ends near its origin but has clearly
        // moved, so the peak — not the final distance — has to be reported.
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.extend(to: CGPoint(x: 40, y: 0), time: 101)
        trail.extend(to: CGPoint(x: 1, y: 0), time: 102)
        #expect(trail.maxDisplacement == 40)
    }

    @Test func capacityEvictsTheOldestSamples() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        for step in 1 ... 10 {
            trail.extend(to: CGPoint(x: CGFloat(step) * 10, y: 0), time: 100 + Double(step), capacity: 4)
        }
        #expect(trail.samples.count == 4)
        // The newest samples survive; the head must stay at the finger.
        #expect(trail.samples.last?.point == CGPoint(x: 100, y: 0))
    }

    @Test func visibleWindowDropsExpiredSamples() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.extend(to: CGPoint(x: 10, y: 0), time: 100.4)
        trail.extend(to: CGPoint(x: 20, y: 0), time: 100.9)

        let visible = trail.visiblePoints(at: 100.9, visibleDuration: 0.55)
        #expect(visible == [CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)])
    }

    @Test func releaseFreezesTheVisibleWindow() {
        // After lift the shape must stop shrinking from its tail, otherwise
        // the trail both fades and retracts and reads as two effects at once.
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.extend(to: CGPoint(x: 10, y: 0), time: 100.1)
        trail.release(at: 100.2)

        let atRelease = trail.visiblePoints(at: 100.2, visibleDuration: 0.55)
        let laterOn = trail.visiblePoints(at: 105, visibleDuration: 0.55)
        #expect(atRelease == laterOn)
        #expect(laterOn.count == 2)
    }

    @Test func fadeOpacityIsFullWhileTheFingerIsDown() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        #expect(trail.fadeOpacity(at: 200, fadeOutDuration: 0.22) == 1)
        #expect(!trail.isFinished(at: 200, fadeOutDuration: 0.22))
    }

    @Test func fadeOpacityRampsToZeroAfterRelease() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.release(at: 100)
        #expect(trail.fadeOpacity(at: 100, fadeOutDuration: 0.2) == 1)
        #expect(abs(trail.fadeOpacity(at: 100.1, fadeOutDuration: 0.2) - 0.5) < 0.0001)
        #expect(trail.fadeOpacity(at: 100.2, fadeOutDuration: 0.2) == 0)
        // Never negative, however late the frame arrives.
        #expect(trail.fadeOpacity(at: 999, fadeOutDuration: 0.2) == 0)
    }

    @Test func isFinishedOnlyAfterTheFadeCompletes() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.release(at: 100)
        #expect(!trail.isFinished(at: 100.1, fadeOutDuration: 0.2))
        #expect(trail.isFinished(at: 100.2, fadeOutDuration: 0.2))
    }

    @Test func clearResetsEverything() {
        var trail = GestureTrail()
        trail.begin(at: .zero, time: 100)
        trail.extend(to: CGPoint(x: 40, y: 0), time: 101)
        trail.release(at: 102)
        trail.clear()
        #expect(trail.isEmpty)
        #expect(trail.origin == nil)
        #expect(trail.maxDisplacement == 0)
        #expect(trail.releaseTime == nil)
    }
}

// MARK: - Ribbon Geometry

struct GestureTrailGeometryTests {
    @Test func smoothingKeepsTheOriginalSamplesOnThePath() {
        // Catmull-Rom interpolates rather than approximates, so the trail must
        // still pass through every position the finger actually visited.
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 60, y: 30),
        ]
        let smoothed = GestureTrailGeometry.smoothed(points, subdivisions: 4)
        for point in points {
            #expect(smoothed.contains { hypot($0.x - point.x, $0.y - point.y) < 0.0001 })
        }
        #expect(smoothed.first == points.first)
        #expect(smoothed.last == points.last)
        #expect(smoothed.count == (points.count - 1) * 4 + 1)
    }

    @Test func smoothingPassesShortPathsThrough() {
        let two = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        #expect(GestureTrailGeometry.smoothed(two, subdivisions: 4) == two)
        #expect(GestureTrailGeometry.smoothed([], subdivisions: 4).isEmpty)
    }

    @Test func widthTapersFromTailToHead() {
        let head: CGFloat = 12
        let tail = GestureTrailGeometry.halfWidth(atProgress: 0, headWidth: head, taperExponent: 0.55)
        let middle = GestureTrailGeometry.halfWidth(atProgress: 0.5, headWidth: head, taperExponent: 0.55)
        let finger = GestureTrailGeometry.halfWidth(atProgress: 1, headWidth: head, taperExponent: 0.55)

        #expect(tail == 0)
        #expect(finger == head / 2)
        #expect(middle > tail && middle < finger)
        // Below 1 the exponent has to keep the ribbon thick well before the
        // head — a linear taper would sit at exactly half here.
        #expect(middle > head / 4)
    }

    @Test func widthClampsProgressOutsideTheUnitRange() {
        #expect(GestureTrailGeometry.halfWidth(atProgress: -1, headWidth: 10) == 0)
        #expect(GestureTrailGeometry.halfWidth(atProgress: 2, headWidth: 10) == 5)
    }

    @Test func ribbonIsEmptyForDegenerateInput() {
        #expect(GestureTrailGeometry.ribbon(through: [], headWidth: 10).isEmpty)
        #expect(GestureTrailGeometry.ribbon(through: [.zero], headWidth: 10).isEmpty)
        #expect(GestureTrailGeometry.ribbon(through: [.zero, CGPoint(x: 10, y: 0)], headWidth: 0).isEmpty)
    }

    @Test func ribbonWrapsTheStraightPathWithinItsWidth() {
        let path = [CGPoint(x: 0, y: 50), CGPoint(x: 100, y: 50)]
        let head: CGFloat = 12
        let box = GestureTrailGeometry.ribbon(through: path, headWidth: head).boundingRect

        // The tail is a point and the head a semicircle, so the ribbon spans
        // the path plus one radius beyond the finger and nothing behind it.
        #expect(abs(box.minX - 0) < 0.5)
        #expect(abs(box.maxX - (100 + head / 2)) < 0.5)
        #expect(box.height <= head + 0.5)
        #expect(abs(box.midY - 50) < 0.5)
    }

    @Test func cumulativeDistancesMeasureAlongThePath() {
        let path = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4), CGPoint(x: 3, y: 14)]
        #expect(GestureTrailGeometry.cumulativeDistances(along: path) == [0, 5, 15])
        #expect(GestureTrailGeometry.cumulativeDistances(along: []) == [0])
    }

    @Test func taperSpansAFixedLengthNotAFractionOfThePath() {
        // A long cursor slide must stay a constant-width stroke with a short
        // tail. Tapering by index fraction instead would stretch the wedge
        // across the whole trail and render it as one thin spike.
        let head: CGFloat = 10
        let longPath = (0 ... 40).map { CGPoint(x: CGFloat($0) * 10, y: 100) }
        let box = GestureTrailGeometry.ribbon(
            through: longPath, headWidth: head, taperLengthFactor: 3.5
        ).boundingRect

        // Sample the ribbon halfway along a 400pt path: far past the ~35pt
        // taper, so it has to be at full width there.
        let midX = 200.0
        let ribbon = GestureTrailGeometry.ribbon(through: longPath, headWidth: head, taperLengthFactor: 3.5)
        #expect(ribbon.contains(CGPoint(x: midX, y: 100 + head / 2 - 0.5)))
        #expect(!ribbon.contains(CGPoint(x: midX, y: 100 + head / 2 + 1)))
        #expect(box.height <= head + 0.5)
    }

    @Test func shortPathsStillReachFullWidthAtTheFinger() {
        // A quick flick is shorter than the nominal taper; it must taper across
        // itself rather than never getting thick enough to see.
        let head: CGFloat = 10
        let flick = [CGPoint(x: 0, y: 50), CGPoint(x: 12, y: 50), CGPoint(x: 24, y: 50)]
        let ribbon = GestureTrailGeometry.ribbon(through: flick, headWidth: head, taperLengthFactor: 3.5)
        #expect(ribbon.contains(CGPoint(x: 23, y: 50 + head / 2 - 0.5)))
    }

    @Test func ribbonIsPointedAtTheTail() {
        // The tail carries zero width, so the outline has to converge on the
        // oldest sample rather than starting with a blunt edge.
        let path = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 0)]
        let box = GestureTrailGeometry.ribbon(through: path, headWidth: 12).boundingRect
        #expect(box.minX >= -0.5)
    }

    @Test func ribbonSurvivesCoincidentPoints() {
        // The spline can emit duplicate positions; the ribbon must still be a
        // usable shape instead of collapsing or producing NaN coordinates.
        let path = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 30, y: 0),
        ]
        let box = GestureTrailGeometry.ribbon(through: path, headWidth: 10).boundingRect
        #expect(box.width.isFinite)
        #expect(box.height.isFinite)
        #expect(box.width > 0)
    }
}

// MARK: - Recorder

struct GestureTrailRecorderTests {
    /// Feeds a straight drag of `distance` points into the recorder.
    private func drag(
        _ recorder: GestureTrailRecorder,
        distance: CGFloat,
        steps: Int = 8,
        from token: GestureTrailToken = GestureTrailToken(),
        origin: CGPoint = .zero
    ) {
        recorder.record(origin, isTouchDown: true, from: token)
        for step in 1 ... steps {
            let x = origin.x + distance * CGFloat(step) / CGFloat(steps)
            recorder.record(CGPoint(x: x, y: origin.y), isTouchDown: false, from: token)
        }
    }

    private func makeRecorder(enabled: Bool, clock: @escaping () -> TimeInterval = { 0 }) -> GestureTrailRecorder {
        let defaults = InMemoryUserDefaults()
        defaults.set(enabled, forKey: SettingsKey.gestureTrailEnabled.rawValue)
        return GestureTrailRecorder(defaults: defaults, now: clock)
    }

    @Test func offByDefaultRecordsNothing() {
        let recorder = GestureTrailRecorder(defaults: InMemoryUserDefaults(), now: { 0 })
        drag(recorder, distance: 120)
        #expect(!recorder.isVisible)
        #expect(recorder.trail.isEmpty)
    }

    @Test func disabledRecordsNothing() {
        let recorder = makeRecorder(enabled: false)
        drag(recorder, distance: 120)
        #expect(!recorder.isVisible)
        #expect(recorder.trail.isEmpty)
    }

    @Test func enabledSwipeBecomesVisible() {
        var clock: TimeInterval = 0
        let recorder = makeRecorder(enabled: true, clock: { clock })
        let token = GestureTrailToken()
        recorder.record(.zero, isTouchDown: true, from: token)
        for step in 1 ... 8 {
            clock += 0.01
            recorder.record(CGPoint(x: CGFloat(step) * 15, y: 0), isTouchDown: false, from: token)
        }
        #expect(recorder.isVisible)
        #expect(recorder.trail.samples.count > 1)
    }

    @Test func tapStaysInvisible() {
        // Every keystroke starts as a touch down, so a trail that drew from
        // the first sample would flash under every letter typed.
        let recorder = makeRecorder(enabled: true)
        let token = GestureTrailToken()
        recorder.record(.zero, isTouchDown: true, from: token)
        recorder.record(CGPoint(x: 2, y: 1), isTouchDown: false, from: token)
        #expect(!recorder.isVisible)
    }

    @Test func finishingATapDropsTheTrailWithoutAFade() {
        let recorder = makeRecorder(enabled: true)
        let token = GestureTrailToken()
        recorder.record(.zero, isTouchDown: true, from: token)
        recorder.record(CGPoint(x: 2, y: 0), isTouchDown: false, from: token)
        recorder.finish(from: token)
        #expect(!recorder.isVisible)
        #expect(recorder.trail.isEmpty)
    }

    @Test func finishingASwipeFreezesTheTrailForItsFade() {
        var clock: TimeInterval = 500
        let recorder = makeRecorder(enabled: true, clock: { clock })
        let token = GestureTrailToken()
        drag(recorder, distance: 120, from: token)
        clock = 501
        recorder.finish(from: token)
        // Still drawn — the fade-out runs on a timer, not on this call.
        #expect(recorder.isVisible)
        #expect(recorder.trail.releaseTime == 501)
    }

    @Test func cancelDropsEverythingImmediately() {
        let recorder = makeRecorder(enabled: true)
        let token = GestureTrailToken()
        drag(recorder, distance: 120, from: token)
        recorder.cancel(from: token)
        #expect(!recorder.isVisible)
        #expect(recorder.trail.isEmpty)
    }

    @Test func aNewTouchDiscardsThePreviousTrail() {
        // Typing fast starts the next gesture while the last one is still
        // fading; the old path must not be extended by the new touch.
        let recorder = makeRecorder(enabled: true)
        let first = GestureTrailToken()
        drag(recorder, distance: 120, from: first)
        recorder.finish(from: first)
        recorder.record(CGPoint(x: 300, y: 300), isTouchDown: true, from: GestureTrailToken())
        #expect(!recorder.isVisible)
        #expect(recorder.trail.samples.map(\.point) == [CGPoint(x: 300, y: 300)])
    }

    @Test func theSettingIsSampledPerTouch() {
        // Flipping the toggle in the host app has to take effect on the next
        // gesture, without the extension observing the store on every key.
        let defaults = InMemoryUserDefaults()
        let recorder = GestureTrailRecorder(defaults: defaults, now: { 0 })
        let first = GestureTrailToken()
        drag(recorder, distance: 120, from: first)
        #expect(!recorder.isVisible)

        recorder.finish(from: first)
        defaults.set(true, forKey: SettingsKey.gestureTrailEnabled.rawValue)
        drag(recorder, distance: 120)
        #expect(recorder.isVisible)
    }

    // MARK: - Touch-Sequence Ownership

    @Test func aSecondFingerDoesNotHijackTheTrail() {
        // Two-thumb typing overlaps touch sequences. Without ownership the
        // second thumb's touch down restarts the stroke, so the trail jumps
        // across the keyboard between the two fingers.
        let recorder = makeRecorder(enabled: true)
        let left = GestureTrailToken()
        let right = GestureTrailToken()
        drag(recorder, distance: 120, from: left)

        recorder.record(CGPoint(x: 300, y: 300), isTouchDown: true, from: right)
        recorder.record(CGPoint(x: 340, y: 300), isTouchDown: false, from: right)

        #expect(recorder.isVisible)
        let points = recorder.trail.samples.map(\.point)
        #expect(points.allSatisfy { $0.y == 0 })
        #expect(recorder.trail.origin == .zero)
    }

    @Test func aSecondFingerLiftingDoesNotEndTheOwnersTrail() {
        let recorder = makeRecorder(enabled: true)
        let left = GestureTrailToken()
        let right = GestureTrailToken()
        drag(recorder, distance: 120, from: left)

        recorder.record(CGPoint(x: 300, y: 300), isTouchDown: true, from: right)
        recorder.finish(from: right)
        #expect(recorder.trail.releaseTime == nil)

        recorder.cancel(from: right)
        #expect(recorder.isVisible)
        #expect(!recorder.trail.isEmpty)
    }

    @Test func ownershipIsReleasedForTheNextGesture() {
        let recorder = makeRecorder(enabled: true)
        let first = GestureTrailToken()
        drag(recorder, distance: 120, from: first)
        recorder.cancel(from: first)

        let second = GestureTrailToken()
        drag(recorder, distance: 120, from: second)
        #expect(recorder.isVisible)
    }

    @Test func ownershipIsReleasedEvenWhenTheSettingWasOff() {
        // A touch taken while the trail was disabled still claims the trail,
        // so it has to hand it back — otherwise enabling the setting would
        // leave the feature dead until the view is rebuilt.
        let defaults = InMemoryUserDefaults()
        let recorder = GestureTrailRecorder(defaults: defaults, now: { 0 })
        let first = GestureTrailToken()
        drag(recorder, distance: 120, from: first)
        recorder.finish(from: first)

        defaults.set(true, forKey: SettingsKey.gestureTrailEnabled.rawValue)
        drag(recorder, distance: 120, from: GestureTrailToken())
        #expect(recorder.isVisible)
    }
}

// MARK: - Overlay Sizing

struct GestureTrailOverlaySizingTests {
    @Test func headWidthScalesWithTheRowHeight() {
        let small = KeyboardLayoutMetrics.resolve(
            wishWidth: 200, aspectRatio: 1, columns: 5, rows: 4,
            availableWidth: 400, screenHeight: 900
        )
        let large = KeyboardLayoutMetrics.resolve(
            wishWidth: 390, aspectRatio: 1, columns: 5, rows: 4,
            availableWidth: 400, screenHeight: 900
        )
        #expect(large.rowHeight > small.rowHeight)
        #expect(GestureTrailOverlay.headWidth(for: large) >= GestureTrailOverlay.headWidth(for: small))
    }

    @Test func headWidthStaysInsideTheClamps() {
        for wish in stride(from: 90.0, through: 600.0, by: 30.0) {
            let metrics = KeyboardLayoutMetrics.resolve(
                wishWidth: wish, aspectRatio: 1.3, columns: 5, rows: 4,
                availableWidth: 600, screenHeight: 1000
            )
            let width = GestureTrailOverlay.headWidth(for: metrics)
            #expect(width >= KeyboardConstants.GestureTrail.minWidth)
            #expect(width <= KeyboardConstants.GestureTrail.maxWidth)
        }
    }
}
