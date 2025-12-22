//
//  GesturePlaygroundView.swift
//  wurstfinger
//
//  A visual playground for testing gesture recognition parameters.
//

import SwiftUI

struct GesturePlaygroundView: View {
    @State private var rawPoints: [CGPoint] = []
    @State private var processedPoints: [CGPoint] = []
    @State private var classificationResult: String = "Draw a gesture..."
    @State private var features: GestureFeatures?
    @State private var detectedDirection: KeyboardDirection = .center
    @State private var detectedCircularDirection: KeyboardCircularDirection?
    
    @AppStorage("keyAspectRatio", store: SharedDefaults.store)
    private var keyAspectRatio = 1.5
    
    // Key dimensions for the input area (simulating a standard key)
    private let keyHeight: CGFloat = KeyboardConstants.KeyDimensions.height
    
    private var keyWidth: CGFloat {
        KeyboardConstants.KeyDimensions.height * CGFloat(keyAspectRatio)
    }
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Magnified View (Top)
            ZStack {
                Color.gray.opacity(0.1)
                
                // Grid lines
                Path { path in
                    path.move(to: CGPoint(x: 150, y: 0))
                    path.addLine(to: CGPoint(x: 150, y: 300))
                    path.move(to: CGPoint(x: 0, y: 150))
                    path.addLine(to: CGPoint(x: 300, y: 150))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                
                // Sector lines (for swipe angles)
                ForEach(0..<8) { i in
                    Path { path in
                        let angle = Double(i) * 45.0 * .pi / 180.0
                        path.move(to: CGPoint(x: 150, y: 150))
                        path.addLine(to: CGPoint(
                            x: 150 + 150 * cos(angle),
                            y: 150 + 150 * sin(angle)
                        ))
                    }
                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                }
                
                // Calculate scale to fit key + margin in 300x300
                // Key is roughly 81x54 (1.5 AR). 300 width.
                // Let's map keyWidth to 200pt (leaving 50pt margin on sides)
                let scale = 200.0 / keyWidth
                let offsetX = (300.0 - (keyWidth * scale)) / 2.0
                let offsetY = (300.0 - (keyHeight * scale)) / 2.0
                
                // Visual Key Boundary in Magnified View
                RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius * scale)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: keyWidth * scale, height: keyHeight * scale)
                    .position(x: 150, y: 150) // Center it
                
                // Raw Path (Red) - Scaled up
                Path { path in
                    guard rawPoints.count > 1 else { return }
                    
                    path.move(to: scalePoint(rawPoints[0], scale: scale, offsetX: offsetX, offsetY: offsetY))
                    for point in rawPoints.dropFirst() {
                        path.addLine(to: scalePoint(point, scale: scale, offsetX: offsetX, offsetY: offsetY))
                    }
                }
                .stroke(Color.red.opacity(0.5), lineWidth: 4)
                
                // Processed Path (Green) - Scaled up
                Path { path in
                    guard processedPoints.count > 1 else { return }
                    
                    path.move(to: scalePoint(processedPoints[0], scale: scale, offsetX: offsetX, offsetY: offsetY))
                    for point in processedPoints.dropFirst() {
                        path.addLine(to: scalePoint(point, scale: scale, offsetX: offsetX, offsetY: offsetY))
                    }
                }
                .stroke(Color.green, lineWidth: 4)
                
                // Key Points
                if let features = features {
                    // Start
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(scalePoint(rawPoints.first ?? .zero, scale: scale, offsetX: offsetX, offsetY: offsetY))
                    
                    // End
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .position(scalePoint(rawPoints.last ?? .zero, scale: scale, offsetX: offsetX, offsetY: offsetY))
                        
                    // Max Displacement
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 14)
                        .position(scalePoint(features.maxDisplacementPoint, scale: scale, offsetX: offsetX, offsetY: offsetY))
                }
            }
            .frame(width: 300, height: 300)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // 2. Input Area (Realistic Key Size)
            VStack {
                Text("Input Area")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack {
                    RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: keyWidth, height: keyHeight)
                    
                    Text("Key")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .contentShape(Rectangle()) // Make the whole area touchable even outside the visual key if needed, but let's stick to key size
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                // New gesture started
                                isDragging = true
                                clear()
                                rawPoints = [value.location]
                            } else {
                                rawPoints.append(value.location)
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            processGesture()
                        }
                )
            }
            
            // 3. Analytics & Classification
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Result Header
                    HStack {
                        Text(classificationResult)
                            .font(.title3.bold())
                        Spacer()
                        if detectedDirection != .center {
                            Text(String(describing: detectedDirection).capitalized)
                                .padding(6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    if let features = features {
                        // Decision Tree Breakdown
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Decision Logic").font(.headline)
                            
                            decisionRow(
                                "1. Tap?",
                                passed: features.isTap
                            ) {
                                criterion("maxDisp", val: features.maxDisplacement, op: "<", limit: GestureFeatures.thresholds.minSwipeLength, pass: features.maxDisplacement < GestureFeatures.thresholds.minSwipeLength)
                            }
                            
                            decisionRow(
                                "2. Circular?",
                                passed: features.isCircular
                            ) {
                                VStack(alignment: .leading) {
                                    criterion("circ", val: features.circularity, op: ">", limit: GestureFeatures.thresholds.minCircularity, pass: features.circularity > GestureFeatures.thresholds.minCircularity)
                                    criterion("angle", val: abs(features.angularSpan) * 180 / .pi, op: ">", limit: GestureFeatures.thresholds.minAngularSpan * 180 / .pi, unit: "°", pass: abs(features.angularSpan) > GestureFeatures.thresholds.minAngularSpan)
                                    criterion("turn", val: features.turnConsistency, op: ">", limit: GestureFeatures.thresholds.minTurnConsistency, pass: features.turnConsistency > GestureFeatures.thresholds.minTurnConsistency)
                                    criterion("compact", val: features.orientedCompactness, op: ">", limit: GestureFeatures.thresholds.minOrientedCompactness, pass: features.orientedCompactness > GestureFeatures.thresholds.minOrientedCompactness)
                                }
                            }
                            
                            decisionRow(
                                "3. Return Swipe?",
                                passed: features.isReturn
                            ) {
                                VStack(alignment: .leading) {
                                    criterion("ratio", val: features.returnRatio, op: "<", limit: GestureFeatures.thresholds.maxReturnRatio, pass: features.returnRatio < GestureFeatures.thresholds.maxReturnRatio)
                                    criterion("progress", val: features.maxDisplacementProgress, op: "in", limit: 0, pass: features.maxDisplacementProgress > 0.2 && features.maxDisplacementProgress < 0.8) // Simplified range display
                                }
                            }
                            
                            decisionRow(
                                "4. Swipe?",
                                passed: !features.isTap && !features.isCircular && !features.isReturn
                            ) {
                                Text("Direction: \(angleToSector(features.maxDisplacementAngle)) (\(f(features.maxDisplacementAngle * 180 / .pi))°)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        
                        // Raw Metrics
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Metrics").font(.headline).padding(.bottom, 4)
                            featureRow("Path Length", f(features.pathLength))
                            featureRow("Chord Length", f(features.chordLength))
                            featureRow("Max Displacement", f(features.maxDisplacement))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Gesture Playground")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    clear()
                }
            }
        }
    }
    
    private func clear() {
        rawPoints = []
        processedPoints = []
        features = nil
        classificationResult = "Draw a gesture..."
        detectedDirection = .center
        detectedCircularDirection = nil
    }
    
    private func scalePoint(_ point: CGPoint, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
    }
    
    private func f(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
    
    private func decisionRow<Content: View>(_ label: String, passed: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(passed ? .green : .gray)
            VStack(alignment: .leading) {
                Text(label).bold()
                content()
            }
        }
    }
    
    private func criterion(_ name: String, val: CGFloat, op: String, limit: CGFloat, unit: String = "", pass: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name)
            Text("\(f(val))\(unit)")
                .bold()
                .foregroundColor(pass ? .green : .red)
            Text(op)
            Text("\(f(limit))\(unit)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func angleToSector(_ angle: CGFloat) -> String {
        let dir = KeyboardDirection.direction(for: CGSize(width: cos(angle), height: sin(angle)), tolerance: 0)
        return String(describing: dir).capitalized
    }
    
    private func featureRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
    }
    
    private func processGesture() {
        // 1. Load Config (including aspect ratio, just like the real keyboard)
        let config = GesturePreprocessorConfig.fromUserDefaults().with(aspectRatio: keyAspectRatio)
        let preprocessor = GesturePreprocessor(config: config)
        
        // 2. Preprocess
        // Note: The playground canvas is likely larger than a key, but we treat it as 1:1 for now
        // or we could scale points to simulate key size.
        // For debugging, seeing raw behavior is often better.
        processedPoints = preprocessor.preprocess(rawPoints)
        
        // 3. Extract Features
        GestureFeatures.thresholds = GestureClassificationThresholds.fromUserDefaults()
        let feats = GestureFeatures.extract(from: processedPoints)
        self.features = feats
        
        // 4. Classify
        var result = ""
        if feats.isTap {
            result = "Tap"
            detectedDirection = .center
        } else if feats.isCircular {
            result = "Circular (\(feats.isClockwise ? "CW" : "CCW"))"
            detectedCircularDirection = feats.isClockwise ? .clockwise : .counterclockwise
            detectedDirection = .center
        } else if feats.isReturn {
            result = "Return Swipe"
            // For return swipe, we still want the direction of the max displacement
            detectedDirection = KeyboardDirection.direction(for: CGSize(width: cos(feats.maxDisplacementAngle), height: sin(feats.maxDisplacementAngle)), tolerance: 0)
        } else {
            result = "Swipe"
            detectedDirection = KeyboardDirection.direction(for: CGSize(width: cos(feats.maxDisplacementAngle), height: sin(feats.maxDisplacementAngle)), tolerance: 0)
        }
        
        self.classificationResult = result
    }
}

#Preview {
    NavigationStack {
        GesturePlaygroundView()
    }
}
