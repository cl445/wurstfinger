//
//  GesturePreprocessor.swift
//  Wurstfinger
//
//  Gesture Recognition Pipeline
//  ============================
//
//  This module implements gesture preprocessing and feature extraction for
//  distinguishing between taps, swipes, return-swipes, and circular gestures.
//
//  ## Data Flow
//
//  ```
//  Touch Events (KeyView)
//       │
//       ▼
//  Raw CGPoint[] ──► GesturePreprocessor.preprocess()
//       │                    │
//       │              ┌─────┴─────┐
//       │              ▼           ▼
//       │         filterJitter  filterOutliers
//       │              │           │
//       │              ▼           ▼
//       │         normalizeAspectRatio
//       │              │
//       │              ▼
//       │         smoothSavitzkyGolay
//       │              │
//       ▼              ▼
//  Cleaned CGPoint[] ──► GestureFeatures.extract()
//       │
//       ▼
//  GestureFeatures { pathLength, maxDisplacement, angularSpan, ... }
//       │
//       ▼
//  Classification: isTap, isReturn, isCircular, direction
//  ```
//
//  ## Preprocessing Steps
//
//  1. **Jitter Filter**: Removes points too close together (< jitterThreshold)
//     - Prevents noise from finger micro-movements
//
//  2. **Outlier Filter**: Removes isolated impossible jumps (> maxJumpDistance)
//     - Handles touch glitches and multitouch interference
//     - Keeps points consistent with a raw neighbor, so a single dropped-frame
//       gap cannot cascade and discard the rest of a genuine fast swipe
//     - Velocity-aware: a jump that continues the movement the finger was
//       already making — same direction to within 45°, at most three times
//       the reference step (the longer of the step the accepted path
//       established and the raw step the jump leads into) and never beyond
//       3x maxJumpDistance — is kept, so a flick covering more than
//       maxJumpDistance per sample is not read as a teleport
//
//  3. **Aspect Ratio Normalization**: Divides X by aspect ratio
//     - Makes horizontal and vertical movements comparable on non-square keys
//
//  4. **Savitzky-Golay Smoothing**: Polynomial smoothing filter
//     - Preserves gesture shape while reducing noise
//     - Uses pre-computed coefficients for efficiency
//
//  ## Feature Extraction
//
//  Geometric features extracted from the cleaned path:
//  - `pathLength`: Total distance traveled
//  - `chordLength`: Direct distance from start to end
//  - `maxDisplacement`: Furthest point from start
//  - `maxDisplacementProgress`: Where in path (0-1) max occurred
//  - `returnRatio`: chordLength / pathLength (low = returned to start)
//  - `angularSpan`: Total angle swept around centroid (radians)
//  - `circularity`: How uniform the radii are (0-1)
//  - `pathSeparation`: Distance between mirrored points (early vs late)
//
//  ## Classification Logic
//
//  - **Tap**: maxDisplacement < minSwipeLength (20pt by default)
//  - **Return-swipe**: returnRatio < 0.5 AND maxDisplacement in middle of path
//  - **Circular**: angularSpan > 270° AND consistent turn direction AND enough
//    oriented compactness (a circle, not a narrow arc)
//  - **Swipe**: Everything else, direction from maxDisplacementAngle
//
//  Note: minSwipeLength is an absolute distance, so its share of the key
//  depends on the user's size setting — 20pt is about a third of the ~58pt
//  key height the layout metrics resolve at the default width.
//
//  ## Key Insight: Spiral vs Return-Swipe
//
//  Both can have high angularSpan, but:
//  - Spiral: Early points (start) far from late points (end) → high pathSeparation
//  - Return: Path comes back, early ≈ late points → low pathSeparation
//

import CoreGraphics
import Foundation

// MARK: - Configuration

struct GesturePreprocessorConfig {
    /// Minimum distance between consecutive points (jitter threshold)
    let jitterThreshold: CGFloat
    /// Maximum jump distance to consider valid (outlier threshold)
    let maxJumpDistance: CGFloat
    /// Window size for Savitzky-Golay filter (must be odd)
    let smoothingWindow: Int
    /// Polynomial order for Savitzky-Golay filter
    let smoothingOrder: Int
    /// Aspect ratio of the key (width/height) for normalizing coordinates
    let aspectRatio: CGFloat

    // MARK: - Default Values

    static let defaultJitterThreshold: CGFloat = 3.0
    static let defaultMaxJumpDistance: CGFloat = 50.0
    static let defaultSmoothingWindow: Int = 5

    // MARK: - Value Ranges

    /// The ranges the Expert UI offers, shared with the loaders below so a
    /// stale or foreign store value (an older build's range, a hand-written
    /// default) is clamped instead of reaching the pipeline.
    static let jitterThresholdRange: ClosedRange<Double> = 1 ... 10
    static let maxJumpDistanceRange: ClosedRange<Double> = 20 ... 100
    /// Upper bound is odd on purpose: the loader rounds even windows up.
    static let smoothingWindowRange: ClosedRange<Int> = 3 ... 11

    // MARK: - UserDefaults Keys

    static let jitterThresholdKey = "gesture.jitterThreshold"
    static let maxJumpDistanceKey = "gesture.maxJumpDistance"
    static let smoothingWindowKey = "gesture.smoothingWindow"

    static let `default` = GesturePreprocessorConfig(
        jitterThreshold: defaultJitterThreshold,
        maxJumpDistance: defaultMaxJumpDistance,
        smoothingWindow: defaultSmoothingWindow,
        smoothingOrder: 2,
        aspectRatio: 1.0
    )

    /// Loads config from SharedDefaults with fallback to defaults.
    /// Non-finite values (NaN, Inf) are replaced with defaults, out-of-range
    /// ones clamped to the Expert range.
    /// Custom values only apply while expert mode is enabled; when it is off,
    /// the defaults are returned. The stored values are kept so they survive
    /// toggling expert mode off and on again.
    static func fromUserDefaults(store: UserDefaults = SharedDefaults.store) -> GesturePreprocessorConfig {
        guard store.bool(forKey: SettingsKey.expertModeEnabled.rawValue) else { return .default }
        let jitter = clampedCGFloat(
            from: store, key: jitterThresholdKey,
            default: defaultJitterThreshold, range: jitterThresholdRange
        )
        let maxJump = clampedCGFloat(
            from: store, key: maxJumpDistanceKey,
            default: defaultMaxJumpDistance, range: maxJumpDistanceRange
        )
        return GesturePreprocessorConfig(
            jitterThreshold: jitter,
            maxJumpDistance: maxJump,
            smoothingWindow: validSmoothingWindow(from: store),
            smoothingOrder: 2,
            aspectRatio: 1.0
        )
    }

    /// Reads smoothingWindow from defaults, clamped to the Expert range and
    /// forced to an odd width (the Savitzky-Golay window must be centred).
    private static func validSmoothingWindow(from store: UserDefaults) -> Int {
        let raw = store.object(forKey: smoothingWindowKey) as? Int ?? defaultSmoothingWindow
        let clamped = min(max(raw, smoothingWindowRange.lowerBound), smoothingWindowRange.upperBound)
        return clamped.isMultiple(of: 2) ? clamped + 1 : clamped
    }

    /// Loads a CGFloat from the store, clamped to `range`. A missing key or a
    /// NaN/Inf value falls back to `defaultValue`.
    private static func clampedCGFloat(
        from store: UserDefaults,
        key: String,
        default defaultValue: CGFloat,
        range: ClosedRange<Double>
    ) -> CGFloat {
        guard store.object(forKey: key) != nil else { return defaultValue }
        let value = store.double(forKey: key)
        guard value.isFinite else { return defaultValue }
        return CGFloat(min(max(value, range.lowerBound), range.upperBound))
    }

    /// Creates a config with custom aspect ratio.
    /// Non-finite or non-positive values (the ratio reaches this via a raw
    /// `@AppStorage` read) fall back to 1.0 — `normalizeAspectRatio` divides
    /// by the ratio, and dividing by zero/NaN would poison the whole pipeline
    /// so that every gesture classifies as `.swipeRight`.
    func with(aspectRatio: CGFloat) -> GesturePreprocessorConfig {
        GesturePreprocessorConfig(
            jitterThreshold: jitterThreshold,
            maxJumpDistance: maxJumpDistance,
            smoothingWindow: smoothingWindow,
            smoothingOrder: smoothingOrder,
            aspectRatio: aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1.0
        )
    }
}

// MARK: - Gesture Preprocessor

struct GesturePreprocessor {
    let config: GesturePreprocessorConfig

    init(config: GesturePreprocessorConfig = .default) {
        self.config = config
    }

    /// Main preprocessing pipeline
    func preprocess(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        // Step 1: Jitter filter
        let dejittered = filterJitter(points)

        // Step 2: Outlier filter
        let cleaned = filterOutliers(dejittered)

        // Step 3: Aspect ratio correction (normalize horizontal movement)
        let normalized = normalizeAspectRatio(cleaned)

        // Step 4: Savitzky-Golay smoothing
        return smoothSavitzkyGolay(normalized)
    }

    // MARK: - Step 1: Jitter Filter

    /// Removes points that are too close to the previous point
    func filterJitter(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var filtered: [CGPoint] = [points[0]]

        for i in 1 ..< points.count {
            // Safe: filtered always has at least one element (initialized with points[0])
            guard let last = filtered.last else { continue }
            let current = points[i]

            if current.distance(to: last) >= config.jitterThreshold {
                filtered.append(current)
            }
        }

        // Always include the last point if different from current last
        if let lastInput = points.last,
           let lastFiltered = filtered.last,
           lastInput.distance(to: lastFiltered) >= 0.1 {
            filtered.append(lastInput)
        }

        return filtered
    }

    // MARK: - Step 2: Outlier Filter

    /// Removes points with physically impossible jumps.
    ///
    /// A point is an outlier only when it is farther than `maxJumpDistance`
    /// from the last accepted point AND from both of its raw neighbors.
    /// Comparing solely against the last accepted point would cascade: one
    /// dropped-frame gap leaves the anchor stuck before the gap, so every
    /// later sample of a genuine fast swipe (or of a re-anchored long drag
    /// whose retained window sits far from the origin) would be discarded
    /// too. Consistency with a raw neighbor proves real motion; the ceiling
    /// below is what stops a ghost cluster from vouching for itself.
    ///
    /// Those criteria all measure *where* a sample landed. The last one
    /// measures *how the finger got there*, and it is the only evidence that
    /// separates the two cases this filter has to tell apart — a touch glitch
    /// and a violent flick land in the same place, but the glitch appears out
    /// of a near-stationary path while the flick is preceded by a finger
    /// already covering that ground every sample. Without it a fling faster
    /// than `maxJumpDistance` per sample had *every* sample discarded and
    /// committed the key's center letter, while the gesture trail — which
    /// draws the raw path — showed the full swipe (review 2026-08-09,
    /// finding 3).
    ///
    /// Accepting a point moves the anchor onto it, so a glitch let in here is
    /// paid for twice: the genuine sample after it is then measured from the
    /// glitch and can fail every criterion. That is why `isSameMovement` is
    /// deliberately narrow — a jump has to continue the reference direction to
    /// within 45° and stay inside three times the reference step.
    ///
    /// The one shape it cannot resolve is a burst of consistently-moving
    /// interference: two samples travelling coherently at flick speed arrive
    /// byte-identical to a finger that accelerated into a flick. How long the
    /// finger rested first would separate them, but the jitter filter has
    /// already collapsed that dwell by the time this filter runs. Because
    /// `continuesEstablishedMotion` takes the longer of its two candidate
    /// references, the ambiguity is uniform along the path instead of confined
    /// to the origin — deliberately, since the established step is no evidence
    /// against a real flick either. Both are accepted; what bounds the damage
    /// is the magnitude ceiling and the direction cone in `isSameMovement`,
    /// not the shape. Separating them needs the pipeline order changed (or the
    /// trail clamped to post-filter samples), which is the structural half of
    /// finding 3 and is not attempted here.
    func filterOutliers(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var filtered: [CGPoint] = [points[0]]
        // Step between the two most recently accepted samples — the velocity
        // the accepted path has established so far. Nil while the origin is
        // the entire accepted path.
        var acceptedStep: CGVector?

        for i in 1 ..< points.count {
            // Safe: filtered always has at least one element (initialized with points[0])
            guard let lastAccepted = filtered.last else { continue }
            let current = points[i]

            let step = CGVector(dx: current.x - lastAccepted.x, dy: current.y - lastAccepted.y)
            let distanceToAccepted = current.distance(to: lastAccepted)
            let nearAccepted = distanceToAccepted <= config.maxJumpDistance
            let nearRawPrevious = current.distance(to: points[i - 1]) <= config.maxJumpDistance
            let nearRawNext = i + 1 < points.count &&
                current.distance(to: points[i + 1]) <= config.maxJumpDistance

            // Raw-neighbor support alone can be bootstrapped by a clustered
            // glitch burst: two mutually close ghost points admit each other.
            // Support therefore only counts while the point stays within a
            // plausibility ceiling of the accepted path, unless it belongs to
            // a sustained run of mutually consistent samples (a re-anchored
            // long drag or a genuine post-gap tail keeps moving; a ghost
            // cluster does not).
            let ceiling = config.maxJumpDistance * Self.plausibilityCeilingFactor
            let supportIsPlausible = distanceToAccepted <= ceiling
                || consistentRunLength(in: points, at: i) >= Self.sustainedRunMinimumLength

            if nearAccepted
                || ((nearRawPrevious || nearRawNext) && supportIsPlausible)
                || continuesEstablishedMotion(step, after: acceptedStep, in: points, at: i) {
                filtered.append(current)
                acceptedStep = step
            }
            // Isolated or clustered outlier: skip — and leave `acceptedStep`
            // alone, so a rejected glitch never raises the velocity that would
            // admit the next one. An *accepted* one cannot either: the
            // reference is capped in `isSameMovement`.
        }

        return filtered
    }

    /// Raw-neighbor support only counts within this multiple of
    /// `maxJumpDistance` from the accepted path; farther points need a
    /// sustained run instead.
    private static let plausibilityCeilingFactor: CGFloat = 3

    /// A run of at least this many mutually consistent samples counts as
    /// sustained real motion regardless of distance from the accepted path.
    private static let sustainedRunMinimumLength = 3

    /// Length of the run of mutually consistent raw samples containing
    /// index `i` (consecutive neighbors within `maxJumpDistance`).
    private func consistentRunLength(in points: [CGPoint], at i: Int) -> Int {
        var length = 1
        var backward = i
        while backward > 0,
              points[backward].distance(to: points[backward - 1]) <= config.maxJumpDistance {
            length += 1
            backward -= 1
        }
        var forward = i
        while forward + 1 < points.count,
              points[forward].distance(to: points[forward + 1]) <= config.maxJumpDistance {
            length += 1
            forward += 1
        }
        return length
    }

    /// A jump may be this multiple of the step the finger was already
    /// covering — itself capped at `maxJumpDistance`, see `isSameMovement` —
    /// and still count as the same movement.
    ///
    /// Sized against the two regimes it separates. The rule only ever runs for
    /// jumps beyond `maxJumpDistance`, so the reference step is already a
    /// third of that (≈17 pt per sample at the default — a finger crossing two
    /// key heights in about six frames) before anything can be accepted at
    /// all. The cap is what keeps the number meaning something: an accepted
    /// jump becomes the next sample's reference, so without it every
    /// admission would triple the allowance for the one after it and a chain
    /// of ever-longer jumps would walk itself off the key. With it the rule
    /// can never admit more than 3 × `maxJumpDistance` — 150 pt per sample at
    /// the default, ≈1.4 m/s at 60 Hz, about three times the fling it exists
    /// for.
    private static let velocityToleranceFactor: CGFloat = 3

    /// How far a jump may turn away from the reference direction and still
    /// count as the same movement, as a cosine: 45° of *raw* screen turn.
    ///
    /// That is one swipe sector only on square keys. This test runs before
    /// `normalizeAspectRatio`, while the classifier's 45° sectors are measured
    /// after it, so the widest admitted turn opens up with the key's aspect
    /// ratio: 45° raw is 46.7° normalized at the 1.06:1 keys the extension
    /// renders, 52.4° at 1.3:1 and 63.4° at 2:1. Testing direction
    /// post-normalization would close that gap, but it is a behavior change
    /// and not a comment fix, so the number stated here is the raw one.
    ///
    /// A finger that crosses a key in a single frame does not also change
    /// direction in it. The half-plane this replaced — any angle short of a
    /// right angle — admitted a near-perpendicular jump at three times the
    /// reference step, which flipped the committed direction of ordinary fast
    /// swipes carrying one trailing glitch sample (review 2026-08-09).
    private static let minimumDirectionCosine = CGFloat(cos(Double.pi / 4))

    /// Whether the jump onto `points[i]` continues the movement the finger was
    /// already making.
    ///
    /// Two steps can speak for the jump: the one the accepted path has
    /// established (`previousStep`) and the raw one that leads away from
    /// `points[i]`. The reference is whichever of the two is longer.
    ///
    /// Letting the established step win whenever it exists — the rule this
    /// replaced — loses every flick that launches out of a rolling start, a
    /// finger that settles on the key with a slow drift and only then flicks.
    /// The drift establishes a step of a few points, the first fast sample is
    /// more than three times it, and because a rejected sample leaves the
    /// anchor and the reference alone, every sample after it fails the same
    /// way: the classifier only ever sees the drift. Measured over three drift
    /// samples followed by three 80 pt flick samples at the default config,
    /// that starts at roughly 1 pt per sample of drift — below it the jitter
    /// filter still collapses the drift — and never stops. What gets committed
    /// is the key's center letter while the drift is shorter than
    /// `minSwipeLength`, and from about 8 pt per sample a swipe in the
    /// *drift's* direction: a drift running across the flick therefore types a
    /// different letter than the one the finger drew, at any drift rate, since
    /// the cone rejects the turn from drift into flick however fast the drift
    /// was. Taking the longer step fixes the whole band — the flick's own
    /// following step vouches for its first sample.
    ///
    /// Before there is an established step at all — the first sample after
    /// touch-down, where the whole accepted path is the origin — the following
    /// raw step is the only evidence there is anyway: a finger that lands
    /// already moving keeps moving at a comparable rate, whereas a glitch
    /// lands once and stops.
    ///
    /// A trailing jump has no following step, so it is judged against
    /// `previousStep` alone, and only when the accepted path is still just the
    /// origin does it have no evidence at all and stay an outlier. What keeps
    /// a glitch at the end of a tap out is therefore how far it jumped, not
    /// where it sits in the path: a tap establishes a step of a few points and
    /// `isSameMovement` allows three times that, while the glitch is beyond
    /// `maxJumpDistance`. A finger already travelling `maxJumpDistance`/3 per
    /// sample does carry a trailing jump in — deliberately, since the last
    /// sample of a genuine flick is itself one.
    ///
    /// What the longer reference costs is that the origin's ambiguity now
    /// applies along the whole path rather than only at touch-down: two
    /// spurious samples travelling coherently at flick speed are
    /// byte-identical to a finger accelerating into one, and mid-path the
    /// established step used to refuse them. That refusal was never evidence —
    /// a rolling start *is* a slow step followed by a fast one — so the two
    /// cases cannot be told apart here either way. The shapes this filter was
    /// actually built against are unaffected: a ghost cluster's own step is a
    /// few points, so it establishes no reference to ride in on, and an
    /// out-and-back teleport is opposed to both candidate references and fails
    /// the cone. See `filterOutliers` for what bounds the residue.
    private func continuesEstablishedMotion(
        _ step: CGVector,
        after previousStep: CGVector?,
        in points: [CGPoint],
        at i: Int
    ) -> Bool {
        guard let reference = longerStep(previousStep, followingRawStep(in: points, at: i)) else {
            return false
        }
        return isSameMovement(reference, step)
    }

    /// Whichever of the two candidate references is longer, or the only one
    /// that exists. Nil when neither does — a trailing sample on a path whose
    /// accepted part is still just the origin.
    private func longerStep(_ first: CGVector?, _ second: CGVector?) -> CGVector? {
        guard let first else { return second }
        guard let second else { return first }
        return hypot(first.dx, first.dy) >= hypot(second.dx, second.dy) ? first : second
    }

    /// The raw step leading away from `points[i]`, or nil when it is the last
    /// sample.
    private func followingRawStep(in points: [CGPoint], at i: Int) -> CGVector? {
        guard i + 1 < points.count else { return nil }
        return CGVector(dx: points[i + 1].x - points[i].x, dy: points[i + 1].y - points[i].y)
    }

    /// Two steps belong to one movement when they point the same way to within
    /// `minimumDirectionCosine` and the second does not explode in length.
    ///
    /// The direction test is what rejects an out-and-back teleport, whose two
    /// steps are both long but opposed — a shape that a magnitude comparison
    /// alone would happily accept — and, as a cone rather than a half-plane,
    /// the sideways glitch: past a 45° turn the accepted sample pulls the
    /// max-displacement angle far enough that the swipe can commit out of the
    /// sector the finger was travelling towards.
    ///
    /// The reference is capped at `maxJumpDistance` so that a jump this rule
    /// admits cannot raise the allowance for the next one. A zero-length
    /// reference establishes no direction; the guard says so rather than
    /// leaning on the magnitude test, which happens to reject it too because a
    /// zero budget admits no step.
    ///
    /// The corroboration this asks for is the inverse of the rule it replaced,
    /// and the trade is deliberate. The old filter wanted a raw neighbor
    /// within `maxJumpDistance` and ignored direction; this one wants
    /// direction and ignores neighbors, so a single sample inside the cone is
    /// now trusted on its own evidence. That is what buys the flick rescue,
    /// and it is paid for at the cone's edge: a fast swipe with a short prefix
    /// carrying one trailing glitch just inside 45° commits the neighbouring
    /// sector where the old filter kept the right one — measured at 3 of 960
    /// swept shapes, e.g. two 45 pt steps followed by 120 pt at 40°, which
    /// commits `swipeDownRight` instead of `swipeRight`. A tighter cone would
    /// buy that class back and lose flick rescues in exchange, so the angle
    /// stays where it is; this is a choice about `minimumDirectionCosine`, not
    /// a defect to patch here.
    private func isSameMovement(_ reference: CGVector, _ step: CGVector) -> Bool {
        let referenceLength = hypot(reference.dx, reference.dy)
        let stepLength = hypot(step.dx, step.dy)
        let budget = min(referenceLength, config.maxJumpDistance)
        guard budget > 0, stepLength <= budget * Self.velocityToleranceFactor else { return false }
        return reference.dx * step.dx + reference.dy * step.dy
            >= Self.minimumDirectionCosine * referenceLength * stepLength
    }

    // MARK: - Step 3: Aspect Ratio Normalization

    /// Normalizes points for non-square aspect ratio
    /// Divides X by aspect ratio so horizontal movement equals vertical movement
    func normalizeAspectRatio(_ points: [CGPoint]) -> [CGPoint] {
        guard config.aspectRatio != 1.0 else { return points }
        return points.map { point in
            CGPoint(x: point.x / config.aspectRatio, y: point.y)
        }
    }

    // MARK: - Step 4: Savitzky-Golay Smoothing

    /// Applies Savitzky-Golay filter to smooth the path while preserving shape
    func smoothSavitzkyGolay(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= config.smoothingWindow else { return points }

        let coefficients = savitzkyGolayCoefficients(
            windowSize: config.smoothingWindow,
            polyOrder: config.smoothingOrder
        )

        let halfWindow = config.smoothingWindow / 2
        var smoothed: [CGPoint] = []

        for i in 0 ..< points.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0

            for j in 0 ..< config.smoothingWindow {
                let idx = i - halfWindow + j
                let clampedIdx = max(0, min(points.count - 1, idx))
                sumX += coefficients[j] * points[clampedIdx].x
                sumY += coefficients[j] * points[clampedIdx].y
            }

            smoothed.append(CGPoint(x: sumX, y: sumY))
        }

        return smoothed
    }

    /// Calculates Savitzky-Golay convolution coefficients
    private func savitzkyGolayCoefficients(windowSize: Int, polyOrder: Int) -> [CGFloat] {
        // Pre-computed coefficients for common cases
        // Window=5, Order=2: [-3, 12, 17, 12, -3] / 35
        // Window=7, Order=2: [-2, 3, 6, 7, 6, 3, -2] / 21

        if windowSize == 5 && polyOrder <= 3 {
            return [-3, 12, 17, 12, -3].map { CGFloat($0) / 35.0 }
        } else if windowSize == 7 && polyOrder <= 3 {
            return [-2, 3, 6, 7, 6, 3, -2].map { CGFloat($0) / 21.0 }
        } else if windowSize == 9 && polyOrder <= 3 {
            return [-21, 14, 39, 54, 59, 54, 39, 14, -21].map { CGFloat($0) / 231.0 }
        } else if windowSize == 11 && polyOrder <= 3 {
            return [-36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36].map { CGFloat($0) / 429.0 }
        }

        // Fallback: uniform weights (simple moving average)
        return Array(repeating: CGFloat(1.0 / Double(windowSize)), count: windowSize)
    }
}

// MARK: - Classification Thresholds

struct GestureClassificationThresholds {
    /// Minimum path length to be considered a swipe (not a tap)
    let minSwipeLength: CGFloat
    /// Maximum return ratio to be considered a return-swipe
    let maxReturnRatio: CGFloat
    /// Range where maxDisplacement should occur for return-swipe (as % of path)
    let returnDisplacementRange: ClosedRange<CGFloat>
    /// Minimum circularity score to be considered circular
    let minCircularity: CGFloat
    /// Minimum angular span (radians) to be considered circular
    let minAngularSpan: CGFloat
    /// Minimum path separation to distinguish spiral from return-swipe
    let minPathSeparation: CGFloat
    /// Minimum turn consistency to be considered circular (1.0 = all same direction)
    let minTurnConsistency: CGFloat
    /// Minimum oriented compactness (width/length) to be considered circular (1.0 = square, 0 = line)
    let minOrientedCompactness: CGFloat

    // MARK: - Default Values

    static let defaultMinSwipeLength: CGFloat = 20
    static let defaultMaxReturnRatio: CGFloat = 0.5
    static let defaultReturnDisplacementStart: CGFloat = 0.2
    static let defaultReturnDisplacementEnd: CGFloat = 0.8
    static let defaultMinCircularity: CGFloat = 0.3
    static let defaultMinAngularSpan: CGFloat = .pi * 1.5 // 270°
    static let defaultMinPathSeparation: CGFloat = 0.5
    static let defaultMinTurnConsistency: CGFloat = 0.8 // 80% turns in same direction
    static let defaultMinOrientedCompactness: CGFloat = 0.4 // width must be at least 40% of length

    // MARK: - Value Ranges

    /// The ranges the Expert UI offers, shared with the loader below so a
    /// stale or foreign store value (an older build's range, a hand-written
    /// default) is clamped instead of reaching classification.
    static let minSwipeLengthRange: ClosedRange<Double> = 10 ... 60
    static let maxReturnRatioRange: ClosedRange<Double> = 0.2 ... 0.8
    static let returnDisplacementStartRange: ClosedRange<Double> = 0.1 ... 0.4
    static let returnDisplacementEndRange: ClosedRange<Double> = 0.6 ... 0.9
    static let minCircularityRange: ClosedRange<Double> = 0.1 ... 0.7
    static let minAngularSpanRange: ClosedRange<Double> = .pi ... (2 * .pi)
    static let minTurnConsistencyRange: ClosedRange<Double> = 0.5 ... 1.0
    static let minOrientedCompactnessRange: ClosedRange<Double> = 0.2 ... 0.8
    /// No Expert control (the circular branch does not read it); clamped to
    /// the ratio's meaningful band so a stored value cannot be nonsense.
    static let minPathSeparationRange: ClosedRange<Double> = 0 ... 1

    // MARK: - UserDefaults Keys

    static let minSwipeLengthKey = "gesture.minSwipeLength"
    static let maxReturnRatioKey = "gesture.maxReturnRatio"
    static let returnDisplacementStartKey = "gesture.returnDisplacementStart"
    static let returnDisplacementEndKey = "gesture.returnDisplacementEnd"
    static let minCircularityKey = "gesture.minCircularity"
    static let minAngularSpanKey = "gesture.minAngularSpan"
    static let minPathSeparationKey = "gesture.minPathSeparation"
    static let minTurnConsistencyKey = "gesture.minTurnConsistency"
    static let minOrientedCompactnessKey = "gesture.minOrientedCompactness"

    static let `default` = GestureClassificationThresholds(
        minSwipeLength: defaultMinSwipeLength,
        maxReturnRatio: defaultMaxReturnRatio,
        returnDisplacementRange: defaultReturnDisplacementStart ... defaultReturnDisplacementEnd,
        minCircularity: defaultMinCircularity,
        minAngularSpan: defaultMinAngularSpan,
        minPathSeparation: defaultMinPathSeparation,
        minTurnConsistency: defaultMinTurnConsistency,
        minOrientedCompactness: defaultMinOrientedCompactness
    )

    /// Loads a CGFloat from UserDefaults, clamped to `range`. A missing key or
    /// a NaN/Inf value falls back to `defaultValue`.
    private static func clampedCGFloat(
        from store: UserDefaults,
        key: String,
        default defaultValue: CGFloat,
        range: ClosedRange<Double>
    ) -> CGFloat {
        guard store.object(forKey: key) != nil else { return defaultValue }
        let value = store.double(forKey: key)
        guard value.isFinite else { return defaultValue }
        return CGFloat(min(max(value, range.lowerBound), range.upperBound))
    }

    /// Loads thresholds from SharedDefaults with fallback to defaults.
    /// Custom values only apply while expert mode is enabled; when it is off,
    /// the defaults are returned. The stored values are kept so they survive
    /// toggling expert mode off and on again.
    static func fromUserDefaults(store: UserDefaults = SharedDefaults.store) -> GestureClassificationThresholds {
        guard store.bool(forKey: SettingsKey.expertModeEnabled.rawValue) else { return .default }
        let start = clampedCGFloat(
            from: store, key: returnDisplacementStartKey,
            default: defaultReturnDisplacementStart, range: returnDisplacementStartRange
        )
        let end = clampedCGFloat(
            from: store, key: returnDisplacementEndKey,
            default: defaultReturnDisplacementEnd, range: returnDisplacementEndRange
        )
        return GestureClassificationThresholds(
            minSwipeLength: clampedCGFloat(
                from: store, key: minSwipeLengthKey,
                default: defaultMinSwipeLength, range: minSwipeLengthRange
            ),
            maxReturnRatio: clampedCGFloat(
                from: store, key: maxReturnRatioKey,
                default: defaultMaxReturnRatio, range: maxReturnRatioRange
            ),
            returnDisplacementRange: min(start, end) ... max(start, end),
            minCircularity: clampedCGFloat(
                from: store, key: minCircularityKey,
                default: defaultMinCircularity, range: minCircularityRange
            ),
            minAngularSpan: clampedCGFloat(
                from: store, key: minAngularSpanKey,
                default: defaultMinAngularSpan, range: minAngularSpanRange
            ),
            minPathSeparation: clampedCGFloat(
                from: store, key: minPathSeparationKey,
                default: defaultMinPathSeparation, range: minPathSeparationRange
            ),
            minTurnConsistency: clampedCGFloat(
                from: store, key: minTurnConsistencyKey,
                default: defaultMinTurnConsistency, range: minTurnConsistencyRange
            ),
            minOrientedCompactness: clampedCGFloat(
                from: store, key: minOrientedCompactnessKey,
                default: defaultMinOrientedCompactness, range: minOrientedCompactnessRange
            )
        )
    }
}

// MARK: - Gesture Features

struct GestureFeatures {
    /// Thresholds used for classification
    let thresholds: GestureClassificationThresholds

    // Geometric features
    let pathLength: CGFloat
    let chordLength: CGFloat
    let boundingBox: CGRect
    let maxDisplacement: CGFloat
    let maxDisplacementPoint: CGPoint
    let maxDisplacementProgress: CGFloat // 0.0-1.0: where in the path maxDisplacement occurs
    let centroid: CGPoint

    // Ratio features
    let returnRatio: CGFloat // chordLength / pathLength (low = returned to start)
    let aspectRatio: CGFloat // boundingBox width / height

    // Direction features
    let dominantAngle: CGFloat // angle from start to end
    let maxDisplacementAngle: CGFloat // angle from start to max displacement

    // Circularity features
    let angularSpan: CGFloat // total angle traversed (positive = CW, negative = CCW)
    let circularity: CGFloat // how circular (0-1, 1 = perfect circle)
    let pathSeparation: CGFloat // how separated are mirrored points (spiral > 0.5, return < 0.3)
    let turnConsistency: CGFloat // how consistent turn direction is (1.0 = all same direction, 0.5 = half each)
    let orientedCompactness: CGFloat // width/length along principal axis (1.0 = square, 0 = line)

    // Derived classifications (using configurable thresholds)
    var isTap: Bool {
        maxDisplacement < thresholds.minSwipeLength
    }

    /// Return-swipe: maxDisplacement in the middle of the path (not at the end) AND finger returned to start
    var isReturn: Bool {
        let t = thresholds
        // Must have significant movement
        guard maxDisplacement > t.minSwipeLength else { return false }
        // Must have returned close to start (low chord/path ratio)
        guard returnRatio < t.maxReturnRatio else { return false }
        // maxDisplacement should be in the middle of the path, not at the very end
        return t.returnDisplacementRange.contains(maxDisplacementProgress)
    }

    var isCircular: Bool {
        let t = thresholds
        // Require minimum size (2x swipe length) to avoid small wiggles being detected as circles
        // Also require high turn consistency and compactness to distinguish from return swipes
        // (circle: turns consistently one direction AND is not a narrow arc)
        return pathLength > t.minSwipeLength * 2 &&
            circularity > t.minCircularity &&
            abs(angularSpan) > t.minAngularSpan &&
            turnConsistency > t.minTurnConsistency &&
            orientedCompactness > t.minOrientedCompactness
    }

    var isClockwise: Bool {
        angularSpan > 0
    }

    /// Extracts features from preprocessed points.
    /// Uses GestureCalculations helper functions for cleaner, testable code.
    static func extract(from points: [CGPoint], thresholds: GestureClassificationThresholds = .default) -> GestureFeatures {
        guard points.count >= 2 else {
            return GestureFeatures.empty(thresholds: thresholds)
        }

        let start = points[0]
        let end = points[points.count - 1]

        // Use helper functions from GestureCalculations
        let pathLen = GestureCalculations.pathLength(of: points)
        let chordLen = GestureCalculations.chordLength(of: points)
        let bbox = GestureCalculations.boundingBox(of: points)
        let centroid = GestureCalculations.centroid(of: points)

        // Max displacement analysis
        let maxDispResult = GestureCalculations.maxDisplacement(in: points)
        let maxDisp = maxDispResult.distance
        let maxDispPoint = maxDispResult.point
        let maxDispProgress = maxDispResult.progress

        // Angles (simple calculations, kept inline)
        let dominantAngle = atan2(end.y - start.y, end.x - start.x)
        let maxDispAngle = atan2(maxDispPoint.y - start.y, maxDispPoint.x - start.x)

        // Circularity features using helpers
        let angularSpan = GestureCalculations.angularSpan(of: points, around: centroid)
        let circularity = GestureCalculations.circularity(of: points, centroid: centroid)
        let pathSeparation = GestureCalculations.pathSeparation(of: points, maxDisplacement: maxDisp)
        let turnConsistency = GestureCalculations.turnConsistency(of: points)
        let orientedCompactness = GestureCalculations.orientedCompactness(of: points, principalAngle: maxDispAngle)

        // Derived ratios
        let returnRatio = pathLen > 0 ? chordLen / pathLen : 1
        let bboxAspect = bbox.height > 0 ? bbox.width / bbox.height : 1

        return GestureFeatures(
            thresholds: thresholds,
            pathLength: pathLen,
            chordLength: chordLen,
            boundingBox: bbox,
            maxDisplacement: maxDisp,
            maxDisplacementPoint: maxDispPoint,
            maxDisplacementProgress: maxDispProgress,
            centroid: centroid,
            returnRatio: returnRatio,
            aspectRatio: bboxAspect,
            dominantAngle: dominantAngle,
            maxDisplacementAngle: maxDispAngle,
            angularSpan: angularSpan,
            circularity: circularity,
            pathSeparation: pathSeparation,
            turnConsistency: turnConsistency,
            orientedCompactness: orientedCompactness
        )
    }

    static func empty(thresholds: GestureClassificationThresholds = .default) -> GestureFeatures {
        GestureFeatures(
            thresholds: thresholds,
            pathLength: 0,
            chordLength: 0,
            boundingBox: .zero,
            maxDisplacement: 0,
            maxDisplacementPoint: .zero,
            maxDisplacementProgress: 0,
            centroid: .zero,
            returnRatio: 1,
            aspectRatio: 1,
            dominantAngle: 0,
            maxDisplacementAngle: 0,
            angularSpan: 0,
            circularity: 0,
            pathSeparation: 0,
            turnConsistency: 1,
            orientedCompactness: 0
        )
    }
}

// MARK: - Debug Logging

extension GestureFeatures: CustomStringConvertible {
    var description: String {
        """
        GestureFeatures:
          pathLength: \(String(format: "%.1f", pathLength))
          chordLength: \(String(format: "%.1f", chordLength))
          maxDisplacement: \(String(format: "%.1f", maxDisplacement)) @ \(String(format: "%.0f%%", maxDisplacementProgress * 100))
          returnRatio: \(String(format: "%.2f", returnRatio))
          angularSpan: \(String(format: "%.1f°", angularSpan * 180 / .pi))
          circularity: \(String(format: "%.2f", circularity))
          pathSeparation: \(String(format: "%.2f", pathSeparation))
          turnConsistency: \(String(format: "%.2f", turnConsistency))
          orientedCompactness: \(String(format: "%.2f", orientedCompactness))
          isTap: \(isTap), isReturn: \(isReturn), isCircular: \(isCircular)
        """
    }
}
