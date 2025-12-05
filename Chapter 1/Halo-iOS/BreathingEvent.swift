//
//  BreathingEvent.swift
//  Halo-iOS
//
//  Data models for breathing events and measurements
//

import Foundation

/// Represents a discrete breathing event
struct BreathingEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let amplitude: Float?
    let duration: TimeInterval?

    enum EventType: String, Codable {
        case inhale
        case exhale
        case apnea
        case deepBreath = "deep_breath"
    }
}

/// Represents a breathing rate measurement at a point in time
struct BreathingRateMeasurement: Codable {
    let timestamp: Date
    let instantaneousRate: Float // breaths per minute
    let smoothedRate: Float // median-smoothed rate
    let confidence: Float // 0.0 to 1.0
}

/// Session data containing all breathing measurements
struct BreathingSession: Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var rateMeasurements: [BreathingRateMeasurement]
    var events: [BreathingEvent]

    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.rateMeasurements = []
        self.events = []
    }

    mutating func addRateMeasurement(_ measurement: BreathingRateMeasurement) {
        rateMeasurements.append(measurement)
    }

    mutating func addEvent(_ event: BreathingEvent) {
        events.append(event)
    }

    var duration: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
    }

    var averageRate: Float {
        guard !rateMeasurements.isEmpty else {
            return 0.0
        }
        let sum = rateMeasurements.reduce(0.0) { $0 + $1.smoothedRate }
        return sum / Float(rateMeasurements.count)
    }

    var apneaCount: Int {
        events.filter { $0.type == .apnea }.count
    }

    var deepBreathCount: Int {
        events.filter { $0.type == .deepBreath }.count
    }
}
