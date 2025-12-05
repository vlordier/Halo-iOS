//
//  BreathingRateTrackerTests.swift
//  Halo-iOS
//
//  Created for Halo-iOS
//

@testable import Halo_iOS
import XCTest

final class BreathingRateTrackerTests: XCTestCase {
    var tracker: BreathingRateTracker!

    override func setUp() {
        super.setUp()
        tracker = BreathingRateTracker()
    }

    func testInitialState() {
        XCTAssertEqual(tracker.getCurrentRate(), 0.0)
    }

    func testRateCalculationViaCallback() {
        // Test that rate updates are delivered via callback
        var receivedRate: Float = 0.0
        tracker.onRateUpdate = { rate in
            receivedRate = rate
        }

        let envelope: [Float] = [0.5, 0.6, 0.7, 0.5]

        // Simulate exhale -> inhale transition (first breath)
        tracker.update(state: .exhale, envelope: envelope, timestamp: Date())
        tracker.update(state: .inhale, envelope: envelope, timestamp: Date())

        // Second breath 4 seconds later (15 BPM)
        let date2 = Date().addingTimeInterval(4.0)
        tracker.update(state: .exhale, envelope: envelope, timestamp: date2)
        tracker.update(state: .inhale, envelope: envelope, timestamp: date2)

        // Rate = 60 / 4 = 15 BPM (clamped to 4-60 range)
        XCTAssertEqual(receivedRate, 15.0, accuracy: 1.0)
    }

    func testEventCallback() {
        var receivedEvents: [BreathingEvent] = []
        tracker.onEvent = { event in
            receivedEvents.append(event)
        }

        let envelope: [Float] = [0.5]

        // Trigger exhale -> inhale transition
        tracker.update(state: .exhale, envelope: envelope, timestamp: Date())
        tracker.update(state: .inhale, envelope: envelope, timestamp: Date())

        // Should have received an inhale event
        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?.type, .inhale)
    }

    func testGetRecentInhalations() {
        let envelope: [Float] = [0.5]

        // Record some inhalations
        tracker.update(state: .exhale, envelope: envelope, timestamp: Date())
        tracker.update(state: .inhale, envelope: envelope, timestamp: Date())

        let recent = tracker.getRecentInhalations(count: 5)
        XCTAssertEqual(recent.count, 1)
    }
}
