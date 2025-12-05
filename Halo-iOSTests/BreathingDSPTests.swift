//
//  BreathingDSPTests.swift
//  Halo-iOS
//
//  Created for Halo-iOS
//

import Accelerate
@testable import Halo_iOS
import XCTest

final class BreathingDSPTests: XCTestCase {
    var dsp: BreathingDSP!

    override func setUp() {
        super.setUp()
        dsp = BreathingDSP(sampleRate: 16_000.0)
    }

    override func tearDown() {
        dsp = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(dsp)
    }

    func testBandpassFilterEffect() {
        // Create a signal with mixed frequencies: 5 Hz (breathing range) and 5000 Hz (noise)
        let sampleRate: Float = 16_000.0
        let count = 1_024
        var input = [Float](repeating: 0.0, count: count)

        for i in 0 ..< count {
            let time = Float(i) / sampleRate
            let breathingSignal = sin(2 * .pi * 5.0 * time) // 5 Hz
            let noiseSignal = 0.5 * sin(2 * .pi * 5_000.0 * time) // 5000 Hz
            input[i] = breathingSignal + noiseSignal
        }

        let output = dsp.applyBandpassFilter(to: input)

        XCTAssertEqual(output.count, input.count)

        // Simple energy check: Noise should be significantly attenuated
        // Since we can't easily do FFT here without complex boilerplate, we check if output is different/smoother
        // Just checking basic properties for now

        let inputEnergy = input.reduce(0) { $0 + $1 * $1 }
        let outputEnergy = output.reduce(0) { $0 + $1 * $1 }

        // Output energy should be less than input because noise is removed
        XCTAssertLessThan(outputEnergy, inputEnergy)
    }

    func testEnvelopeDetection() {
        let input: [Float] = [10.0, -10.0, 10.0, -10.0] // High frequency changing
        let output = dsp.extractEnvelope(from: input)

        XCTAssertEqual(output.count, input.count)

        // Envelope should be positive
        for val in output {
            XCTAssertGreaterThanOrEqual(val, 0.0)
        }
    }

    func testProcessingChain() {
        let input = [Float](repeating: 0.5, count: 512)
        let processed = dsp.process(pcmBuffer: input)

        XCTAssertEqual(processed.count, input.count)
    }
}
