//
//  BreathingClassifier.swift
//  Halo-iOS
//
//  Classifies breathing patterns (inhale/exhale/none)
//

import Foundation

/// Classifies breathing segments as inhale, exhale, or none
/// Currently uses rule-based approach; can be replaced with Core ML model
final class BreathingClassifier {
    // MARK: - Properties

    private var previousState: BreathingState = .none
    private var stateHistory: [BreathingState] = []
    private let historySize: Int = 5
    private let minConfidence: Float = 0.6

    // Hysteresis parameters to prevent rapid switching
    private var sameStateCount: Int = 0
    private let minSameStateFrames: Int = 3

    // MARK: - Public Methods

    /// Classify breathing state from features and envelope
    /// Currently uses rule-based approach based on envelope slope
    func classify(features: [[Float]], envelope: [Float]) -> BreathingState {
        guard !envelope.isEmpty else {
            return .none
        }

        // Rule-based classification using envelope slope
        let state = classifyFromEnvelope(envelope)

        // Apply smoothing and hysteresis
        let smoothedState = applySmoothing(state)

        return smoothedState
    }

    // MARK: - Private Methods

    private func classifyFromEnvelope(_ envelope: [Float]) -> BreathingState {
        guard envelope.count > 10 else {
            return .none
        }

        // Compute derivative (slope) of envelope
        let mid = envelope.count / 2
        let windowSize = min(10, envelope.count / 4)

        let startIdx = max(0, mid - windowSize)
        let endIdx = min(envelope.count, mid + windowSize)

        guard endIdx > startIdx else {
            return .none
        }

        let startValue = envelope[startIdx]
        let endValue = envelope[endIdx]
        let slope = (endValue - startValue) / Float(endIdx - startIdx)

        // Classify based on slope
        let threshold: Float = 0.001

        if slope > threshold {
            return .inhale // Rising slope = inhaling
        } else if slope < -threshold {
            return .exhale // Falling slope = exhaling
        } else {
            return .none // Flat = no clear breathing
        }
    }

    private func applySmoothing(_ state: BreathingState) -> BreathingState {
        // Add to history
        stateHistory.append(state)
        if stateHistory.count > historySize {
            stateHistory.removeFirst()
        }

        // Hysteresis: require minimum consecutive frames before switching
        if state == previousState {
            sameStateCount += 1
        } else {
            sameStateCount = 1
        }

        // Only switch if we've had enough consecutive frames
        let finalState: BreathingState
        if sameStateCount >= minSameStateFrames {
            finalState = state
            previousState = state
        } else {
            finalState = previousState
        }

        return finalState
    }

    // MARK: - Core ML Integration (Future)

    // When Core ML model is ready, replace classifyFromEnvelope with:
    /*
     private func classifyWithModel(features: [[Float]]) -> BreathingState {
         // Convert features to MLMultiArray
         // Run inference
         // Get class prediction (0=none, 1=inhale, 2=exhale)
         // Return corresponding BreathingState
     }
     */
}
