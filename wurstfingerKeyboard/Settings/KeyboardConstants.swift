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

        /// Corner radius for modern iOS appearance.
        /// Matches iOS 15+ system keyboard style.
        static let cornerRadius: CGFloat = 8

        /// Reference key aspect ratio (width/height) at which `height` is defined.
        /// Used only as the baseline of `Calculations.screenshotCellSize`; it is NOT
        /// the user-facing default setting (that is `DeviceLayout.defaultKeyAspectRatio`).
        static let referenceAspectRatio: CGFloat = 1.5

        /// Total number of rows in the keyboard layout.
        /// 3 rows for main keys + 1 row for space bar = 4 rows.
        static let totalRows: Int = 4
    }

    // MARK: - Font Sizes

    enum FontSizes {
        /// Default label size for utility buttons.
        static let defaultLabel: CGFloat = 18

        /// Utility column label size (globe, delete, return).
        static let utilityLabel: CGFloat = 22

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
        /// Reference font size for hint padding calculations.
        static let hintReferenceFontSize: CGFloat = 10

        /// Largest share of the rendered cell width a main label may occupy.
        /// The readability floors above are a wish, not a guarantee: at the
        /// smallest keyboard width a cell is ~14 pt wide, where the 20 pt floor
        /// draws a glyph across its neighbours. Because the aspect-ratio
        /// setting never goes below 1.0, this cap sits above the proportional
        /// size for every cell wide enough to honour the floor — so it only
        /// ever cuts the floor, never the normal scaling.
        static let mainLabelMaxCellFraction: CGFloat = 0.5

        /// Same cap for the directional hints, which sit three across a row
        /// (top-leading / top / top-trailing) and so may claim under a third
        /// of the cell each.
        static let hintMaxCellFraction: CGFloat = 0.3

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
    }

    // MARK: - Gesture Recognition

    enum Gesture {
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

    /// Tuning for the optional gesture trail drawn under the finger.
    ///
    /// A soft ribbon, widest at the finger and tapering to a point at its
    /// tail, kept short so it reads as a comet tail rather than a drawing of
    /// the whole path.
    enum GestureTrail {
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
        /// Tuned on device: 0.22 read as an abrupt blink once the press dot
        /// made single keystrokes draw; the longer glow lets the mark register
        /// without lagging behind fast typing.
        static let fadeOutDuration: TimeInterval = 0.35

        /// Head width as a fraction of the row height, so the trail scales
        /// with the user's key size instead of overwhelming small keyboards.
        static let widthFraction: CGFloat = 0.16

        /// Clamps for the scaled head width.
        static let minWidth: CGFloat = 5
        static let maxWidth: CGFloat = 14

        /// Diameter of the press dot, as a multiple of the head width.
        ///
        /// Slightly wider than the ribbon's head so both carry a comparable
        /// amount of ink: a swipe spreads its mark along the whole path, while
        /// a press has nothing but the dot. At 1.0 the dot reads as a smudge
        /// next to the key label; much beyond this it starts to swamp it.
        static let pressDotWidthFactor: CGFloat = 1.4

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

        /// Distance per cursor movement step (one character).
        /// Provides smooth, controlled cursor navigation.
        static let dragStep: CGFloat = 14

        /// Maximum ratio of final displacement to peak displacement for a return swipe.
        /// Below this threshold, the gesture is classified as a return swipe (word movement).
        static let returnSwipeThreshold: CGFloat = 0.3

        /// Minimum upward travel to classify a vertical space-bar swipe
        /// (label-visibility toggle). Deliberately above the classifier's
        /// swipe-vs-tap boundary (`GestureClassificationThresholds`
        /// `.defaultMinSwipeLength`, 20pt): the space bar lies under the
        /// thumbs and collects incidental upward drift, so the toggle asks for
        /// a longer, more deliberate flick.
        static let swipeUpActivationThreshold: CGFloat = 30
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
    }

    // MARK: - Text Input

    enum TextInput {
        /// Maximum size of a pasted string in UTF-16 code units (~200 KB as
        /// NSString storage). The pasteboard is the one unbounded external
        /// input in the jetsam-constrained keyboard extension; longer text is
        /// silently truncated at a grapheme boundary before insertion.
        static let maxPasteUTF16Length = 200_000

        /// How long after a space press a second one still reads as a double
        /// space. Without a window every space typed behind an existing
        /// "word + space" is rewritten — hours later, or after the caret moved
        /// back into an old sentence — and a deliberate double space becomes
        /// untypable while the shortcut is on. Deliberately longer than a UIKit
        /// double tap: two spaces on a gesture keyboard are a typing rhythm,
        /// not a double tap.
        static let doubleSpacePeriodWindow: TimeInterval = 1.1
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
        /// Cell size the App Store screenshots render at: the reference key
        /// height at the reference aspect ratio. A marketing constant, not a
        /// layout value — the rendered cell comes from `KeyboardLayoutMetrics`.
        static let screenshotCellSize: CGFloat = KeyDimensions.height * KeyDimensions.referenceAspectRatio

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
