//
//  OrientationLayoutTests.swift
//  wurstfingerTests
//
//  Tests for keyboard misalignment after orientation change while backgrounded.
//

import Combine
import Foundation
import Testing
@testable import WurstfingerApp

struct OrientationLayoutTests {
    /// When the keyboard is backgrounded during an orientation change
    /// (e.g. user opens camera in landscape), the keyboard layout uses stale
    /// screen bounds on return because no @Published property triggers a SwiftUI
    /// re-render. viewWillAppear is NOT called when the keyboard was already
    /// loaded but inactive — only viewWillLayoutSubviews runs.
    ///
    /// The viewModel must have a @Published viewWidth that the controller updates
    /// in viewWillLayoutSubviews(), so SwiftUI re-evaluates the layout.
    @Test("viewWidth publishes changes for orientation handling")
    func viewWidthPublishesChanges() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        var observedWidths: [CGFloat] = []
        let cancellable = viewModel.$viewWidth
            .dropFirst()
            .sink { observedWidths.append($0) }

        viewModel.updateViewWidth(400)
        viewModel.updateViewWidth(800)

        #expect(observedWidths == [400, 800])
        #expect(viewModel.viewWidth == 800)
        _ = cancellable
    }

    @Test("Same viewWidth does not trigger redundant publish")
    func sameViewWidthNoRedundantPublish() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        var publishCount = 0
        let cancellable = viewModel.$viewWidth
            .dropFirst()
            .sink { _ in publishCount += 1 }

        viewModel.updateViewWidth(400)
        viewModel.updateViewWidth(400)

        #expect(publishCount == 1, "Same width should not publish again")
        _ = cancellable
    }

    // MARK: - Window bounds (Split View / Stage Manager, issue #116)

    private var screenShortestSide: CGFloat {
        min(DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height)
    }

    @Test("Keyboard-sized window keeps the screen's portrait width")
    func keyboardSizedWindowKeepsPortraitWidth() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        // The extension's window is only as tall as the keyboard itself
        // (issue behind #219's regression): its height must never cap the
        // width. Portrait: window spans the screen width, keyboard-height tall.
        viewModel.updateWindowBounds(
            CGRect(x: 0, y: 0, width: DeviceLayoutUtils.screenBounds.width, height: 300)
        )
        #expect(viewModel.keyboardWidthCap == screenShortestSide)

        // Landscape: window is screen-height wide; the screen's shortest
        // side still caps the keyboard at its portrait width.
        viewModel.updateWindowBounds(
            CGRect(x: 0, y: 0, width: DeviceLayoutUtils.screenBounds.height, height: 250)
        )
        #expect(viewModel.keyboardWidthCap == screenShortestSide)
    }

    @Test("Narrow pane window caps the keyboard width")
    func narrowPaneWindowCapsWidth() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        // Slide Over / narrow Split View pane: the window width is the
        // available container width and wins over the screen.
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 300))
        #expect(viewModel.keyboardWidthCap == 320)
    }

    @Test("Nil window falls back to the device screen")
    func nilWindowFallsBackToScreen() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 300))
        viewModel.updateWindowBounds(nil)

        #expect(viewModel.keyboardWidthCap == screenShortestSide)
    }

    @Test("Same window bounds do not trigger redundant publish")
    func sameWindowBoundsNoRedundantPublish() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        var publishCount = 0
        let cancellable = viewModel.$keyboardWidthCap
            .dropFirst()
            .sink { _ in publishCount += 1 }

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 300))
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 300))

        #expect(publishCount == 1, "Same bounds should not publish again")
        _ = cancellable
    }

    @Test("Landscape metrics never exceed the portrait width cap")
    func landscapeMetricsRespectWidthCap() {
        // PR #223 semantics under the point-anchored model: even a maximal
        // width wish must not blow the keyboard up to the full landscape
        // width — the resolved metrics stay within the window-derived cap
        // (bounded by the screen's shortest side).
        let viewModel = KeyboardViewModel(
            userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false
        )
        viewModel.keyboardWidth = 600

        // Landscape: the view spans the long side, the window caps at the
        // screen's shortest side.
        let longSide = max(DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height)
        viewModel.updateViewWidth(longSide)
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: longSide, height: 300))

        #expect(viewModel.layoutMetrics.keyboardWidth <= screenShortestSide)
    }

    @Test("Degenerate window bounds are ignored")
    func degenerateWindowBoundsIgnored() {
        let viewModel = KeyboardViewModel(userDefaults: InMemoryUserDefaults(), shouldPersistSettings: false)

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 300))
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 0, height: 300))

        #expect(viewModel.keyboardWidthCap == 320, "Zero-sized bounds must not be adopted")
    }
}
