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
    
    // Adaptive Audio Frequency State
    private var currentAudioCenterFreq: Float = 500.0 // Start at 500 Hz
    private var audioBandwidth: Float = 800.0 // 800 Hz wide
    private var smoothedZCR: Float = 0.03 // Initial estimate corresponding to ~500Hz
    
    // Limits
    private let minAudioFreq: Float = 80.0
    private let maxAudioFreq: Float = 4000.0
    
    // Adaptive Tuning State
    private var currentCenterFreq: Float = 0.3 // Default start ~18 BPM
    private var currentBandwidth: Float = 0.7  // Wide start
    private var isTracking: Bool = false

    // MARK: - Initialization

    init(sampleRate: Double = 16_000.0) {
        self.sampleRate = sampleRate
        setupFilters()
    }

    private func setupFilters() {
        // 1. Audio Filtering (Initial: 100Hz - 900Hz)
        audioHighpass = IIRFilter(sampleRate: sampleRate, filterType: .highpass, frequency: 100.0)
        audioLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 900.0)

        // 2. Envelope Smoothing (4Hz)
        envelopeRectifierLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 4.0)
        
        // 3. Rhythm Isolation (Initial Wide Setup: 0.1Hz - 0.8Hz)
        // 0.1Hz = 6 BPM (Deep slow breathing)
        // 0.8Hz = 48 BPM (Fast hyperventilation)
        envelopeRhythmHighpass = IIRFilter(sampleRate: sampleRate, filterType: .highpass, frequency: 0.1)
        envelopeRhythmLowpass = IIRFilter(sampleRate: sampleRate, filterType: .lowpass, frequency: 0.8)
    }

    // MARK: - Public Methods
    
    /// Adaptively tune the filters to lock onto the detected breathing frequency
    func adaptProcessing(to breathingRateBPM: Float) {
        // Convert BPM to Hz
        let targetFreq = breathingRateBPM / 60.0
        
        // Validate Frequency (6 BPM - 40 BPM range mostly)
        guard targetFreq > 0.1, targetFreq < 0.7 else {
            // Out of reasonable range, slowly relax back to default wide search
            relaxFilters()
            return
        }
        
        isTracking = true
        
        // Smoothly interpolate towards the target frequency (Slew Limiting)
        // This prevents the filter from jumping wildly on single bad measurements
        let alpha: Float = 0.1 // 10% movement per update
        currentCenterFreq = (currentCenterFreq * (1.0 - alpha)) + (targetFreq * alpha)
        
        // Tighten bandwidth when tracking
        // Target bandwidth: Center ± 40%
        let targetBW = currentCenterFreq * 0.8 // Total width
        currentBandwidth = (currentBandwidth * (1.0 - alpha)) + (targetBW * alpha)
        
        // Calculate new cutoffs
        // Ensure Highpass doesn't go below 0.1 Hz (DC drift safety)
        var lowCutoff = max(0.1, currentCenterFreq - (currentBandwidth / 2.0))
        // Ensure Lowpass doesn't go above 1.0 Hz (Noise safety)
        var highCutoff = min(1.0, currentCenterFreq + (currentBandwidth / 2.0))
        
        // Ensure we don't cross (maintain minimum band of 0.1 Hz)
        if highCutoff - lowCutoff < 0.1 {
            highCutoff = lowCutoff + 0.1
        }
        
        // Retune the filters
        // Note: For Highpass filter, cutoff is the frequency below which it attenuates (The LOW bound of our passband)
        envelopeRhythmHighpass.updateParameters(filterType: .highpass, frequency: Double(lowCutoff))
        
        // For Lowpass filter, cutoff is frequency above which it attenuates (The HIGH bound)
        envelopeRhythmLowpass.updateParameters(filterType: .lowpass, frequency: Double(highCutoff))
        
        // print("🎛 Adaptive Filtering: Center: \(String(format: "%.2f", currentCenterFreq)) Hz (\(String(format: "%.0f", currentCenterFreq * 60)) BPM) | Band: \(String(format: "%.2f", lowCutoff))-\(String(format: "%.2f", highCutoff)) Hz")
    }
    
    private func relaxFilters() {
        // Slowly widen the window back to default (0.1 - 0.8 Hz)
        let alpha: Float = 0.05
        let defaultLow: Float = 0.1
        let defaultHigh: Float = 0.8
        
        // Current cutoffs estimate
        var currentLow = Float(envelopeRhythmHighpass.frequency)
        var currentHigh = Float(envelopeRhythmLowpass.frequency)
        
        currentLow = (currentLow * (1.0 - alpha)) + (defaultLow * alpha)
        currentHigh = (currentHigh * (1.0 - alpha)) + (defaultHigh * alpha)
        
        envelopeRhythmHighpass.updateParameters(filterType: .highpass, frequency: Double(currentLow))
        envelopeRhythmLowpass.updateParameters(filterType: .lowpass, frequency: Double(currentHigh))
        
        isTracking = false
    }

    /// Adaptively tune the AUDIO filters based on the signal content (ZCR)
    /// This locks onto the specific "hiss" frequency of the user's breath
    private func adaptAudioFrequencies(signal: [Float]) {
        guard !signal.isEmpty else { return }
        
        // 1. Calculate Zero Crossing Rate (Proxy for dominant frequency)
        var zeroCrossings = 0
        for i in 1..<signal.count {
            if (signal[i-1] > 0 && signal[i] <= 0) || (signal[i-1] < 0 && signal[i] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(signal.count)
        
        // 2. Smooth ZCR (Slow moving average)
        let alpha: Float = 0.05
        smoothedZCR = (smoothedZCR * (1.0 - alpha)) + (zcr * alpha)
        
        // 3. Convert ZCR to roughly estimated Frequency
        // F = (ZCR * SampleRate) / 2
        let estimatedFreq = (smoothedZCR * Float(sampleRate)) / 2.0
        
        // 4. Update Target Center Frequency
        // Only update if we have significant energy (don't adapt to silence)
        // Check longTermRMS from normalizeAndAGC
        if longTermRMS > 0.005 {
             let freqAlpha: Float = 0.02
             currentAudioCenterFreq = (currentAudioCenterFreq * (1.0 - freqAlpha)) + (estimatedFreq * freqAlpha)
        }
        
        // 5. Calculate new Audio Filter Cutoffs
        // We keep a fixed bandwidth but slide it up/down
        let halfBW = audioBandwidth / 2.0
        var newLow = max(minAudioFreq, currentAudioCenterFreq - halfBW)
        var newHigh = min(maxAudioFreq, currentAudioCenterFreq + halfBW)
        
        // Safety check to maintain bandwidth
        if newHigh - newLow < 200 {
            newHigh = newLow + 200
        }
        
        // 6. Update Filters
        audioHighpass.updateParameters(filterType: .highpass, frequency: Double(newLow))
        audioLowpass.updateParameters(filterType: .lowpass, frequency: Double(newHigh))
        
        // print("🎤 Audio Tuning: Center: \(Int(currentAudioCenterFreq)) Hz | Range: \(Int(newLow))-\(Int(newHigh)) Hz")
    }

    /// Apply band-pass filter to isolate breath sounds (Airflow)
    func applyBandpassFilter(to signal: [Float]) -> [Float] {
        // Run adaptation step on the raw signal first
        adaptAudioFrequencies(signal: signal)
        
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
        
        // Slow update of peak expectation (Slower than before for stability)
        if maxVal > envelopePeak {
            envelopePeak = maxVal // Fast attack
        } else {
            envelopePeak *= 0.999 // Very Slow decay to avoid pumping
        }
        
        var normalizedEnvelope = [Float](repeating: 0.0, count: rhythmic.count)
        var envGain = 0.5 / max(envelopePeak, 1e-4) // Target 0.5 amplitude
        vDSP_vsmul(rhythmic, 1, &envGain, &normalizedEnvelope, 1, vDSP_Length(rhythmic.count))

        return normalizedEnvelope
    }

    /// Detect if breathing activity is present
    func detectBreathingActivity(envelope: [Float]) -> Bool {
        // Robustness check: if peak is extremely small, we are boosting noise
        if envelopePeak < 0.0001 {
            return false
        }
        return true 
    }
}

// MARK: - IIR Filter Implementation

final class IIRFilter {
    enum FilterType { case lowpass, highpass, bandpass }

    private var b: [Double] = []
    private var a: [Double] = []
    private var state: [Double] = []
    
    // Properties to read back current state
    private(set) var frequency: Double
    private let sampleRate: Double

    init(sampleRate: Double, filterType: FilterType, frequency: Double, order: Int = 2) {
        self.sampleRate = sampleRate
        self.frequency = frequency
        
        // Initialize coefficients
        updateParameters(filterType: filterType, frequency: frequency)
        
        self.state = Array(repeating: 0.0, count: max(a.count, b.count))
    }
    
    func updateParameters(filterType: FilterType, frequency: Double) {
        self.frequency = frequency
        switch filterType {
        case .lowpass:
            designLowpass(sampleRate: sampleRate, cutoff: frequency)
        case .highpass:
            designHighpass(sampleRate: sampleRate, cutoff: frequency)
        case .bandpass:
             fatalError("Use separate HP/LP filters for bandpass")
        }
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
