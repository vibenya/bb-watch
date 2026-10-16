import AVFoundation
import Foundation

/// Continuous audio capture; files rotate without restarting the microphone.
/// Two-second CAF checkpoints bound unfinalized audio. Hardware crash/power-loss
/// guarantees still require the Ultra 2 acceptance test.
final class AudioWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private var filename = ""
    private let directory: URL
    private let completed: @Sendable (AudioChunk) -> Void
    private var failure: Error?
    private var closed = false
    private var finishedChunks: [AudioChunk] = []

    init(directory: URL, completed: @escaping @Sendable (AudioChunk) -> Void) {
        self.directory = directory
        self.completed = completed
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard !closed, failure == nil else { return }
        do {
            if file == nil {
                let free = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity ?? 0
                guard free > 20 * 1024 * 1024 else { throw AudioFailure.storageFull }
                filename = "\(Date().timeIntervalSince1970)-\(UUID().uuidString).caf"
                file = try AVAudioFile(forWriting: directory.appendingPathComponent(filename), settings: buffer.format.settings)
                frames = 0
            }
            try file?.write(from: buffer)
            frames += AVAudioFramePosition(buffer.frameLength)
            if Double(frames) / buffer.format.sampleRate >= 2 { try checkpoint() }
        } catch { failure = error }
    }

    private func checkpoint() throws {
        guard file != nil else { return }
        let duration = Double(frames) / file!.processingFormat.sampleRate
        // Do not retain a local AVAudioFile: its release finalizes the CAF header.
        file = nil
        let handle = try FileHandle(forWritingTo: directory.appendingPathComponent(filename))
        try handle.synchronize()
        try handle.close()
        let chunk = AudioChunk(filename: filename, duration: duration)
        finishedChunks.append(chunk)
        completed(chunk)
        frames = 0
    }

    func finish() throws {
        lock.lock(); defer { lock.unlock() }
        closed = true
        try checkpoint()
        if let failure { throw failure }
    }
    func finalizedChunks() -> [AudioChunk] { lock.lock(); defer { lock.unlock() }; return finishedChunks }
    func currentError() -> Error? { lock.lock(); defer { lock.unlock() }; return failure }
}

enum AudioFailure: LocalizedError {
    case denied, noInput, storageFull
    var errorDescription: String? {
        switch self {
        case .denied: return "Microphone access is off. Allow it in Watch Settings."
        case .noInput: return "Microphone unavailable. Recording did not start."
        case .storageFull: return "Not enough storage. Recording stopped; saved parts remain on this watch."
        }
    }
}
