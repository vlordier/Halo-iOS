//
//  BreathingFeatureExtractor.swift
//  Halo-iOS
//
//  Extracts mel-spectrogram features for breathing classification
//

import Accelerate
import Foundation

/// Extracts log-mel spectrograms from audio for ML classification
final class BreathingFeatureExtractor {
    // MARK: - Properties

    private let sampleRate: Double
    private let fftSize: Int = 512 // 32 ms at 16 kHz
    private let hopSize: Int = 256 // 16 ms hop (50% overlap)
    private let numMelBands: Int = 64
    private let minFreq: Float = 100.0
    private let maxFreq: Float = 800.0

    private var audioBuffer: [Float] = []
    private let targetDuration: Double = 1.0 // 1 second chunks
    private var targetSamples: Int

    private var fftSetup: vDSP_DFT_Setup?
    private var melFilterbank: [[Float]] = []

    // MARK: - Initialization

    init(sampleRate: Double = 16_000.0) {
        self.sampleRate = sampleRate
        self.targetSamples = Int(sampleRate * targetDuration)

        setupFFT()
        createMelFilterbank()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    private func createMelFilterbank() {
        // Create mel-scale filterbank
        let melMin = hzToMel(minFreq)
        let melMax = hzToMel(maxFreq)

        let melPoints = (0 ... numMelBands + 1).map { i -> Float in
            let fraction = Float(i) / Float(numMelBands + 1)
            return melMin + fraction * (melMax - melMin)
        }

        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { hz -> Int in
            Int(hz * Float(fftSize) / Float(sampleRate))
        }

        // Build triangular filters
        for i in 0 ..< numMelBands {
            var filter = [Float](repeating: 0.0, count: fftSize / 2 + 1)

            let leftBin = binPoints[i]
            let centerBin = binPoints[i + 1]
            let rightBin = binPoints[i + 2]

            // Rising slope
            for bin in leftBin ..< centerBin {
                let weight = Float(bin - leftBin) / Float(centerBin - leftBin)
                filter[bin] = weight
            }

            // Falling slope
            for bin in centerBin ..< rightBin {
                let weight = Float(rightBin - bin) / Float(rightBin - centerBin)
                filter[bin] = weight
            }

            melFilterbank.append(filter)
        }
    }

    // MARK: - Public Methods

    func addSamples(_ samples: [Float]) {
        audioBuffer.append(contentsOf: samples)

        // Keep buffer from growing too large
        let maxBuffer = targetSamples * 2
        if audioBuffer.count > maxBuffer {
            audioBuffer.removeFirst(audioBuffer.count - maxBuffer)
        }
    }

    func extractFeatures() -> [[Float]]? {
        guard audioBuffer.count >= targetSamples else {
            return nil
        }

        // Take the most recent targetSamples
        let samples = Array(audioBuffer.suffix(targetSamples))

        // Compute STFT and convert to log-mel
        let logMel = computeLogMelSpectrogram(samples)

        return logMel
    }

    // MARK: - Private Methods

    private func computeLogMelSpectrogram(_ signal: [Float]) -> [[Float]] {
        var logMelFrames: [[Float]] = []

        let numFrames = (signal.count - fftSize) / hopSize + 1

        for frameIndex in 0 ..< numFrames {
            let startIndex = frameIndex * hopSize
            let endIndex = min(startIndex + fftSize, signal.count)

            guard endIndex - startIndex == fftSize else {
                continue
            }

            var frame = Array(signal[startIndex ..< endIndex])

            // Apply Hann window
            applyHannWindow(&frame)

            // Compute magnitude spectrum
            let magnitudeSpectrum = computeMagnitudeSpectrum(frame)

            // Apply mel filterbank
            let melEnergies = applyMelFilterbank(magnitudeSpectrum)

            // Convert to log scale
            let logMel = melEnergies.map { max(log($0 + 1e-10), -10.0) }

            logMelFrames.append(logMel)
        }

        return logMelFrames
    }

    private func applyHannWindow(_ frame: inout [Float]) {
        var window = [Float](repeating: 0.0, count: frame.count)
        vDSP_hann_window(&window, vDSP_Length(frame.count), Int32(vDSP_HANN_NORM))
        vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(frame.count))
    }

    private func computeMagnitudeSpectrum(_ frame: [Float]) -> [Float] {
        guard let setup = fftSetup else {
            return []
        }

        var realIn = [Float](repeating: 0.0, count: fftSize)
        var imagIn = [Float](repeating: 0.0, count: fftSize)
        var realOut = [Float](repeating: 0.0, count: fftSize)
        var imagOut = [Float](repeating: 0.0, count: fftSize)

        for i in 0 ..< fftSize {
            realIn[i] = i < frame.count ? frame[i] : 0.0
        }

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        // Compute magnitude
        var magnitude = [Float](repeating: 0.0, count: fftSize / 2 + 1)
        for i in 0 ... fftSize / 2 {
            magnitude[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        return magnitude
    }

    private func applyMelFilterbank(_ spectrum: [Float]) -> [Float] {
        var melEnergies = [Float](repeating: 0.0, count: numMelBands)

        for (melIndex, filter) in melFilterbank.enumerated() {
            var energy: Float = 0.0
            vDSP_dotpr(spectrum, 1, filter, 1, &energy, vDSP_Length(spectrum.count))
            melEnergies[melIndex] = energy
        }

        return melEnergies
    }

    // MARK: - Helper Functions

    private func hzToMel(_ hz: Float) -> Float {
        2_595.0 * log10(1.0 + hz / 700.0)
    }

    private func melToHz(_ mel: Float) -> Float {
        700.0 * (pow(10.0, mel / 2_595.0) - 1.0)
    }
}
