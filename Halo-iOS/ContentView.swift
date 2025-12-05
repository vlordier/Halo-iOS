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

            // Audio level bars
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(audioBarColor(for: index))
                        .frame(width: 8, height: audioBarHeight(for: index))
                        .animation(.easeOut(duration: 0.15), value: ringSessionManager.currentBreathingState)
                }
            }
            .frame(height: 40)

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

    private func audioBarColor(for index: Int) -> Color {
        let isActive = ringSessionManager.currentBreathingState != .none
        let activeIndex = ringSessionManager.currentBreathingState == .inhale ? 6 - index : index
        let threshold = isActive ? (ringSessionManager.currentBreathingState == .inhale ? 4 : 3) : 0
        return activeIndex < threshold ? breathingStateColor : Color.gray.opacity(0.3)
    }

    private func audioBarHeight(for index: Int) -> CGFloat {
        let baseHeights: [CGFloat] = [12, 20, 28, 36, 28, 20, 12]
        let isActive = ringSessionManager.currentBreathingState != .none
        return isActive ? baseHeights[index] : baseHeights[index] * 0.5
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
