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
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

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
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

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

    @Test("Window bounds publish their shortest side")
    func windowBoundsPublishShortestSide() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

        // Landscape Split View pane: height is the shortest side.
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 507, height: 834))
        #expect(viewModel.windowShortestSide == 507)

        // Portrait pane: width is the shortest side.
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 320, height: 1180))
        #expect(viewModel.windowShortestSide == 320)
    }

    @Test("Nil window falls back to the device screen")
    func nilWindowFallsBackToScreen() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        let screenShortestSide = min(
            DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height
        )

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 507, height: 834))
        viewModel.updateWindowBounds(nil)

        #expect(viewModel.windowShortestSide == screenShortestSide)
    }

    @Test("Same window bounds do not trigger redundant publish")
    func sameWindowBoundsNoRedundantPublish() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

        var publishCount = 0
        let cancellable = viewModel.$windowShortestSide
            .dropFirst()
            .sink { _ in publishCount += 1 }

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 507, height: 834))
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 507, height: 834))

        #expect(publishCount == 1, "Same bounds should not publish again")
        _ = cancellable
    }

    @Test("Degenerate window bounds are ignored")
    func degenerateWindowBoundsIgnored() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 507, height: 834))
        viewModel.updateWindowBounds(CGRect(x: 0, y: 0, width: 0, height: 834))

        #expect(viewModel.windowShortestSide == 507, "Zero-sized bounds must not be adopted")
    }
}
