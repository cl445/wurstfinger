//
//  DataDrivenKeyboardRootView.swift
//  Wurstfinger
//
//  Root SwiftUI view that renders the data-driven keyboard using
//  KeyboardGridView. Replaces KeyboardRootView as the hosting target
//  in KeyboardViewController.
//

import SwiftUI

/// Root view for the data-driven keyboard path. Reads mode and arrangement
/// from the ViewModel and delegates all gesture callbacks back to it.
struct DataDrivenKeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        if let mode = viewModel.activeModeFromDefinition,
           let arrangement = mode.arrangement(for: viewModel.currentContext) {
            KeyboardGridView(
                arrangement: arrangement,
                keys: mode.keys,
                onGesture: { key, gesture, isReturn in
                    viewModel.handleGesture(gesture, keyId: key.id, isReturn: isReturn)
                },
                onTouchDown: {
                    viewModel.feedbackTap()
                },
                onSlide: { key, phase in
                    viewModel.handleSlide(key, phase: phase)
                }
            )
            .scaleEffect(viewModel.keyboardScale)
            .frame(maxWidth: .infinity)
        } else {
            // Fallback: show nothing while definition loads.
            // This should only flash for a single frame at most.
            Color.clear
        }
    }
}
