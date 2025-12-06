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

    // Audio Filters (Separate HP/LP is more stable for wide bands)
    private var audioHighpass: IIRFilter!
    private var audioLowpass: IIRFilter!

    // Envelope Filters (The "Rhythm" Section)
    private var envelopeRectifierLowpass: IIRFilter! // Smoothing (4Hz)
    private var envelopeRhythmHighpass: IIRFilter!   // DC Removal (0.1Hz)
    private var envelopeRhythmLowpass: IIRFilter!    // Jitter Removal (0.8Hz)

    // Adaptive Normalization
    private var longTermRMS: Float = 0.001
    private var envelopePeak: Float = 0.005

    // MARK: - Initialization

    init(sampleRate: Double = 16_000.0) {
        self.sampleRate = sampleRate
        setupFilters()
    }

    private func setupFilters() {
        // 1. Audio Filtering (80Hz - 1000Hz)
        // Using distinct filters avoids the resonance issues of simple BPFs
        audioHighpass = IIRFilter(sampleRate: sampleRate, filterType: .highpass, frequency: 80.0)
        audioLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 1000.0)

        // 2. Envelope Smoothing (4Hz)
        envelopeRectifierLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 4.0)
        
        // 3. Rhythm Isolation (0.1Hz - 0.8Hz)
        // 0.1Hz = 6 BPM (Deep slow breathing)
        // 0.8Hz = 48 BPM (Fast hyperventilation)
        envelopeRhythmHighpass = IIRFilter(sampleRate: sampleRate, filterType: .highpass, frequency: 0.1)
        envelopeRhythmLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 0.8)
    }

    // MARK: - Public Methods

    /// Apply band-pass filter to isolate breath sounds (Airflow)
    func applyBandpassFilter(to signal: [Float]) -> [Float] {
        let hp = audioHighpass.process(signal)
        return audioLowpass.process(hp)
    }

    /// Normalize signal and apply AGC
    func normalizeAndAGC(_ signal: [Float]) -> [Float] {
        guard !signal.isEmpty else { return signal }

        // 1. Compute current RMS
        var rms: Float = 0.0
        var signalSquared = [Float](repeating: 0.0, count: signal.count)
        vDSP_vsq(signal, 1, &signalSquared, 1, vDSP_Length(signal.count))
        vDSP_meanv(signalSquared, 1, &rms, vDSP_Length(signal.count))
        rms = sqrt(rms)
        
        // 2. Update Long-Term RMS (Adaptive Noise Floor)
        // Fast attack for loud noises, slow decay for quiet periods
        let attack: Float = 0.1
        let decay: Float = 0.005
        if rms > longTermRMS {
            longTermRMS = (longTermRMS * (1.0 - attack)) + (rms * attack)
        } else {
            longTermRMS = (longTermRMS * (1.0 - decay)) + (rms * decay)
        }
        
        // 3. Calculate Gain
        // Target a consistent level relative to the noise floor
        let targetLevel: Float = 0.1
        let noiseFloor = max(longTermRMS, 1e-5)
        var gain = targetLevel / noiseFloor
        
        // Limit gain to prevent massive amplification of silence
        gain = min(gain, 200.0) // Allow up to 200x gain for very quiet breathing

        var normalized = [Float](repeating: 0.0, count: signal.count)
        vDSP_vsmul(signal, 1, &gain, &normalized, 1, vDSP_Length(signal.count))
        
        // Soft Clip [-1, 1]
        var lower: Float = -1.0; var upper: Float = 1.0
        vDSP_vclip(normalized, 1, &lower, &upper, &normalized, 1, vDSP_Length(signal.count))
        
        return normalized
    }

    /// Compute envelope using rectification, smoothing, and rhythm isolation
    func computeEnvelope(_ signal: [Float]) -> [Float] {
        guard !signal.isEmpty else { return signal }

        // 1. Rectify
        var rectified = [Float](repeating: 0.0, count: signal.count)
        vDSP_vabs(signal, 1, &rectified, 1, vDSP_Length(signal.count))

        // 2. Smooth (4Hz LP)
        let smoothed = envelopeRectifierLowpass.process(rectified)
        
        // 3. Rhythm Isolation (BPF)
        let dcRemoved = envelopeRhythmHighpass.process(smoothed)
        let rhythmic = envelopeRhythmLowpass.process(dcRemoved)
        
        // 4. Adaptive Envelope Normalization
        // This ensures the classifiers sees a full -1..1 signal regardless of breath depth
        // Track peak amplitude of the rhythm
        var maxVal: Float = 0.0
        vDSP_maxmgv(rhythmic, 1, &maxVal, vDSP_Length(rhythmic.count))
        
        // Slow update of peak expectation
        if maxVal > envelopePeak {
            envelopePeak = maxVal // Fast attack
        } else {
            envelopePeak *= 0.995 // Slow decay (~10 sec to decay 50 samples/sec)
        }
        
        var normalizedEnvelope = [Float](repeating: 0.0, count: rhythmic.count)
        var envGain = 0.5 / max(envelopePeak, 1e-4) // Target 0.5 amplitude
        vDSP_vsmul(rhythmic, 1, &envGain, &normalizedEnvelope, 1, vDSP_Length(rhythmic.count))

        return normalizedEnvelope
    }

    /// Detect if breathing activity is present
    func detectBreathingActivity(envelope: [Float]) -> Bool {
        // With the new pipeline, "Activity" is just checking if we can normalize the signal successfully
        // If envelopePeak drops too low, it means we are boosting silence
        
        // Current simplistic check: Is the gain realistic?
        // If we are applying >2000x gain, it's probably noise.
        // But for now, let's assume the Adaptive AGC handles it.
        // We return true because the Classifier now handles the "Stability" check.
        return true 
    }
}

// MARK: - IIR Filter Implementation

final class IIRFilter {
    enum FilterType { case lowpass, highpass, bandpass }

    private var b: [Double] = []
    private var a: [Double] = []
    private var state: [Double] = []

    init(sampleRate: Double, filterType: FilterType, frequency: Double, order: Int = 2) {
        switch filterType {
        case .lowpass:
            designLowpass(sampleRate: sampleRate, cutoff: frequency)
        case .highpass:
            designHighpass(sampleRate: sampleRate, cutoff: frequency)
        case .bandpass:
             // Fallback for logic consistency, though we use separated filters now
             fatalError("Use separate HP/LP filters for bandpass")
        }
        self.state = Array(repeating: 0.0, count: max(a.count, b.count))
    }

    func process(_ signal: [Float]) -> [Float] {
        var output = [Float](repeating: 0.0, count: signal.count)
        
        // Direct Form II implementation
        for i in 0 ..< signal.count {
            let x = Double(signal[i])
            let y = b[0] * x + state[0]
            
            // Standard biquad difference equation
            // state[0] = b[1]*x - a[1]*y + state[1]
            // state[1] = b[2]*x - a[2]*y
            
            if b.count > 1 {
                state[0] = b[1] * x - a[1] * y + (state.count > 1 ? state[1] : 0)
            }
            if b.count > 2 {
                state[1] = b[2] * x - a[2] * y
            }
            
            output[i] = Float(y)
        }
        return output
    }

    private func designLowpass(sampleRate: Double, cutoff: Double) {
        let omega = tan(.pi * cutoff / sampleRate)
        let omega2 = omega * omega
        let sqrt2 = sqrt(2.0)
        let k = 1.0 / (1.0 + sqrt2 * omega + omega2)
        b = [k * omega2, 2 * k * omega2, k * omega2]
        a = [1.0, 2 * k * (omega2 - 1), k * (1.0 - sqrt2 * omega + omega2)]
    }

    private func designHighpass(sampleRate: Double, cutoff: Double) {
        let omega = tan(.pi * cutoff / sampleRate)
        let omega2 = omega * omega
        let sqrt2 = sqrt(2.0)
        let k = 1.0 / (1.0 + sqrt2 * omega + omega2)
        b = [k, -2 * k, k]
        a = [1.0, 2 * k * (omega2 - 1), k * (1.0 - sqrt2 * omega + omega2)]
    }
}
