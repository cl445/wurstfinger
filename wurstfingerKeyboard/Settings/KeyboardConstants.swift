//
//  KeyboardConstants.swift
//  Wurstfinger
//
//  Shared constants for keyboard dimensions, font sizes, and gesture thresholds.
//

import CoreGraphics
import Foundation

enum KeyboardConstants {
    // MARK: - Key Dimensions

    enum KeyDimensions {
        /// Standard key height in points.
        /// Derived from iOS standard keyboard key height (~54pt) for comfortable touch targets.
        static let height: CGFloat = 54

        /// Minimum key width for accessibility compliance.
        /// Based on Apple's Human Interface Guidelines (44pt minimum touch target).
        static let minWidth: CGFloat = 44

        /// Corner radius for modern iOS appearance.
        /// Matches iOS 15+ system keyboard style.
        static let cornerRadius: CGFloat = 8

        /// Reference key aspect ratio (width/height) at which `height` is defined.
        /// Used only as the baseline in `Calculations.keyHeight`; it is NOT the
        /// user-facing default setting (that is `DeviceLayoutUtils.defaultKeyAspectRatio`).
        static let referenceAspectRatio: CGFloat = 1.5

        /// Total number of rows in the keyboard layout.
        /// 3 rows for main keys + 1 row for space bar = 4 rows.
        static let totalRows: Int = 4
    }

    // MARK: - Font Sizes

    enum FontSizes {
        /// Main key label size (center character).
        static let keyLabel: CGFloat = 22

        /// Default label size for utility buttons.
        static let defaultLabel: CGFloat = 18

        /// Utility column label size (globe, delete, return).
        static let utilityLabel: CGFloat = 22

        /// Emphasized hint label size (for frequently used characters).
        static let hintEmphasis: CGFloat = 11

        /// Normal hint label size (for less common characters).
        static let hintNormal: CGFloat = 10

        // Main label dynamic scaling
        /// Base size for main label scaling calculations.
        static let mainLabelBaseSize: CGFloat = 26
        /// Reference key height for scaling calculations.
        static let mainLabelReferenceHeight: CGFloat = KeyDimensions.height
        /// Minimum main label size to ensure readability.
        static let mainLabelMinSize: CGFloat = 20
        /// Maximum main label size to prevent overflow.
        static let mainLabelMaxSize: CGFloat = 34

        // Hint label dynamic scaling
        /// Base size for hint label scaling.
        static let hintBaseSize: CGFloat = 14
        /// Reference height for hint scaling.
        static let hintReferenceHeight: CGFloat = KeyDimensions.height
        /// Minimum hint size to ensure readability.
        static let hintMinSize: CGFloat = 10
        /// Maximum hint size to prevent visual clutter.
        static let hintMaxSize: CGFloat = 22
        /// Multiplier for emphasized hints (1.1 = 10% larger).
        static let hintEmphasisMultiplier: CGFloat = 1.1
        /// Reference font size for hint padding calculations.
        static let hintReferenceFontSize: CGFloat = 10

        // Hint padding
        /// Horizontal padding around hint labels.
        static let hintBaseHorizontalPadding: CGFloat = 2
        /// Vertical padding around hint labels.
        static let hintBaseVerticalPadding: CGFloat = 0.5
    }

    // MARK: - Layout Spacing

    enum Layout {
        /// Horizontal gap between keys in the grid.
        static let gridHorizontalSpacing: CGFloat = 5
        /// Vertical gap between key rows.
        static let gridVerticalSpacing: CGFloat = 5
        /// Left/right padding of the entire keyboard.
        static let horizontalPadding: CGFloat = 12
        /// Top padding - minimal since keyboard sits directly below text input.
        static let verticalPaddingTop: CGFloat = 4
        /// Bottom padding - accounts for home indicator safe area on notched devices.
        static let verticalPaddingBottom: CGFloat = 10
        /// Margin for hint labels from key edges.
        static let hintMargin: CGFloat = 10
        /// Larger margin for "returning" hint labels (swipe-and-return gestures).
        static let hintMarginReturning: CGFloat = 22
    }

    // MARK: - Gesture Recognition

    enum Gesture {
        /// Minimum swipe distance to register as a swipe (not a tap).
        /// ~55% of key height (54pt × 0.55 ≈ 30pt) to avoid accidental swipes.
        static let minSwipeLength: CGFloat = 30

        /// Tolerance for circular gesture end-point matching.
        /// How close the finger must return to the start point to complete a circle.
        static let circleCompletionTolerance: CGFloat = 16

        /// Multiplier for final swipe offset calculation.
        /// 0.71 ≈ 1/√2, accounts for diagonal swipes being longer than cardinal directions.
        static let finalOffsetMultiplier: CGFloat = 0.71

        /// Number of touch points to buffer for gesture analysis.
        /// 60 points at 60Hz = 1 second of touch history.
        static let positionBufferSize: Int = 60
    }

    // MARK: - Space Key Gestures

    enum SpaceGestures {
        /// Minimum drag distance to activate cursor movement mode.
        static let dragActivationThreshold: CGFloat = 8

        /// Minimum drag distance to activate text selection mode.
        static let selectionActivationThreshold: CGFloat = 24

        /// Distance per cursor movement step (one character).
        /// Provides smooth, controlled cursor navigation.
        static let dragStep: CGFloat = 14

        /// Maximum ratio of final displacement to peak displacement for a return swipe.
        /// Below this threshold, the gesture is classified as a return swipe (word movement).
        static let returnSwipeThreshold: CGFloat = 0.3
    }

    // MARK: - Delete Key Gestures

    enum DeleteGestures {
        /// Minimum drag distance to activate delete-drag mode.
        static let dragActivationThreshold: CGFloat = 8

        /// Distance to activate slide-delete (continuous deletion).
        static let slideActivationThreshold: CGFloat = 28

        /// Distance for word-at-a-time deletion gesture.
        static let wordSwipeThreshold: CGFloat = 40

        /// Vertical movement tolerance during horizontal delete swipe.
        static let verticalTolerance: CGFloat = 28

        /// Interval between repeated deletions during hold (in seconds).
        /// 0.08s = ~12.5 characters per second.
        static let repeatInterval: TimeInterval = 0.08

        /// Initial delay before repeat-delete starts (in seconds).
        static let repeatDelay: TimeInterval = 0.35
    }

    // MARK: - Preview Settings

    enum Preview {
        /// Minimum height for keyboard preview in settings.
        static let minHeight: CGFloat = 100
        /// Maximum height for keyboard preview in settings.
        static let maxHeight: CGFloat = 400
    }

    // MARK: - Keyboard Calculations

    enum Calculations {
        /// Calculates the adjusted key height based on aspect ratio
        static func keyHeight(aspectRatio: CGFloat) -> CGFloat {
            KeyDimensions.height * (KeyDimensions.referenceAspectRatio / aspectRatio)
        }

        /// Calculates the total keyboard base height (without scaling)
        static func baseHeight(aspectRatio: CGFloat) -> CGFloat {
            let keyHeight = keyHeight(aspectRatio: aspectRatio)
            return (keyHeight * CGFloat(KeyDimensions.totalRows)) +
                (Layout.gridVerticalSpacing * CGFloat(KeyDimensions.totalRows - 1)) +
                Layout.verticalPaddingTop + Layout.verticalPaddingBottom
        }
    }
}
