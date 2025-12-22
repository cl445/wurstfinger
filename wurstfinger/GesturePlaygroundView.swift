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
    
    // Config (live binding to UserDefaults via wrapper or direct access)
    // For simplicity, we'll load fresh config on each gesture end
    
    var body: some View {
        VStack {
            // Canvas Area
            ZStack {
                Color.gray.opacity(0.1)
                
                // Raw Path (Red)
                Path { path in
                    guard rawPoints.count > 1 else { return }
                    path.move(to: rawPoints[0])
                    for point in rawPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.red.opacity(0.5), lineWidth: 4)
                
                // Processed Path (Green)
                Path { path in
                    guard processedPoints.count > 1 else { return }
                    path.move(to: processedPoints[0])
                    for point in processedPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.green, lineWidth: 4)
                
                // Key Points
                if let features = features {
                    // Start (Blue Circle)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(rawPoints.first ?? .zero)
                    
                    // End (Red Circle)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .position(rawPoints.last ?? .zero)
                    
                    // Max Displacement (Orange Star-ish)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                        .position(features.maxDisplacementPoint)
                }
            }
            .frame(height: 300)
            .cornerRadius(12)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if rawPoints.isEmpty {
                            rawPoints = [value.location]
                        } else {
                            rawPoints.append(value.location)
                        }
                    }
                    .onEnded { _ in
                        processGesture()
                    }
            )
            .overlay(
                VStack {
                    HStack {
                        Label("Raw", systemImage: "circle.fill").foregroundColor(.red)
                        Label("Smoothed", systemImage: "circle.fill").foregroundColor(.green)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(8)
            )
            
            // Results Area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(classificationResult)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    if let features = features {
                        Group {
                            featureRow("Path Length", String(format: "%.1f", features.pathLength))
                            featureRow("Max Displacement", String(format: "%.1f", features.maxDisplacement))
                            featureRow("Return Ratio", String(format: "%.2f", features.returnRatio))
                            featureRow("Circularity", String(format: "%.2f", features.circularity))
                            featureRow("Angular Span", String(format: "%.1f°", features.angularSpan * 180 / .pi))
                            featureRow("Path Separation", String(format: "%.2f", features.pathSeparation))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Gesture Playground")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    rawPoints = []
                    processedPoints = []
                    features = nil
                    classificationResult = "Draw a gesture..."
                }
            }
        }
    }
    
    private func featureRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
    }
    
    private func processGesture() {
        // 1. Load Config
        let config = GesturePreprocessorConfig.fromUserDefaults()
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
        } else if feats.isCircular {
            result = "Circular (\(feats.isClockwise ? "CW" : "CCW"))"
        } else if feats.isReturn {
            result = "Return Swipe"
        } else {
            result = "Swipe"
        }
        
        self.classificationResult = result
    }
}

#Preview {
    NavigationStack {
        GesturePlaygroundView()
    }
}
