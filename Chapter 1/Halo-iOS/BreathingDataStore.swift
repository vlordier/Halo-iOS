//
//  BreathingDataStore.swift
//  Halo-iOS
//
//  Persistent storage for breathing data
//

import Foundation

/// Handles persistent storage of breathing sessions and data
final class BreathingDataStore {
    // MARK: - Properties

    static let shared = BreathingDataStore()

    private let fileManager = FileManager.default
    private let dataDirectory: URL
    private let sessionsFileName = "breathing_sessions.json"

    private var currentSession: BreathingSession?

    // MARK: - Initialization

    private init() {
        // Setup data directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dataDirectory = documentsPath.appendingPathComponent("BreathingData", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: dataDirectory.path) {
            try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        }

        // Clean old data on init
        cleanOldData()
    }

    // MARK: - Session Management

    func startNewSession() -> BreathingSession {
        let session = BreathingSession()
        currentSession = session
        return session
    }

    func endCurrentSession() {
        guard var session = currentSession else {
            return
        }
        session.endTime = Date()
        saveSession(session)
        currentSession = nil
    }

    func updateCurrentSession(with measurement: BreathingRateMeasurement) {
        guard var session = currentSession else {
            return
        }
        session.addRateMeasurement(measurement)
        currentSession = session

        // Save periodically (every 10 measurements)
        if session.rateMeasurements.count % 10 == 0 {
            saveSession(session)
        }
    }

    func addEventToCurrentSession(_ event: BreathingEvent) {
        guard var session = currentSession else {
            return
        }
        session.addEvent(event)
        currentSession = session

        // Save immediately for important events
        if event.type == .apnea {
            saveSession(session)
        }
    }

    func getCurrentSession() -> BreathingSession? {
        currentSession
    }

    // MARK: - Persistence

    private func saveSession(_ session: BreathingSession) {
        var sessions = loadAllSessions()

        // Update or append session
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        // Save to disk
        let fileURL = dataDirectory.appendingPathComponent(sessionsFileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save breathing session: \(error)")
        }
    }

    func loadAllSessions() -> [BreathingSession] {
        let fileURL = dataDirectory.appendingPathComponent(sessionsFileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sessions = try decoder.decode([BreathingSession].self, from: data)
            return sessions
        } catch {
            print("Failed to load breathing sessions: \(error)")
            return []
        }
    }

    func getRecentSessions(days: Int = 7) -> [BreathingSession] {
        let sessions = loadAllSessions()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        return sessions.filter { $0.startTime > cutoffDate }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Data Management

    private func cleanOldData() {
        var sessions = loadAllSessions()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let beforeCount = sessions.count
        sessions = sessions.filter { $0.startTime > cutoffDate }
        let afterCount = sessions.count

        if beforeCount != afterCount {
            print("Cleaned \(beforeCount - afterCount) old breathing sessions")

            let fileURL = dataDirectory.appendingPathComponent(sessionsFileName)
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(sessions)
                try data.write(to: fileURL)
            } catch {
                print("Failed to save cleaned sessions: \(error)")
            }
        }
    }

    func exportSessionData() -> URL? {
        let sessions = loadAllSessions()

        guard !sessions.isEmpty else {
            return nil
        }

        let exportURL = dataDirectory.appendingPathComponent("breathing_export_\(Date().timeIntervalSince1970).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: exportURL)
            return exportURL
        } catch {
            print("Failed to export session data: \(error)")
            return nil
        }
    }

    // MARK: - Statistics

    func getSessionStatistics(sessionId: UUID) -> SessionStatistics? {
        let sessions = loadAllSessions()
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            return nil
        }

        return SessionStatistics(from: session)
    }
}

// MARK: - Session Statistics

struct SessionStatistics {
    let duration: TimeInterval
    let averageRate: Float
    let minRate: Float
    let maxRate: Float
    let apneaCount: Int
    let deepBreathCount: Int
    let totalBreaths: Int

    init(from session: BreathingSession) {
        self.duration = session.duration
        self.averageRate = session.averageRate

        let rates = session.rateMeasurements.map(\.smoothedRate)
        self.minRate = rates.min() ?? 0.0
        self.maxRate = rates.max() ?? 0.0

        self.apneaCount = session.apneaCount
        self.deepBreathCount = session.deepBreathCount

        let inhalationEvents = session.events.filter { $0.type == .inhale }
        self.totalBreaths = inhalationEvents.count
    }
}
