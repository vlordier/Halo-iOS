//
//  BreathingAudioEngine.swift
//  Halo-iOS
//
//  Created by Antigravity AI
//

import Accelerate
import AVFoundation

/// Main audio engine for breathing detection
/// Captures microphone audio, processes it through DSP pipeline, and detects breathing patterns
final class BreathingAudioEngine {
    // MARK: - Properties

    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private let processingQueue = DispatchQueue(label: "com.halo.breathing.processing", qos: .userInitiated)

    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat!

    // DSP components
    private var dspProcessor: BreathingDSP!
    private var featureExtractor: BreathingFeatureExtractor!
    private var classifier: BreathingClassifier!
    private var rateTracker: BreathingRateTracker!

    // State
    private(set) var isRunning = false
    private var simulationTimer: Timer?

    // Callbacks
    var onBreathingRateUpdate: ((Float) -> Void)?
    var onBreathingStateUpdate: ((BreathingState) -> Void)?
    var onBreathingEvent: ((BreathingEvent) -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?

    // MARK: - Initialization

    init() {
        setupDSPComponents()
    }

    private func setupDSPComponents() {
        dspProcessor = BreathingDSP(sampleRate: 16_000.0)
        featureExtractor = BreathingFeatureExtractor(sampleRate: 16_000.0)
        classifier = BreathingClassifier()
        rateTracker = BreathingRateTracker()

        // Connect tracker callbacks
        rateTracker.onRateUpdate = { [weak self] rate in
            self?.onBreathingRateUpdate?(rate)
            
            // Adaptive DSP Feedback Loop
            // When we detect a rate, we tune the filters to focus on it
            self?.dspProcessor.adaptProcessing(to: rate)
        }

        rateTracker.onEvent = { [weak self] event in
            self?.onBreathingEvent?(event)
        }
    }

    // MARK: - Public Methods

    func start() throws {
        guard !isRunning else {
            return
        }

        // Request microphone permission first
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else {
                print("❌ Microphone permission denied!")
                return
            }
            print("✅ Microphone permission granted")

            DispatchQueue.main.async {
                do {
                    try self?.configureAudioSession()
                    try self?.startAudioEngine()
                    self?.isRunning = true
                    print("🎤 BreathingAudioEngine started successfully")
                } catch {
                    print("❌ Failed to start audio engine: \(error)")
                }
            }
        }
    }

    func stop() {
        guard isRunning else {
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        simulationTimer?.invalidate() // Invalidate simulation timer if running
        simulationTimer = nil

        do {
            try session.setActive(false, options: [])
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        isRunning = false
        print("BreathingAudioEngine stopped")
    }

    // MARK: - Simulation

    /// Simulates breathing using an audio file
    func startSimulation(fileURL: URL) {
        stop() // Stop any running engine
        
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else {
            print("❌ Simulation failed: Could not read file \(fileURL.lastPathComponent)")
            return
        }
        
        print("▶️ Starting simulation with: \(fileURL.lastPathComponent)")
        isRunning = true
        
        // Convert to compatible format (16kHz Mono Float32)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        try? audioFile.read(into: buffer)
        
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let converter = AVAudioConverter(from: format, to: targetFormat)!
        
        let ratio = 16000.0 / format.sampleRate
        let targetFrameCount = AVAudioFrameCount(Double(frameCount) * ratio)
        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCount)!
        
        var error: NSError? = nil
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        guard let channelData = convertedBuffer.floatChannelData else { return }
        let totalSamples = Int(convertedBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: totalSamples))
        
        var currentOffset = 0
        let chunkSize = 512 // ~32ms at 16kHz
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.032, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            if currentOffset + chunkSize >= totalSamples {
                currentOffset = 0 // Loop
                print("🔄 Loop simulation")
            }
            
            // Get chunk
            let chunk = UnsafePointer(samples).advanced(by: currentOffset)
            
            self.processingQueue.async {
                self.runBreathingPipeline(samples: chunk, count: chunkSize)
            }
            
            currentOffset += chunkSize
        }
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        try session.setCategory(
            .record,
            mode: .measurement,
            options: [.allowBluetoothHFP, .mixWithOthers]
        )
        try session.setPreferredSampleRate(16_000)
        try session.setPreferredIOBufferDuration(0.02) // ~20 ms
        try session.setActive(true, options: [])
    }

    private func startAudioEngine() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Target format: 16 kHz mono Float32
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!

        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

        // Install tap with 1024 sample buffer (~64ms at 16kHz)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            self?.processingQueue.async {
                self?.processAudioBuffer(buffer)
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else {
            return
        }

        // Convert to target format
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(targetFormat.sampleRate * 0.1)
        )!

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error {
            print("Audio conversion error: \(error)")
            return
        }

        guard let channelData = convertedBuffer.floatChannelData?[0] else {
            return
        }
        let frameCount = Int(convertedBuffer.frameLength)

        // Run DSP pipeline
        runBreathingPipeline(samples: channelData, count: frameCount)
    }

    private var frameCount = 0

    private func runBreathingPipeline(samples: UnsafePointer<Float>, count: Int) {
        // Convert to array for processing
        let audioData = Array(UnsafeBufferPointer(start: samples, count: count))

        // Calculate raw audio level (before processing)
        let rawMax = audioData.map { abs($0) }.max() ?? 0
        let normalizedLevel = min(1.0, rawMax * 5) // Scale for visibility
        onAudioLevelUpdate?(normalizedLevel)

        // Step 1: Band-pass filter (80-500 Hz)
        let filtered = dspProcessor.applyBandpassFilter(to: audioData)

        // Step 2: Normalize and apply AGC
        let normalized = dspProcessor.normalizeAndAGC(filtered)

        // Step 3: Compute envelope
        let envelope = dspProcessor.computeEnvelope(normalized)

        // Debug: Log audio levels periodically
        frameCount += 1
        if frameCount % 100 == 0 {
            print("🎤 Raw level: \(String(format: "%.3f", rawMax)), Envelope: \(String(format: "%.3f", envelope.max() ?? 0))")
        }

        // Step 4: Detect breathing activity
        let isBreathingActive = dspProcessor.detectBreathingActivity(envelope: envelope)

        guard isBreathingActive else {
            // Only update to none occasionally to reduce UI updates
            if frameCount % 10 == 0 {
                onBreathingStateUpdate?(.none)
            }
            return
        }

        print("🫁 Breathing activity detected!")

        // Step 5: Extract features for classification
        featureExtractor.addSamples(normalized)

        if let features = featureExtractor.extractFeatures() {
            // Step 6: Classify breathing state (inhale/exhale/none)
            let state = classifier.classify(features: features, envelope: envelope)
            print("🫁 Classified state: \(state)")
            onBreathingStateUpdate?(state)

            // Step 7: Track breathing rate
            rateTracker.update(state: state, envelope: envelope, timestamp: Date())
        }
    }
}

// MARK: - Supporting Types

enum BreathingState: String {
    case none
    case inhale
    case exhale
}
