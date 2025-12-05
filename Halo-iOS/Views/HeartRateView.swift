//
//  HeartRateView.swift
//  Halo-iOS
//
//  Created by Cyril Zakka on 3/17/25.
//

import SwiftUI

struct HeartRateView: View {
    @Environment(RingSessionManager.self) private var ringSessionManager
    @State var isStreamingHR: Bool = false

    var body: some View {
        ScrollView {
            VStack {
                // Realtime HR Card
                VStack {
                    Label("Realtime HR", systemImage: "heart.fill")
                        .font(.subheadline)
                        .foregroundStyle(.pink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .lastTextBaseline) {
                        Text("--")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .contentTransition(.numericText())

                        Text("BPM")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)

                    Button(action: {
                        isStreamingHR.toggle()
                        if isStreamingHR {
                            ringSessionManager.stopRealTimeStreaming(type: .heartRate)
                        } else {
                            ringSessionManager.startRealTimeStreaming(type: .heartRate)
                        }

                    }, label: {
                        Group {
                            if isStreamingHR {
                                Text("Stop Recording")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Measure Heart Rate")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color(.pink))
                        }
                    })
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    HeartRateView()
        .environment(RingSessionManager())
}

#Preview {
    ContentView(ringSessionManager: PreviewRingSessionManager())
}
