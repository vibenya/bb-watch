import AVFoundation
import Foundation

/// Async nonisolated work runs off MainActor; only connection validation returns to the UI owner.
/// The durable queue still owns sending. This module never dispatches an agent prompt.
enum TranscriptionPipeline {
    static func transcribe(_ chunks: [AudioChunk], folder: URL, using client: BBClient,
                           operation: DiagnosticOperation, foreground: Bool,
                           validate: @Sendable () async throws -> Void) async throws -> String {
        var results: [String] = []
        var group: [AudioChunk] = []
        var duration: TimeInterval = 0
        // Keep existing boundaries/cache names so an upgrade reuses completed ASR work.
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            group.append(chunk); duration += chunk.duration
            guard duration >= 30 || index == chunks.count - 1 else { continue }
            try await validate()
            try Task.checkCancellation()
            let cache = folder.deletingLastPathComponent().appendingPathComponent("transcript-\(group.first!.filename)-\(group.last!.filename)-\(group.count).json")
            if FileManager.default.fileExists(atPath: cache.path) {
                results.append(try JSONDecoder().decode(String.self, from: Data(contentsOf: cache)))
                await WatchDiagnostics.shared.record(.transcriptionCached, operation: operation, foreground: foreground, group: results.count - 1)
            } else {
                await WatchDiagnostics.shared.record(.assemblyStarted, operation: operation, foreground: foreground, group: results.count, count: group.count)
                let upload = try prepare(group, folder: folder)
                defer { try? FileManager.default.removeItem(at: upload) }
                await WatchDiagnostics.shared.record(.assemblyFinished, operation: operation, foreground: foreground, group: results.count)
                try Task.checkCancellation()
                try await validate()
                try Task.checkCancellation()
                let bytes = (try? upload.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let milliseconds = duration.isFinite && duration >= 0 && duration < Double(Int.max) / 1000 ? Int(duration * 1000) : nil
                await WatchDiagnostics.shared.record(.transcriptionStarted, operation: operation, foreground: foreground, group: results.count, bytes: bytes, audioMilliseconds: milliseconds)
                let text = try await client.transcribe(file: upload)
                await WatchDiagnostics.shared.record(.transcriptionFinished, operation: operation, foreground: foreground, group: results.count)
                try Task.checkCancellation()
                try await validate()
                try Task.checkCancellation()
                try JSONEncoder().encode(text).write(to: cache, options: .atomic)
                results.append(text)
            }
            group = []; duration = 0
        }
        try Task.checkCancellation()
        try await validate()
        try Task.checkCancellation()
        return results.joined(separator: "\n")
    }

    /// Compact PCM keeps the verified WAV container and source sample rate/channels.
    static func prepare(_ chunks: [AudioChunk], folder: URL) throws -> URL {
        guard let first = chunks.first else { throw Failure.audio }
        let format = try AVAudioFile(forReading: folder.appendingPathComponent(first.filename)).processingFormat
        let output = folder.deletingLastPathComponent().appendingPathComponent("upload-\(UUID().uuidString).wav")
        do {
            let frames = try assemble(chunks, folder: folder, output: output,
                         settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate,
                                    AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16,
                                    AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            let encoded = try AVAudioFile(forReading: output)
            guard encoded.length == frames, encoded.processingFormat.sampleRate == format.sampleRate,
                  encoded.processingFormat.channelCount == format.channelCount else { throw Failure.audio }
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    private static func assemble(_ chunks: [AudioChunk], folder: URL, output: URL, settings: [String: Any]) throws -> AVAudioFramePosition {
        let writer = try AVAudioFile(forWriting: output, settings: settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: writer.processingFormat, frameCapacity: 16_384) else { throw Failure.audio }
        var frames: AVAudioFramePosition = 0
        for chunk in chunks {
            try Task.checkCancellation()
            let reader = try AVAudioFile(forReading: folder.appendingPathComponent(chunk.filename))
            guard reader.processingFormat == writer.processingFormat else { throw Failure.audio }
            while reader.framePosition < reader.length {
                try Task.checkCancellation()
                try reader.read(into: buffer)
                guard buffer.frameLength > 0 else { throw Failure.audio }
                try writer.write(from: buffer)
                frames += AVAudioFramePosition(buffer.frameLength)
            }
        }
        // AVAudioFile closes/finalizes on release, before the caller can upload.
        return frames
    }
    enum Failure: LocalizedError {
        case audio
        var errorDescription: String? { "Could not prepare the recording. Original audio is saved." }
    }
}
