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
        XCTAssertEqual(tracker.currentInstantaneousRate, 0.0)
        XCTAssertEqual(tracker.currentSmoothedRate, 0.0)
    }

    func testRateTracking() {
        // Mock breathing cycle
        // Inhale at t=0, t=4s (15 BPM), t=8s

        // First inhalation
        tracker.trackInhalation(at: Date())
        XCTAssertEqual(tracker.currentInstantaneousRate, 0.0) // Need 2 points

        // Second inhalation 4 seconds later
        let date2 = Date().addingTimeInterval(4.0)
        tracker.trackInhalation(at: date2)

        // Rate = 60 / 4 = 15 BPM
        XCTAssertEqual(tracker.currentInstantaneousRate, 15.0, accuracy: 0.1)

        // Third inhalation 4 seconds later
        let date3 = date2.addingTimeInterval(4.0)
        tracker.trackInhalation(at: date3)

        // Should maintain 15 BPM
        XCTAssertEqual(tracker.currentInstantaneousRate, 15.0, accuracy: 0.1)
    }

    func testOutlierRejection() {
        tracker.trackInhalation(at: Date())

        // Very fast breath (0.5s = 120 BPM, likely noise/outlier if filtered)
        // But tracker logic clamps at 4-60 usually.
        // 120 BPM -> interval 0.5s.
        // Implementation check:
        // let rate = 60.0 / interval
        // rate = min(max(rate, 4.0), 60.0)

        let date2 = Date().addingTimeInterval(0.5)
        tracker.trackInhalation(at: date2)

        // Expected: clamped to 60.0
        XCTAssertEqual(tracker.currentInstantaneousRate, 60.0)
    }
}
