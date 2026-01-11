//
//  HapticFeedbackManager.swift
//  Wurstfinger
//
//  Extracted from KeyboardViewModel to improve separation of concerns.
//  Handles all haptic feedback generation for the keyboard.
//

import UIKit

/// Manages haptic feedback generation for keyboard events.
/// Uses UIImpactFeedbackGenerator with configurable intensity per event type.
final class HapticFeedbackManager {

    private let settings: HapticSettings

    /// Feedback style used for all haptic events.
    /// Using .rigid provides a crisp, responsive feel that scales well with intensity.
    private let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .rigid

    init(settings: HapticSettings) {
        self.settings = settings
    }

    // MARK: - Public API

    /// Triggers haptic feedback for a key tap
    func tap() {
        trigger(.tap)
    }

    /// Triggers haptic feedback for modifier actions (shift, symbols, etc.)
    func modifier() {
        trigger(.modifier)
    }

    /// Triggers haptic feedback for drag operations (cursor movement, delete drag)
    func drag() {
        trigger(.drag)
    }

    /// Triggers haptic feedback for the specified event type
    func trigger(_ event: KeyboardHapticEvent) {
        guard settings.enabled else { return }

        let intensity = settings.intensity(for: event)
        guard intensity > 0 else { return }

        let performFeedback = { [feedbackStyle] in
            // Create a new generator for each event to ensure reliability.
            // This matches the behavior in HapticSettingsView which is confirmed to work.
            let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
            generator.prepare()
            generator.impactOccurred(intensity: intensity)
        }

        if Thread.isMainThread {
            performFeedback()
        } else {
            DispatchQueue.main.async(execute: performFeedback)
        }
    }
}
