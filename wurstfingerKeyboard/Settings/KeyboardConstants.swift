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

        // Main label dynamic scaling. Font sizes scale with the rendered
        // cell height relative to `KeyDimensions.height` (see
        // `KeyboardLayoutMetrics.fontScale`).
        /// Base size for main label scaling calculations.
        static let mainLabelBaseSize: CGFloat = 26
        /// Minimum main label size to ensure readability.
        static let mainLabelMinSize: CGFloat = 20
        /// Maximum main label size to prevent overflow.
        static let mainLabelMaxSize: CGFloat = 34

        // Hint label dynamic scaling
        /// Base size for hint label scaling.
        static let hintBaseSize: CGFloat = 14
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
        /// SwiftUI's DragGesture delivers samples at display refresh rate, so
        /// the buffer is sized for the fastest shipping display: 120 points
        /// hold 1 second of history at 120Hz (ProMotion) and 2 seconds at
        /// 60Hz. A smaller buffer evicts the outbound leg of slow return
        /// swipes, which then misclassify as plain swipes after
        /// origin-anchoring (see `KeyGestureRecognizer.anchoringOrigin`).
        static let positionBufferSize: Int = 120
    }

    // MARK: - Gesture Trail

    /// Tuning for the optional swipe trail drawn under the finger.
    ///
    /// A soft ribbon, widest at the finger and tapering to a point at its
    /// tail, kept short so it reads as a comet tail rather than a drawing of
    /// the whole path.
    enum GestureTrail {
        /// How far the finger must travel before any trail is drawn. Every
        /// keystroke on this keyboard starts as a touch-down, so without a
        /// threshold plain taps would flash a dot on every letter. Aliases
        /// `SpaceGestures.dragActivationThreshold`, the smallest travel the
        /// keyboard already treats as "not a tap", so retuning that threshold
        /// cannot desynchronize the two.
        static let activationDistance: CGFloat = SpaceGestures.dragActivationThreshold

        /// Minimum spacing between two recorded samples. Filters the duplicate
        /// positions a resting finger produces, which would otherwise fill the
        /// buffer and push the moving part of the path out of it. Kept coarse:
        /// the curve smoothing below rounds the path back out, so storing
        /// sub-pixel steps only costs memory.
        static let minimumSampleSpacing: CGFloat = 4

        /// Maximum number of retained samples. At `minimumSampleSpacing` this
        /// covers ~250pt of path — more than the visible window ever shows,
        /// while bounding memory in an extension with a tight jetsam limit.
        static let sampleCapacity: Int = 64

        /// Age after which a sample stops being drawn while the finger is
        /// still down. Long enough to show a whole flick swipe at once, short
        /// enough that a slow cursor slide trails the finger instead of
        /// painting its entire route.
        static let visibleDuration: TimeInterval = 0.55

        /// How long the frozen trail takes to fade out after the finger lifts.
        static let fadeOutDuration: TimeInterval = 0.22

        /// Head width as a fraction of the row height, so the trail scales
        /// with the user's key size instead of overwhelming small keyboards.
        static let widthFraction: CGFloat = 0.16

        /// Clamps for the scaled head width.
        static let minWidth: CGFloat = 5
        static let maxWidth: CGFloat = 14

        /// Exponent of the tail taper: `width = headWidth * progress^exponent`
        /// with `progress` running 0 (tail) → 1 (finger). `headWidth` is the
        /// per-render width from `GestureTrailOverlay.headWidth(for:)`, not
        /// the `maxWidth` clamp above. Below 1 the ribbon reaches nearly full
        /// width early and thins only near its very end, which is what makes
        /// the system trail read as a stroke rather than a wedge.
        static let taperExponent: CGFloat = 0.55

        /// Length of the tapered tail, as a multiple of the head width.
        ///
        /// The taper is measured along the path rather than as a fraction of
        /// it, so a long cursor slide keeps a constant-width stroke with a
        /// short tapered tail instead of stretching into one long wedge. A
        /// path shorter than this simply tapers across its whole length.
        static let taperLengthFactor: CGFloat = 3.5

        /// Catmull-Rom segments inserted between two recorded samples. A fast
        /// flick only produces a handful of samples before it ends — without
        /// interpolation those would draw as a visible polyline.
        static let smoothingSubdivisions: Int = 6

        /// Opacity of the ribbon. Translucent enough to keep the key labels
        /// underneath readable while the finger passes over them.
        static let opacity: Double = 0.38
    }

    // MARK: - Long Press

    enum LongPress {
        /// How long the finger must rest on a key before a long press fires.
        /// Deliberately above UIKit's 0.5s default: hesitating mid-word is
        /// common on a gesture keyboard, and an accidental digit is worse
        /// than a slightly slower intentional one (tuned on device).
        static let duration: TimeInterval = 0.7

        /// Maximum travel from touch-down before a pending long press is
        /// cancelled. Matches `UILongPressGestureRecognizer.allowableMovement`
        /// so natural finger wobble doesn't cancel the hold, while anything
        /// resembling a swipe does.
        static let movementTolerance: CGFloat = 10
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

        /// Minimum upward travel to classify a vertical space-bar swipe
        /// (label-visibility toggle). Mirrors `Gesture.minSwipeLength` so the
        /// space bar demands the same commitment as a key swipe.
        static let swipeUpActivationThreshold: CGFloat = Gesture.minSwipeLength
    }

    // MARK: - Delete Key Gestures

    enum DeleteGestures {
        /// Minimum drag distance to activate delete-drag mode.
        static let dragActivationThreshold: CGFloat = 8

        /// Distance to activate slide-delete (continuous deletion).
        static let slideActivationThreshold: CGFloat = 28

        /// Distance per deletion step during slide-delete (one character).
        /// Decoupled from `SpaceGestures.dragStep` so delete and cursor
        /// sensitivity can be tuned independently.
        static let dragStep: CGFloat = 14

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

    // MARK: - Text Input

    enum TextInput {
        /// Maximum size of a pasted string in UTF-16 code units (~200 KB as
        /// NSString storage). The pasteboard is the one unbounded external
        /// input in the jetsam-constrained keyboard extension; longer text is
        /// silently truncated at a grapheme boundary before insertion.
        static let maxPasteUTF16Length = 200_000
    }

    // MARK: - Preview Settings

    enum Preview {
        /// Minimum height for keyboard preview in settings.
        static let minHeight: CGFloat = 100
        /// Maximum height for keyboard preview in settings.
        static let maxHeight: CGFloat = 400

        /// Frame height for the settings preview given the rendered keyboard's
        /// content height. Applies only the lower bound — there is deliberately
        /// no upper cap, so the preview grows to match the real keyboard
        /// exactly (which lays out at its content height with no upper clamp)
        /// instead of clipping tall content.
        static func frameHeight(forContentHeight contentHeight: CGFloat) -> CGFloat {
            max(minHeight, contentHeight)
        }
    }

    // MARK: - Keyboard Calculations

    enum Calculations {
        /// Calculates the adjusted key height based on aspect ratio
        static func keyHeight(aspectRatio: CGFloat) -> CGFloat {
            KeyDimensions.height * (KeyDimensions.referenceAspectRatio / aspectRatio)
        }

        /// Keyboard width at which the grid's cells come out exactly
        /// `cellSize` wide. Under the point-anchored metrics, square cells
        /// are simply `keyAspectRatio == 1.0`, so this only converts a
        /// desired cell size into the outer keyboard width (cells + gaps +
        /// paddings). Used by the App Store screenshot mode to reproduce the
        /// square marketing look at the full reference key height.
        static func squareKeyboardWidth(cellSize: CGFloat, columns: Int) -> CGFloat {
            // Cells plus the constant horizontal chrome (paddings + column
            // gaps). Shares `horizontalChrome` with the metrics resolver so the
            // two can never diverge if the per-side padding model changes.
            (cellSize * CGFloat(columns)) +
                KeyboardLayoutMetrics.horizontalChrome(columns: columns)
        }
    }
}
