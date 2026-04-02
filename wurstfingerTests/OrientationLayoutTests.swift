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
    /// Bug #92: When the keyboard is backgrounded during an orientation change
    /// (e.g. user opens camera in landscape), the keyboard layout uses stale
    /// screen bounds on return because no @Published property triggers a SwiftUI
    /// re-render. viewWillAppear is NOT called when the keyboard was already
    /// loaded but inactive — only viewWillLayoutSubviews runs.
    ///
    /// The viewModel must have a @Published viewWidth that the controller updates
    /// in viewWillLayoutSubviews(), so SwiftUI re-evaluates the layout.
    @Test("viewModel has published viewWidth for orientation change handling")
    func viewModelHasPublishedViewWidth() {
        let viewModel = KeyboardViewModel(shouldPersistSettings: false)
        let mirror = Mirror(reflecting: viewModel)

        // @Published properties are stored with an underscore prefix in Mirror.
        let hasViewWidth = mirror.children.contains { label, _ in
            label == "_viewWidth"
        }

        #expect(
            hasViewWidth,
            """
            KeyboardViewModel must have @Published viewWidth so the controller \
            can signal width changes in viewWillLayoutSubviews(). Without it, \
            orientation changes while the keyboard is backgrounded leave the \
            layout stale because SwiftUI has no observable trigger to re-render.
            """
        )
    }
}
