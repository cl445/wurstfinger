//
//  HapticFeedbackManager.swift
//  Wurstfinger
//
//  Extracted from KeyboardViewModel to improve separation of concerns.
//  Handles all haptic feedback generation for the keyboard.
//

import UIKit

/// The physical pulse emitted for a haptic event.
///
/// `UIImpactFeedbackGenerator.impactOccurred(intensity:)` requires
/// CHHapticEngine, which cannot initialize in the sandboxed keyboard
/// extension process, so continuous intensity is unavailable. To still give
/// the intensity slider a wide perceived range, the scale starts with a
/// barely-noticeable `UISelectionFeedbackGenerator` tick and then steps
/// through impact styles up to `.heavy`.
enum HapticPulse: Equatable {
    /// `UISelectionFeedbackGenerator` tick — the subtlest available feedback.
    case selectionTick
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)

    /// Maps a 0...1 intensity to a pulse (0 is handled upstream as "off").
    static func pulse(for intensity: CGFloat) -> HapticPulse {
        switch intensity {
        case ..<0.2: .selectionTick
        case ..<0.4: .impact(.soft)
        case ..<0.6: .impact(.light)
        case ..<0.8: .impact(.medium)
        default: .impact(.heavy)
        }
    }
}

/// Manages haptic feedback generation for keyboard events.
///
/// Requires Full Access to be enabled — without it, `UIFeedbackGenerator` silently
/// fails because the underlying `CHHapticEngine` is blocked by the keyboard sandbox.
/// The host app settings UI prevents enabling haptics when Full Access is not granted.
final class HapticFeedbackManager {
    private let settings: HapticSettings

    /// Cached generators per feedback style to avoid per-event allocation
    private lazy var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = {
        var gens = [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator]()
        for style in [UIImpactFeedbackGenerator.FeedbackStyle.soft, .light, .medium, .heavy] {
            gens[style] = UIImpactFeedbackGenerator(style: style)
        }
        return gens
    }()

    /// Detent-style ticks for drag steps and the lowest intensity level.
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()

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

        let pulse: HapticPulse = switch event {
        case .tap: .pulse(for: intensity)
        // Repeated drag steps always use the light detent tick —
        // `UISelectionFeedbackGenerator` is made for exactly this.
        case .drag: .selectionTick
        }

        let performFeedback = { [self] in
            switch pulse {
            case .selectionTick:
                selectionGenerator.selectionChanged()
                selectionGenerator.prepare()
            case let .impact(style):
                guard let generator = impactGenerators[style] ?? impactGenerators[.light] else { return }
                generator.impactOccurred()
                // Keep the Taptic Engine warm so the next keystroke fires
                // without ramp-up latency.
                generator.prepare()
            }
        }

        if Thread.isMainThread {
            performFeedback()
        } else {
            DispatchQueue.main.async(execute: performFeedback)
        }
    }
}
