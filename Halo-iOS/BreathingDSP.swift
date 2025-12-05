//
//  BreathingDSP.swift
//  Halo-iOS
//
//  Digital signal processing for breathing detection
//

import Accelerate
import Foundation

/// Handles all DSP operations for breathing detection
final class BreathingDSP {
    // MARK: - Properties

    private let sampleRate: Double

    // Band-pass filter state (80-500 Hz, 4th order Butterworth)
    private var bandpassFilter: IIRFilter!

    // Envelope detection (2-3 Hz low-pass)
    private var envelopeLowpass: IIRFilter!

    // Activity detection
    private var envelopeHistory: [Float] = []
    private let envelopeHistorySize = 480 // ~30 seconds at 16 Hz envelope rate
    private let activityThresholdMultiplier: Float = 1.5

    // MARK: - Initialization

    init(sampleRate: Double = 16_000.0) {
        self.sampleRate = sampleRate
        setupFilters()
    }

    private func setupFilters() {
        // Band-pass filter: 80-500 Hz, 4th order Butterworth
        // Implemented as cascade of 2 biquad sections
        bandpassFilter = IIRFilter(
            sampleRate: sampleRate,
            filterType: .bandpass,
            lowFreq: 80.0,
            highFreq: 500.0,
            order: 4
        )

        // Envelope low-pass: 2.5 Hz cutoff
        envelopeLowpass = IIRFilter(
            sampleRate: sampleRate,
            filterType: .lowpass,
            frequency: 2.5,
            order: 2
        )
    }

    // MARK: - Public Methods

    /// Apply band-pass filter to isolate breathing frequencies (80-500 Hz)
    func applyBandpassFilter(to signal: [Float]) -> [Float] {
        bandpassFilter.process(signal)
    }

    /// Normalize signal and apply automatic gain control
    func normalizeAndAGC(_ signal: [Float]) -> [Float] {
        guard !signal.isEmpty else {
            return signal
        }

        // Compute RMS
        var rms: Float = 0.0
        var signalSquared = [Float](repeating: 0.0, count: signal.count)

        vDSP_vsq(signal, 1, &signalSquared, 1, vDSP_Length(signal.count))
        vDSP_meanv(signalSquared, 1, &rms, vDSP_Length(signal.count))
        rms = sqrt(rms)

        // Normalize with epsilon to avoid division by zero
        let epsilon: Float = 1e-6
        let gain = 1.0 / max(rms, epsilon)

        var normalized = [Float](repeating: 0.0, count: signal.count)
        vDSP_vsmul(signal, 1, &gain, &normalized, 1, vDSP_Length(signal.count))

        // Soft clip to [-3, 3]
        var lowerBound: Float = -3.0
        var upperBound: Float = 3.0
        vDSP_vclip(normalized, 1, &lowerBound, &upperBound, &normalized, 1, vDSP_Length(signal.count))

        return normalized
    }

    /// Compute envelope of the signal using rectification and low-pass filtering
    func computeEnvelope(_ signal: [Float]) -> [Float] {
        guard !signal.isEmpty else {
            return signal
        }

        // Rectify (absolute value)
        var rectified = [Float](repeating: 0.0, count: signal.count)
        vDSP_vabs(signal, 1, &rectified, 1, vDSP_Length(signal.count))

        // Low-pass filter to smooth
        let envelope = envelopeLowpass.process(rectified)

        return envelope
    }

    /// Detect if breathing activity is present in the envelope
    func detectBreathingActivity(envelope: [Float]) -> Bool {
        guard !envelope.isEmpty else {
            return false
        }

        // Compute mean of current envelope
        var currentMean: Float = 0.0
        vDSP_meanv(envelope, 1, &currentMean, vDSP_Length(envelope.count))

        // Update envelope history
        envelopeHistory.append(currentMean)
        if envelopeHistory.count > envelopeHistorySize {
            envelopeHistory.removeFirst(envelopeHistory.count - envelopeHistorySize)
        }

        // Not enough history yet
        guard envelopeHistory.count > 10 else {
            return false
        }

        // Compute median of historical envelope values
        let sortedHistory = envelopeHistory.sorted()
        let median = sortedHistory[sortedHistory.count / 2]

        // Check if current envelope exceeds threshold
        let threshold = median * activityThresholdMultiplier
        return currentMean > threshold
    }
}

// MARK: - IIR Filter Implementation

/// Simple IIR filter implementation using Direct Form II
final class IIRFilter {
    enum FilterType {
        case lowpass
        case highpass
        case bandpass
    }

    private var b: [Double] = [] // Numerator coefficients
    private var a: [Double] = [] // Denominator coefficients
    private var state: [Double] = [] // Filter state

    init(sampleRate: Double, filterType: FilterType, frequency: Double? = nil, lowFreq: Double? = nil, highFreq: Double? = nil, order: Int = 2) {
        switch filterType {
        case .lowpass:
            guard let freq = frequency else {
                fatalError("Frequency required for lowpass")
            }
            designButterworthLowpass(sampleRate: sampleRate, cutoff: freq, order: order)
        case .highpass:
            guard let freq = frequency else {
                fatalError("Frequency required for highpass")
            }
            designButterworthHighpass(sampleRate: sampleRate, cutoff: freq, order: order)
        case .bandpass:
            guard let low = lowFreq, let high = highFreq else {
                fatalError("Low and high frequencies required for bandpass")
            }
            designButterworthBandpass(sampleRate: sampleRate, lowCutoff: low, highCutoff: high, order: order)
        }

        self.state = Array(repeating: 0.0, count: max(a.count, b.count))
    }

    func process(_ signal: [Float]) -> [Float] {
        var output = [Float](repeating: 0.0, count: signal.count)

        for i in 0 ..< signal.count {
            let x = Double(signal[i])
            var y = b[0] * x + state[0]

            for j in 1 ..< b.count {
                state[j - 1] = b[j] * x - a[j] * y + state[j]
            }

            output[i] = Float(y)
        }

        return output
    }

    // MARK: - Filter Design Methods

    private func designButterworthLowpass(sampleRate: Double, cutoff: Double, order: Int) {
        // Simplified 2nd-order Butterworth lowpass using bilinear transform
        let omega = tan(.pi * cutoff / sampleRate)
        let omega2 = omega * omega
        let sqrt2 = sqrt(2.0)

        let k = 1.0 / (1.0 + sqrt2 * omega + omega2)

        b = [k * omega2, 2 * k * omega2, k * omega2]
        a = [1.0, 2 * k * (omega2 - 1), k * (1.0 - sqrt2 * omega + omega2)]
    }

    private func designButterworthHighpass(sampleRate: Double, cutoff: Double, order: Int) {
        // Simplified 2nd-order Butterworth highpass
        let omega = tan(.pi * cutoff / sampleRate)
        let omega2 = omega * omega
        let sqrt2 = sqrt(2.0)

        let k = 1.0 / (1.0 + sqrt2 * omega + omega2)

        b = [k, -2 * k, k]
        a = [1.0, 2 * k * (omega2 - 1), k * (1.0 - sqrt2 * omega + omega2)]
    }

    private func designButterworthBandpass(sampleRate: Double, lowCutoff: Double, highCutoff: Double, order: Int) {
        // Simplified approach: cascade high-pass and low-pass
        // For now, using center frequency approximation
        let centerFreq = sqrt(lowCutoff * highCutoff)
        let bandwidth = highCutoff - lowCutoff

        let omega = tan(.pi * centerFreq / sampleRate)
        let bw = tan(.pi * bandwidth / sampleRate)

        let k = 1.0 / (1.0 + bw + omega * omega)

        b = [k * bw, 0.0, -k * bw]
        a = [1.0, 2 * k * (omega * omega - 1), k * (1.0 - bw + omega * omega)]
    }
}
