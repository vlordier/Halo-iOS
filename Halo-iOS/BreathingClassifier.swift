//
//  BreathingClassifier.swift
//  Halo-iOS
//
//  Classifies breathing patterns (inhale/exhale/none)
//

import Foundation

/// Classifies breathing segments as inhale, exhale, or none
final class BreathingClassifier {
    // MARK: - Properties

    private var currentState: BreathingState = .none
    private var frameCount: Int = 0
    private var envelopeHistory: [Float] = []
    private let historySize: Int = 10
    
    // Debouncing - minimum frames before state can change
    private var framesInCurrentState: Int = 0
    private let minFramesBeforeChange: Int = 15  // ~1 second at typical frame rate

    // MARK: - Public Methods

    /// Classify breathing state from features and envelope
    func classify(features: [[Float]], envelope: [Float]) -> BreathingState {
        // Since envelope is now band-pass filtered (0.1-0.6 Hz),
        // it oscillates around 0.
        // Positive = Rising energy (Inhale phase)
        // Negative = Falling energy (Exhale phase)
        
        guard !envelope.isEmpty else { return currentState }

        frameCount += 1
        framesInCurrentState += 1

        // Mean of the current buffer (is it mostly positive or negative?)
        let meanVal = envelope.reduce(0, +) / Float(envelope.count)
        
        // Threshold to avoid switching on tiny noise around 0
        let threshold: Float = 0.005
        
        var potentialState: BreathingState = currentState
        
        if meanVal > threshold {
            potentialState = .inhale
        } else if meanVal < -threshold {
            potentialState = .exhale
        }
        // If between -threshold and +threshold, hold previous state (hysteresis)

        // Only change state if we've been stable long enough
        if potentialState != currentState && framesInCurrentState >= minFramesBeforeChange {
            currentState = potentialState
            framesInCurrentState = 0
            
            // Log state changes
            print("🔄 State changed to: \(currentState) (val: \(String(format: "%.4f", meanVal)))")
        }

        return currentState
    }
}
