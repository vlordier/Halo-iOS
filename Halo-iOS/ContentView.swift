//
//  ContentView.swift
//  Halo-iOS
//
//  Created by Cyril Zakka on 10/21/24.
//

import AccessorySetupKit
import SwiftUI

struct ContentView: View {
    @State var ringSessionManager = RingSessionManager()
    @State private var isBreathingDemoActive = false
    @State private var isSimulationActive = false
    @State private var selectedSimulationFile = "breathing_normal.mp3"

    var body: some View {
        List {
            Section("MY DEVICE", content: {
                if ringSessionManager.pickerDismissed, let currentRing = ringSessionManager.currentRing {
                    makeRingView(ring: currentRing)
                } else {
                    Button {
                        ringSessionManager.presentPicker()
                    } label: {
                        Text("Add Ring")
                            .frame(maxWidth: .infinity)
                            .font(Font.headline.weight(.semibold))
                    }
                }
            })

            // Show breathing section if connected OR demo mode OR simulation
            if ringSessionManager.peripheralConnected || isBreathingDemoActive || isSimulationActive {
                Section("BREATHING MONITORING", content: {
                    makeBreathingMonitorView()
                })

                if let session = ringSessionManager.breathingSession, !session.events.isEmpty {
                    Section("RECENT EVENTS", content: {
                        makeEventsView(session: session)
                    })
                }
            }

            // Ring health metrics (only when connected)
            if ringSessionManager.peripheralConnected {
                Section("RING HEALTH") {
                    // Heart Rate
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text("Heart Rate")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(ringSessionManager.currentHeartRate)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("BPM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            if ringSessionManager.isStreamingHeartRate {
                                ringSessionManager.stopRealTimeStreaming(type: .heartRate)
                                ringSessionManager.isStreamingHeartRate = false
                            } else {
                                ringSessionManager.startRealTimeStreaming(type: .heartRate)
                                ringSessionManager.isStreamingHeartRate = true
                            }
                        } label: {
                            Text(ringSessionManager.isStreamingHeartRate ? "Stop" : "Measure")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ringSessionManager.isStreamingHeartRate ? Color.red : Color.pink)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)

                    // Battery
                    HStack {
                        BatteryView(isCharging: ringSessionManager.isBatteryCharging, batteryLevel: ringSessionManager.batteryLevel)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text("Battery")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(ringSessionManager.batteryLevel)%")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }

                        Spacer()

                        Button("Refresh") {
                            ringSessionManager.getBatteryStatus { info in
                                ringSessionManager.batteryLevel = info.batteryLevel
                                ringSessionManager.isBatteryCharging = info.charging
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Demo mode section (for testing without ring)
            Section("DEMO MODE") {
                Toggle("Breathing Demo", isOn: $isBreathingDemoActive)
                    .onChange(of: isBreathingDemoActive) { _, newValue in
                        if newValue {
                            ringSessionManager.startBreathingDemo()
                        } else {
                            ringSessionManager.stopBreathingDemo()
                        }
                    }

                Text("Test breathing UI without ring connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Simulation section
            Section("SIMULATION") {
                Picker("Test File", selection: $selectedSimulationFile) {
                    Text("Normal").tag("breathing_normal.mp3")
                    Text("Heavy").tag("breathing_heavy.mp3")
                    Text("Fast").tag("breathing_fast.mp3")
                    Text("Slow").tag("breathing_slow.mp3")
                    Text("Sickly").tag("breathing_sickly.mp3")
                }
                
                Button(isSimulationActive ? "Stop Simulation" : "Start Simulation") {
                    if isSimulationActive {
                        ringSessionManager.stopBreathingDemo()
                        isSimulationActive = false
                    } else {
                        ringSessionManager.startBreathingSimulation(file: selectedSimulationFile)
                        isSimulationActive = true
                    }
                }
                .foregroundStyle(isSimulationActive ? .red : .blue)
            }
        }.listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func makeRingView(ring: ASAccessory) -> some View {
        HStack {
            Image("colmi")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 70)

            VStack(alignment: .leading) {
                Text(ring.displayName)
                    .font(Font.headline.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private func makeBreathingMonitorView() -> some View {
        VStack(spacing: 16) {
            // Animated breathing circle
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Animated breathing indicator
                Circle()
                    .fill(breathingStateGradient)
                    .frame(width: breathingCircleSize, height: breathingCircleSize)
                    .animation(.easeInOut(duration: 0.8), value: ringSessionManager.currentBreathingState)
                    .shadow(color: breathingStateColor.opacity(0.5), radius: 10)

                // Center icon
                Image(systemName: breathingStateIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(ringSessionManager.currentBreathingState == .none ? 1.0 : 1.2)
                    .animation(.easeInOut(duration: 0.5), value: ringSessionManager.currentBreathingState)
            }

            // State label
            Text(breathingStateLabel)
                .font(.headline)
                .foregroundStyle(breathingStateColor)

            // Real-time audio level meter
            VStack(spacing: 4) {
                Text("Mic Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Level indicator
                        RoundedRectangle(cornerRadius: 4)
                            .fill(audioLevelColor)
                            .frame(width: geo.size.width * CGFloat(ringSessionManager.currentAudioLevel))
                            .animation(.easeOut(duration: 0.1), value: ringSessionManager.currentAudioLevel)
                    }
                }
                .frame(height: 12)
                .padding(.horizontal, 40)
            }

            // Breathing rate
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", ringSessionManager.currentBreathingRate))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(breathingStateColor)
                Text("BPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var audioLevelColor: Color {
        let level = ringSessionManager.currentAudioLevel
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }

    private var breathingCircleSize: CGFloat {
        switch ringSessionManager.currentBreathingState {
        case .inhale: 100
        case .exhale: 60
        case .none: 80
        }
    }

    private var breathingStateGradient: LinearGradient {
        LinearGradient(
            colors: [breathingStateColor, breathingStateColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var breathingStateLabel: String {
        switch ringSessionManager.currentBreathingState {
        case .inhale: "Breathing In"
        case .exhale: "Breathing Out"
        case .none: "Waiting..."
        }
    }

    @ViewBuilder
    private func makeEventsView(session: BreathingSession) -> some View {
        let recentEvents = Array(session.events.suffix(5).reversed())

        ForEach(recentEvents) { event in
            HStack {
                Image(systemName: eventIcon(for: event.type))
                    .foregroundStyle(eventColor(for: event.type))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(eventTitle(for: event.type))
                        .font(.subheadline)

                    Text(event.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let amplitude = event.amplitude {
                    Text(String(format: "%.2f", amplitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var breathingStateColor: Color {
        switch ringSessionManager.currentBreathingState {
        case .inhale: .blue
        case .exhale: .green
        case .none: .gray
        }
    }

    private var breathingStateIcon: String {
        switch ringSessionManager.currentBreathingState {
        case .inhale: "arrow.down.to.line"
        case .exhale: "arrow.up.to.line"
        case .none: "moon.zzz"
        }
    }

    private func eventIcon(for type: BreathingEvent.EventType) -> String {
        switch type {
        case .inhale: "arrow.down.circle.fill"
        case .exhale: "arrow.up.circle.fill"
        case .apnea: "exclamationmark.triangle.fill"
        case .deepBreath: "wind"
        }
    }

    private func eventColor(for type: BreathingEvent.EventType) -> Color {
        switch type {
        case .inhale: .blue
        case .exhale: .green
        case .apnea: .red
        case .deepBreath: .cyan
        }
    }

    private func eventTitle(for type: BreathingEvent.EventType) -> String {
        switch type {
        case .inhale: "Inhalation"
        case .exhale: "Exhalation"
        case .apnea: "Apnea Detected"
        case .deepBreath: "Deep Breath"
        }
    }
}

#Preview {
    ContentView()
}
