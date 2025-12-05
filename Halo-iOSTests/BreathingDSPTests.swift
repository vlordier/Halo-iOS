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
        // Create a signal with mixed frequencies
        let sampleRate: Float = 16_000.0
        let count = 1_024
        var input = [Float](repeating: 0.0, count: count)

        for i in 0 ..< count {
            let time = Float(i) / sampleRate
            let breathingSignal = sin(2 * .pi * 200.0 * time) // 200 Hz (in passband 80-500)
            let noiseSignal = 0.5 * sin(2 * .pi * 5_000.0 * time) // 5000 Hz (out of passband)
            input[i] = breathingSignal + noiseSignal
        }

        let output = dsp.applyBandpassFilter(to: input)

        XCTAssertEqual(output.count, input.count)

        // Output should have non-zero values
        let maxOutput = output.max() ?? 0
        XCTAssertGreaterThan(maxOutput, 0.0)
    }

    func testNormalizeAndAGC() {
        // Test with a very quiet signal
        let quietSignal: [Float] = [0.001, -0.001, 0.002, -0.002]
        let normalized = dsp.normalizeAndAGC(quietSignal)

        XCTAssertEqual(normalized.count, quietSignal.count)

        // After normalization, signal should be larger
        let originalMax = quietSignal.max()!
        let normalizedMax = normalized.max()!
        XCTAssertGreaterThan(normalizedMax, originalMax)
    }

    func testNormalizeAndAGCClipping() {
        // Test clipping behavior
        let loudSignal: [Float] = [10.0, -10.0, 20.0, -20.0]
        let normalized = dsp.normalizeAndAGC(loudSignal)

        // Should be clipped to [-3, 3]
        for val in normalized {
            XCTAssertLessThanOrEqual(val, 3.0)
            XCTAssertGreaterThanOrEqual(val, -3.0)
        }
    }

    func testComputeEnvelope() {
        // Create oscillating signal
        let input: [Float] = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
        let envelope = dsp.computeEnvelope(input)

        XCTAssertEqual(envelope.count, input.count)

        // Envelope should be positive (rectified + filtered)
        for val in envelope {
            XCTAssertGreaterThanOrEqual(val, 0.0)
        }
    }

    func testEmptyInputHandling() {
        let empty: [Float] = []

        let filtered = dsp.applyBandpassFilter(to: empty)
        XCTAssertEqual(filtered.count, 0)

        let normalized = dsp.normalizeAndAGC(empty)
        XCTAssertEqual(normalized.count, 0)

        let envelope = dsp.computeEnvelope(empty)
        XCTAssertEqual(envelope.count, 0)
    }

    func testDetectBreathingActivityInitialState() {
        // With no history, should return false
        let envelope: [Float] = [0.5, 0.6, 0.5]
        let isActive = dsp.detectBreathingActivity(envelope: envelope)
        XCTAssertFalse(isActive) // Not enough history yet
    }
}
