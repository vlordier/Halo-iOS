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
        guard envelope.count > 5 else {
            return previousState // Return previous instead of none
        }

        // Rule-based classification using envelope slope
        let state = classifyFromEnvelope(envelope)

        // Apply smoothing and hysteresis
        let smoothedState = applySmoothing(state)

        return smoothedState
    }

    // MARK: - Private Methods

    private func classifyFromEnvelope(_ envelope: [Float]) -> BreathingState {
        // Use first half vs second half comparison
        let mid = envelope.count / 2
        guard mid > 0 else { return previousState }

        let firstHalf = Array(envelope[0..<mid])
        let secondHalf = Array(envelope[mid...])

        let firstAvg = firstHalf.reduce(0, +) / Float(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Float(secondHalf.count)

        let change = secondAvg - firstAvg
        let avgValue = (firstAvg + secondAvg) / 2

        // Use relative threshold based on average value
        let threshold = avgValue * 0.05 // 5% change threshold

        if change > threshold {
            return .inhale // Signal increasing = inhaling
        } else if change < -threshold {
            return .exhale // Signal decreasing = exhaling
        } else {
            return previousState // Keep previous state if no clear change
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
