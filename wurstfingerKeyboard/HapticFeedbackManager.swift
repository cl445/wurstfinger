//
//  HapticFeedbackManager.swift
//  Wurstfinger
//
//  Extracted from KeyboardViewModel to improve separation of concerns.
//  Handles all haptic feedback generation for the keyboard.
//

import UIKit

/// Manages haptic feedback generation for keyboard events.
///
/// Uses `UIImpactFeedbackGenerator.impactOccurred()` (without intensity parameter)
/// because the intensity variant requires CHHapticEngine, which cannot initialize
/// in the sandboxed keyboard extension process.
/// Intensity is approximated by selecting different feedback styles.
///
/// Requires Full Access to be enabled — without it, `UIFeedbackGenerator` silently
/// fails because the underlying `CHHapticEngine` is blocked by the keyboard sandbox.
/// The host app settings UI prevents enabling haptics when Full Access is not granted.
final class HapticFeedbackManager {
    private let settings: HapticSettings

    /// Cached generators per feedback style to avoid per-event allocation
    private lazy var generators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = {
        var gens = [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator]()
        for style in [UIImpactFeedbackGenerator.FeedbackStyle.light, .medium, .rigid, .heavy] {
            gens[style] = UIImpactFeedbackGenerator(style: style)
        }
        return gens
    }()

    init(settings: HapticSettings) {
        self.settings = settings
    }

    // MARK: - Public API

    /// Triggers haptic feedback for a key tap (touch-down)
    func tap() {
        trigger(.tap)
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

        let style = Self.style(for: intensity)

        let performFeedback = { [self] in
            guard let generator = generators[style] ?? generators[.medium] else { return }
            generator.impactOccurred()
        }

        if Thread.isMainThread {
            performFeedback()
        } else {
            DispatchQueue.main.async(execute: performFeedback)
        }
    }

    /// Maps a 0...1 intensity to a feedback style
    private static func style(for intensity: CGFloat) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch intensity {
        case ..<0.3: .light
        case ..<0.6: .medium
        case ..<0.8: .rigid
        default: .heavy
        }
    }
}
