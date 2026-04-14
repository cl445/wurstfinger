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
}
