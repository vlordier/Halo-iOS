//
//  BreathingRateTracker.swift
//  Halo-iOS
//
//  Tracks breathing rate and detects events
//

import Foundation

/// Tracks breathing rate over time and detects special events
final class BreathingRateTracker {
    // MARK: - Properties

    private var inhalationTimestamps: [Date] = []
    private var previousState: BreathingState = .none
    private var lastStateChangeTime: Date?

    // Rate calculation
    private let rateWindowSize: Int = 5 // Use last 5 breaths for smoothing
    private var currentRate: Float = 0.0

    // Event detection
    private let apneaThreshold: TimeInterval = 15.0 // 15 seconds without inhalation
    private var amplitudeHistory: [Float] = []
    private let amplitudeHistorySize: Int = 20

    // Callbacks
    var onRateUpdate: ((Float) -> Void)?
    var onEvent: ((BreathingEvent) -> Void)?

    // MARK: - Public Methods

    func update(state: BreathingState, envelope: [Float], timestamp: Date) {
        // Detect state transitions
        detectStateTransition(from: previousState, to: state, envelope: envelope, timestamp: timestamp)

        // Update rate periodically
        if inhalationTimestamps.count >= 2 {
            updateBreathingRate()
        }

        // Check for apnea
        checkForApnea(timestamp: timestamp)

        previousState = state
    }

    // MARK: - Private Methods

    private func detectStateTransition(from oldState: BreathingState, to newState: BreathingState, envelope: [Float], timestamp: Date) {
        // Detect exhale -> inhale transition (start of new breath)
        if oldState == .exhale && newState == .inhale {
            recordInhalation(timestamp: timestamp, envelope: envelope)
        }

        lastStateChangeTime = timestamp
    }

    private func recordInhalation(timestamp: Date, envelope: [Float]) {
        inhalationTimestamps.append(timestamp)

        // Keep only recent timestamps
        let maxTimestamps = rateWindowSize + 5
        if inhalationTimestamps.count > maxTimestamps {
            inhalationTimestamps.removeFirst(inhalationTimestamps.count - maxTimestamps)
        }

        // Compute amplitude (peak of envelope)
        let amplitude = envelope.max() ?? 0.0
        amplitudeHistory.append(amplitude)

        if amplitudeHistory.count > amplitudeHistorySize {
            amplitudeHistory.removeFirst(amplitudeHistory.count - amplitudeHistorySize)
        }

        // Check for deep breath
        checkForDeepBreath(amplitude: amplitude, timestamp: timestamp)

        // Create inhalation event
        let event = BreathingEvent(
            id: UUID(),
            timestamp: timestamp,
            type: .inhale,
            amplitude: amplitude,
            duration: nil
        )
        onEvent?(event)
    }

    private func updateBreathingRate() {
        guard inhalationTimestamps.count >= 2 else {
            return
        }

        // Calculate instantaneous rates for recent breaths
        var rates: [Float] = []

        let recentTimestamps = Array(inhalationTimestamps.suffix(min(rateWindowSize, inhalationTimestamps.count)))

        for i in 1 ..< recentTimestamps.count {
            let interval = recentTimestamps[i].timeIntervalSince(recentTimestamps[i - 1])
            if interval > 0 {
                let rate = Float(60.0 / interval) // Convert to breaths per minute
                rates.append(rate)
            }
        }

        // Compute smoothed rate (median)
        if !rates.isEmpty {
            let sortedRates = rates.sorted()
            currentRate = sortedRates[sortedRates.count / 2]

            // Clamp to reasonable range (4-60 BPM)
            currentRate = max(4.0, min(60.0, currentRate))

            onRateUpdate?(currentRate)
        }
    }

    private func checkForApnea(timestamp: Date) {
        guard let lastInhalation = inhalationTimestamps.last else {
            return
        }

        let timeSinceLastInhalation = timestamp.timeIntervalSince(lastInhalation)

        if timeSinceLastInhalation > apneaThreshold {
            // Check if we already fired an apnea event recently
            let shouldFireEvent = lastStateChangeTime.map { timestamp.timeIntervalSince($0) > 1.0 } ?? true

            if shouldFireEvent {
                let event = BreathingEvent(
                    id: UUID(),
                    timestamp: timestamp,
                    type: .apnea,
                    amplitude: nil,
                    duration: timeSinceLastInhalation
                )
                onEvent?(event)
            }
        }
    }

    private func checkForDeepBreath(amplitude: Float, timestamp: Date) {
        guard amplitudeHistory.count >= 5 else {
            return
        }

        // Compute median baseline amplitude
        let sortedAmplitudes = amplitudeHistory.sorted()
        let medianAmplitude = sortedAmplitudes[sortedAmplitudes.count / 2]

        // Detect deep breath (amplitude > 1.5x median)
        if amplitude > medianAmplitude * 1.5 {
            let event = BreathingEvent(
                id: UUID(),
                timestamp: timestamp,
                type: .deepBreath,
                amplitude: amplitude,
                duration: nil
            )
            onEvent?(event)
        }
    }

    // MARK: - Public Accessors

    func getCurrentRate() -> Float {
        currentRate
    }

    func getRecentInhalations(count: Int) -> [Date] {
        Array(inhalationTimestamps.suffix(count))
    }
}
