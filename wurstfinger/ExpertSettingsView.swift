//
//  ExpertSettingsView.swift
//  wurstfinger
//
//  Expert settings for tuning gesture recognition parameters.
//  Organized according to the gesture classification decision tree.
//

import SwiftUI

struct ExpertSettingsView: View {
    @AppStorage("expertModeEnabled", store: SharedDefaults.store)
    private var expertModeEnabled = false

    // MARK: - Preprocessing Settings

    @AppStorage(GesturePreprocessorConfig.jitterThresholdKey, store: SharedDefaults.store)
    private var jitterThreshold = Double(GesturePreprocessorConfig.defaultJitterThreshold)

    @AppStorage(GesturePreprocessorConfig.maxJumpDistanceKey, store: SharedDefaults.store)
    private var maxJumpDistance = Double(GesturePreprocessorConfig.defaultMaxJumpDistance)

    @AppStorage(GesturePreprocessorConfig.smoothingWindowKey, store: SharedDefaults.store)
    private var smoothingWindow = GesturePreprocessorConfig.defaultSmoothingWindow

    // MARK: - Classification Settings

    @AppStorage(GestureClassificationThresholds.minSwipeLengthKey, store: SharedDefaults.store)
    private var minSwipeLength = Double(GestureClassificationThresholds.defaultMinSwipeLength)

    @AppStorage(GestureClassificationThresholds.maxReturnRatioKey, store: SharedDefaults.store)
    private var maxReturnRatio = Double(GestureClassificationThresholds.defaultMaxReturnRatio)

    @AppStorage(GestureClassificationThresholds.returnDisplacementStartKey, store: SharedDefaults.store)
    private var returnDisplacementStart = Double(GestureClassificationThresholds.defaultReturnDisplacementStart)

    @AppStorage(GestureClassificationThresholds.returnDisplacementEndKey, store: SharedDefaults.store)
    private var returnDisplacementEnd = Double(GestureClassificationThresholds.defaultReturnDisplacementEnd)

    @AppStorage(GestureClassificationThresholds.minCircularityKey, store: SharedDefaults.store)
    private var minCircularity = Double(GestureClassificationThresholds.defaultMinCircularity)

    @AppStorage(GestureClassificationThresholds.minAngularSpanKey, store: SharedDefaults.store)
    private var minAngularSpan = Double(GestureClassificationThresholds.defaultMinAngularSpan)

    @AppStorage(GestureClassificationThresholds.minPathSeparationKey, store: SharedDefaults.store)
    private var minPathSeparation = Double(GestureClassificationThresholds.defaultMinPathSeparation)

    var body: some View {
        Form {
            warningSection

            if expertModeEnabled {
                decisionTreeSection
                preprocessingSection
                tapDetectionSection
                circularDetectionSection
                returnSwipeDetectionSection
            }
        }
        .navigationTitle("Expert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if expertModeEnabled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                }
            }
        }
    }

    // MARK: - Warning Section

    private var warningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("Advanced Settings")
                        .font(.headline)
                }

                Text("These settings control gesture recognition. Incorrect values can make the keyboard unusable.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("I understand, show expert settings", isOn: $expertModeEnabled)
                    .tint(.orange)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Decision Tree Overview

    private var decisionTreeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Classification Decision Tree")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    decisionStep(number: "1", condition: "maxDisplacement < minSwipeLength", result: "Tap", active: true)
                    decisionStep(number: "2", condition: "isCircular (angle + separation)", result: "Circular", active: true)
                    decisionStep(number: "3", condition: "isReturn (ratio + position)", result: "Return-Swipe", active: true)
                    decisionStep(number: "4", condition: "else", result: "Swipe", active: false)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Gestures are checked in order. The first matching condition determines the type.")
        }
    }

    private func decisionStep(number: String, condition: String, result: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(active ? Color.orange : Color.gray)
                .clipShape(Circle())

            Text(condition)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Spacer()

            Text("→ \(result)")
                .font(.caption.bold())
                .foregroundColor(active ? .primary : .secondary)
        }
    }

    // MARK: - Preprocessing Section

    private var preprocessingSection: some View {
        Section {
            parameterSlider(
                title: "Jitter Threshold",
                value: $jitterThreshold,
                range: 1...10,
                step: 0.5,
                unit: "pt",
                description: "Points closer than this are merged. Removes finger micro-movements."
            )

            parameterSlider(
                title: "Max Jump Distance",
                value: $maxJumpDistance,
                range: 20...100,
                step: 5,
                unit: "pt",
                description: "Points further apart are removed as glitches."
            )

            Stepper(value: $smoothingWindow, in: 3...11, step: 2) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Smoothing Window")
                        Spacer()
                        Text("\(smoothingWindow)")
                            .foregroundColor(.secondary)
                    }
                    Text("Larger = smoother path, but may lose quick direction changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("Step 0: Preprocessing", systemImage: "waveform.path")
        } footer: {
            Text("Raw touch data is cleaned before classification. These settings affect all gesture types.")
        }
    }

    // MARK: - Tap Detection Section

    private var tapDetectionSection: some View {
        Section {
            parameterSlider(
                title: "Min Swipe Length",
                value: $minSwipeLength,
                range: 10...60,
                step: 5,
                unit: "pt",
                description: "maxDisplacement below this = Tap. Above = continues to Step 2."
            )

            // Visual indicator
            HStack {
                Text("Key height: 54pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Threshold: \(Int(minSwipeLength / 54 * 100))% of key")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        } header: {
            Label("Step 1: Tap Detection", systemImage: "hand.tap")
        } footer: {
            Text("If the finger didn't move far enough, it's a tap. Otherwise, check for circular gesture.")
        }
    }

    // MARK: - Circular Detection Section

    private var circularDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("All three conditions must be true:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            parameterSlider(
                title: "Min Angular Span",
                value: $minAngularSpan,
                range: .pi...(.pi * 2),
                step: .pi / 8,
                unit: "°",
                description: "Total angle traversed around centroid must exceed \(Int(minAngularSpan * 180 / .pi))°."
            )

            parameterSlider(
                title: "Min Circularity",
                value: $minCircularity,
                range: 0.1...0.7,
                step: 0.05,
                unit: "",
                description: "How uniform the radii are (1.0 = perfect circle). Spirals have lower values."
            )

            parameterSlider(
                title: "Min Path Separation",
                value: $minPathSeparation,
                range: 0.3...0.8,
                step: 0.05,
                unit: "",
                description: "Distance between start and end points. High = spiral, Low = return-swipe."
            )
        } header: {
            Label("Step 2: Circular Detection", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
        } footer: {
            Text("Distinguishes spirals (for uppercase) from return-swipes. Path Separation is the key differentiator: spirals don't return to start, return-swipes do.")
        }
    }

    // MARK: - Return-Swipe Detection Section

    private var returnSwipeDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Both conditions must be true:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            parameterSlider(
                title: "Max Return Ratio",
                value: $maxReturnRatio,
                range: 0.2...0.8,
                step: 0.05,
                unit: "",
                description: "chord/path ratio must be below \(String(format: "%.0f%%", maxReturnRatio * 100)). Low ratio = finger returned to start."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Displacement Range")
                    .font(.body)

                HStack {
                    Text(String(format: "%.0f%%", returnDisplacementStart * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $returnDisplacementStart, in: 0.1...0.4, step: 0.05)
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(String(format: "%.0f%%", returnDisplacementEnd * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $returnDisplacementEnd, in: 0.6...0.9, step: 0.05)
                    Text("End")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Max displacement must occur between \(Int(returnDisplacementStart * 100))% and \(Int(returnDisplacementEnd * 100))% of the path (not at the very end).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Step 3: Return-Swipe Detection", systemImage: "arrow.uturn.backward")
        } footer: {
            Text("If the finger went out and came back (low return ratio) with max displacement in the middle of the path, it's a return-swipe. Otherwise, it's a normal swipe.")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func parameterSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if unit == "°" {
                    Text("\(Int(value.wrappedValue * 180 / .pi))°")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else if unit.isEmpty {
                    Text(String(format: "%.2f", value.wrappedValue))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else {
                    Text(String(format: "%.1f %@", value.wrappedValue, unit))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Slider(value: value, in: range, step: step)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func resetToDefaults() {
        // Preprocessing
        jitterThreshold = Double(GesturePreprocessorConfig.defaultJitterThreshold)
        maxJumpDistance = Double(GesturePreprocessorConfig.defaultMaxJumpDistance)
        smoothingWindow = GesturePreprocessorConfig.defaultSmoothingWindow

        // Classification
        minSwipeLength = Double(GestureClassificationThresholds.defaultMinSwipeLength)
        maxReturnRatio = Double(GestureClassificationThresholds.defaultMaxReturnRatio)
        returnDisplacementStart = Double(GestureClassificationThresholds.defaultReturnDisplacementStart)
        returnDisplacementEnd = Double(GestureClassificationThresholds.defaultReturnDisplacementEnd)
        minCircularity = Double(GestureClassificationThresholds.defaultMinCircularity)
        minAngularSpan = Double(GestureClassificationThresholds.defaultMinAngularSpan)
        minPathSeparation = Double(GestureClassificationThresholds.defaultMinPathSeparation)
    }
}

#Preview {
    NavigationStack {
        ExpertSettingsView()
    }
}
