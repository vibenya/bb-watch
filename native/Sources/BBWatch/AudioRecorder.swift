import AVFoundation
import Foundation
import WatchKit

@MainActor
final class WatchRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var error: String?
    @Published private(set) var finalizationFailed = false
    /// Smoothed input level 0…1 for the recording ring; updated ~10×/s.
    @Published private(set) var level: Float = 0
    private let engine = AVAudioEngine()
    private var writer: AudioWriter?
    private var lastFinalizedChunks: [AudioChunk] = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var startedAt: Date?
    private var baseDuration: TimeInterval = 0
    private var starting = false
    var onInterruption: (() -> Void)?

    init() {
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, .AVAudioEngineConfigurationChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                // The observer already executes on main. Avoid queuing a second task
                // that could mistake a startup configuration event for a later interruption.
                MainActor.assumeIsolated {
                    guard let self, self.isRecording else { return }
                    if notification.name == AVAudioSession.interruptionNotification {
                        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                    } else if notification.name == AVAudioSession.routeChangeNotification {
                        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                              reason == .oldDeviceUnavailable || reason == .noSuitableRouteForCategory else { return }
                    } else {
                        guard !self.engine.isRunning else { return }
                    }
                    self.pause()
                    if !self.finalizationFailed { self.error = "Recording interrupted. Saved parts are available." }
                    self.onInterruption?()
                }
            })
        }
    }

    func start(directory: URL, duration: TimeInterval, completed: @escaping @Sendable (AudioChunk) -> Void) async throws {
        guard !isRecording, !starting else { throw AudioFailure.noInput }
        starting = true; defer { starting = false }
        guard await AVAudioApplication.requestRecordPermission() else { throw AudioFailure.denied }
        let free = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity ?? 0
        guard free > 20 * 1024 * 1024 else { throw AudioFailure.storageFull }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioFailure.noInput }
        let sink = AudioWriter(directory: directory, completed: completed)
        writer = sink
        lastFinalizedChunks = []
        let meter = LevelMeter()
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            sink.append(buffer)
            if let value = meter.sample(buffer) { Task { @MainActor in self?.level = value } }
        }
        do { try engine.start() } catch {
            input.removeTap(onBus: 0); writer = nil
            try? session.setActive(false)
            throw error
        }
        error = nil; finalizationFailed = false
        baseDuration = duration; elapsed = duration; startedAt = Date(); isRecording = true
        WKInterfaceDevice.current().play(.start)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.elapsed = self.baseDuration + (self.startedAt.map { Date().timeIntervalSince($0) } ?? 0)
                if let error = self.writer?.currentError() {
                    self.pause(); self.error = error.localizedDescription; self.onInterruption?()
                }
            }
        }
    }

    @discardableResult func pause() -> [AudioChunk] {
        guard isRecording else { return lastFinalizedChunks }
        isRecording = false
        engine.stop(); engine.inputNode.removeTap(onBus: 0)
        do { try writer?.finish() } catch { self.error = error.localizedDescription; finalizationFailed = true }
        let chunks = writer?.finalizedChunks() ?? []
        lastFinalizedChunks = chunks
        elapsed = baseDuration + chunks.reduce(0) { $0 + $1.duration }
        writer = nil; isRecording = false; timer?.invalidate(); timer = nil; level = 0
        try? AVAudioSession.sharedInstance().setActive(false)
        WKInterfaceDevice.current().play(.stop)
        return chunks
    }
}

/// RMS → 0…1 with decay, throttled to every 4th buffer (~10 Hz at 2048 frames / 48 kHz).
private final class LevelMeter: @unchecked Sendable {
    private var count = 0
    private var smoothed: Float = 0
    func sample(_ buffer: AVAudioPCMBuffer) -> Float? {
        count += 1
        guard count % 4 == 0, let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        let db = max(-50, 20 * log10(max(rms, 1e-6)))
        let value = (db + 50) / 50
        smoothed = max(value, smoothed * 0.8)
        return smoothed
    }
}
