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

            if ringSessionManager.peripheralConnected {
                Section("BREATHING MONITORING", content: {
                    makeBreathingMonitorView()
                })

                if let session = ringSessionManager.breathingSession, !session.events.isEmpty {
                    Section("RECENT EVENTS", content: {
                        makeEventsView(session: session)
                    })
                }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Breathing Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", ringSessionManager.currentBreathingRate))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("BPM")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Breathing state indicator
                VStack {
                    Circle()
                        .fill(breathingStateColor)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: breathingStateIcon)
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                    Text(ringSessionManager.currentBreathingState.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
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
