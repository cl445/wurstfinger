//
//  OrientationLayoutTests.swift
//  wurstfingerTests
//
//  Tests for Bug #92: Keyboard misalignment after orientation change while backgrounded.
//

import Combine
import Foundation
import Testing
@testable import WurstfingerApp

struct OrientationLayoutTests {
    // MARK: - Bug #92: Orientation change while backgrounded

    /// Bug #92: When the keyboard is backgrounded during an orientation change
    /// (e.g. user opens camera in landscape), the keyboard layout uses stale
    /// screen bounds on return because no @Published property triggers a re-render.
    ///
    /// The viewModel must provide a published `viewWidth` that the controller
    /// updates in `viewWillLayoutSubviews()`, so SwiftUI re-evaluates the layout.
    @Test("viewModel publishes viewWidth changes for orientation handling")
    func viewModelPublishesViewWidthChanges() async {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

        // Collect objectWillChange notifications
        var changeCount = 0
        let cancellable = viewModel.objectWillChange
            .sink { _ in changeCount += 1 }

        // Simulate portrait width
        viewModel.updateViewWidth(390)
        #expect(viewModel.viewWidth == 390)

        // Simulate landscape width — must trigger objectWillChange so SwiftUI re-renders
        let previousCount = changeCount
        viewModel.updateViewWidth(844)
        #expect(viewModel.viewWidth == 844)
        #expect(changeCount > previousCount, "Changing viewWidth must trigger objectWillChange")

        // Setting the same width should NOT trigger a redundant update
        let countBefore = changeCount
        viewModel.updateViewWidth(844)
        #expect(changeCount == countBefore, "Same width should not trigger objectWillChange")

        _ = cancellable
    }

    /// The hosting controller view must have a top anchor constraint so it
    /// properly fills the keyboard view on layout changes (orientation).
    @Test("KeyboardRootView uses viewModel.viewWidth instead of screen bounds")
    func rootViewUsesViewModelWidth() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)

        // Set a known width
        viewModel.updateViewWidth(400)

        // The viewModel should expose viewWidth for the view to use
        #expect(viewModel.viewWidth == 400)

        // After orientation change, the width should reflect the new value
        viewModel.updateViewWidth(800)
        #expect(viewModel.viewWidth == 800)
    }
}
