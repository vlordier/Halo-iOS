# Halo iOS

A sleep tracking and health monitoring iOS application featuring breathing detection, smart ring integration, and comprehensive sleep analysis.

## Features

### 🫁 Breathing Detection
- Real-time breathing pattern monitoring using microphone
- DSP-based signal processing (band-pass filtering, envelope detection)
- Breathing rate calculation (BPM)
- Apnea detection (>15s gaps)
- Deep breath detection
- Privacy-first: only features stored, no raw audio

### 💍 Smart Ring Integration
- COLMI R02 Ring support via AccessorySetupKit
- Bluetooth LE connectivity
- Real-time sensor data streaming

### 📊 Health Monitoring
- Continuous overnight tracking
- Session-based data storage
- 30-day data retention
- Export functionality

## Architecture

```
Halo-iOS/
├── Audio Processing
│   ├── BreathingAudioEngine - AVAudioEngine capture (16kHz mono)
│   ├── BreathingDSP - Band-pass filter, AGC, envelope detection
│   └── BreathingFeatureExtractor - 64-band mel-spectrogram
├── Classification
│   ├── BreathingClassifier - Rule-based inhale/exhale detection
│   └── BreathingRateTracker - BPM calculation, event detection
├── Data Layer
│   ├── BreathingEvent - Event models
│   └── BreathingDataStore - Persistent JSON storage
└── UI
    ├── ContentView - Main interface
    └── RingSessionManager - Session coordination
```

## Technical Details

**Audio Processing:**
- Sample rate: 16 kHz mono
- Band-pass: 80-500 Hz (4th-order Butterworth)
- Mel bands: 64 (100-800 Hz)
- Background audio mode enabled

**Breathing Detection:**
- Activity detection: adaptive threshold (1.5× median)
- Classification: envelope slope analysis
- Rate tracking: median-smoothed over 5 breaths
- Latency: <500ms

**Performance:**
- CPU usage: ~2-5% average
- Battery: <25% overnight (8 hours)
- Memory: ~1 MB per night session

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Physical device (microphone required for breathing detection)

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/Halo-iOS.git
   cd Halo-iOS
   ```

2. **Open in Xcode:**
   ```bash
   open "Chapter 1/Halo-iOS.xcodeproj"
   ```

3. **Install dependencies (if using):**
   ```bash
   # SwiftLint (optional)
   brew install swiftlint
   
   # SwiftFormat (optional)
   brew install swiftformat
   ```

4. **Build and run:**
   - Select your physical device
   - Build and run (⌘R)
   - Grant microphone and Bluetooth permissions

## Development

### Code Style

This project uses SwiftLint and SwiftFormat for consistent code style:

```bash
# Format code
swiftformat .

# Lint code
swiftlint
```

### Testing

```bash
# Run tests
xcodebuild test -project "Chapter 1/Halo-iOS.xcodeproj" \
                -scheme Halo-iOS \
                -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Project Structure

- `Halo-iOS/` - Main application code
  - `*AudioEngine.swift` - Audio processing
  - `*DSP.swift` - Digital signal processing
  - `*Classifier.swift` - Pattern classification
  - `*DataStore.swift` - Persistence layer
  - `ContentView.swift` - Main UI
  - `RingSessionManager.swift` - Device coordination

## Privacy & Security

- ✅ No raw audio stored
- ✅ Local-only processing
- ✅ 30-day auto-purge
- ✅ User data export available
- ✅ Clear permission requests

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Breathing detection algorithm based on standard DSP techniques
- AccessorySetupKit integration for seamless device pairing
- SwiftUI for modern, reactive UI
