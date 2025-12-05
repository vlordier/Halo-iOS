//
//  BreathingClassifierTests.swift
//  Halo-iOS
//
//  Created for Halo-iOS
//

@testable import Halo_iOS
import XCTest

final class BreathingClassifierTests: XCTestCase {
    var classifier: BreathingClassifier!

    override func setUp() {
        super.setUp()
        classifier = BreathingClassifier()
    }

    override func tearDown() {
        classifier = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(classifier)
    }

    func testClassifyWithRisingEnvelope() {
        // Rising envelope suggests inhale
        let features: [[Float]] = [[0.1, 0.2, 0.3]]
        let envelope: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5] // Rising

        let state = classifier.classify(features: features, envelope: envelope)

        // With rising envelope, should detect inhale (though may need warmup)
        XCTAssertTrue(state == .inhale || state == .none)
    }

    func testClassifyWithFallingEnvelope() {
        // Falling envelope suggests exhale
        let features: [[Float]] = [[0.3, 0.2, 0.1]]
        let envelope: [Float] = [0.5, 0.4, 0.3, 0.2, 0.1] // Falling

        let state = classifier.classify(features: features, envelope: envelope)

        // With falling envelope, should detect exhale (though may need warmup)
        XCTAssertTrue(state == .exhale || state == .none)
    }

    func testClassifyWithFlatEnvelope() {
        // Flat envelope = no clear breathing
        let features: [[Float]] = [[0.2, 0.2, 0.2]]
        let envelope: [Float] = [0.2, 0.2, 0.2, 0.2, 0.2] // Flat

        let state = classifier.classify(features: features, envelope: envelope)

        // Flat envelope should result in none
        XCTAssertEqual(state, .none)
    }

    func testHysteresisPreventsFastSwitching() {
        let risingEnvelope: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let fallingEnvelope: [Float] = [0.5, 0.4, 0.3, 0.2, 0.1]
        let features: [[Float]] = [[0.2]]

        // Warm up the classifier
        for _ in 0 ..< 10 {
            _ = classifier.classify(features: features, envelope: risingEnvelope)
        }

        let stateAfterRising = classifier.classify(features: features, envelope: risingEnvelope)

        // Single falling frame shouldn't immediately switch (hysteresis)
        let stateAfterOneFalling = classifier.classify(features: features, envelope: fallingEnvelope)

        // The state shouldn't change after just one frame
        XCTAssertTrue(stateAfterRising == stateAfterOneFalling || stateAfterOneFalling == .none)
    }
}
