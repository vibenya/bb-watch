import AVFoundation
import Foundation

@main
struct TranscriptionCheck {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bb-asr-check-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("chunks")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        var chunks: [AudioChunk] = []
        for index in 0..<31 {
            let name = "\(index).caf"
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000)!
            buffer.frameLength = buffer.frameCapacity
            for frame in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![0][frame] = Float(sin(2 * .pi * Double(220 + index * 30) * Double(frame) / 48_000) * 0.3)
            }
            let file = try AVAudioFile(forWriting: folder.appendingPathComponent(name), settings: format.settings)
            try file.write(from: buffer)
            chunks.append(AudioChunk(filename: name, duration: 2))
        }
        let originals = try chunks.map { try Data(contentsOf: folder.appendingPathComponent($0.filename)) }
        let upload = try TranscriptionPipeline.prepare(Array(chunks.prefix(15)), folder: folder)
        let reader = try AVAudioFile(forReading: upload)
        try require(upload.pathExtension == "wav", "Upload must retain the verified WAV container")
        try require(reader.length == 1_440_000 && reader.processingFormat.sampleRate == 48_000, "PCM conversion changed duration/sample rate")
        try require(reader.fileFormat.commonFormat == .pcmFormatInt16, "Compact transport must use 16-bit PCM")
        let decoded = try samples(reader)
        var offset = 0
        var maximumError: Float = 0
        for chunk in chunks.prefix(15) {
            let source = try AVAudioFile(forReading: folder.appendingPathComponent(chunk.filename))
            let expected = try samples(source)
            try require(expected.count == 96_000, "Source checkpoint fixture lost frames")
            for (index, sample) in expected.enumerated() {
                maximumError = max(maximumError, abs(sample - decoded[offset + index]))
            }
            offset += expected.count
        }
        try require(maximumError <= 2.0 / 32_768, "PCM conversion reordered or damaged audio; max_error=\(maximumError)")
        try FileManager.default.removeItem(at: upload)
        let lowFormat = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let lowBuffer = AVAudioPCMBuffer(pcmFormat: lowFormat, frameCapacity: 80)!
        lowBuffer.frameLength = 80
        for index in 0..<80 { lowBuffer.floatChannelData![0][index] = 0.25 }
        do {
            let source = try AVAudioFile(forWriting: folder.appendingPathComponent("low-rate.caf"), settings: lowFormat.settings)
            try source.write(from: lowBuffer)
        }
        let lowUpload = try TranscriptionPipeline.prepare([AudioChunk(filename: "low-rate.caf", duration: 0.005)], folder: folder)
        let lowReader = try AVAudioFile(forReading: lowUpload)
        try require(lowReader.length == 80 && lowReader.processingFormat.sampleRate == 16_000, "PCM transport changed source sample rate/length")
        try FileManager.default.removeItem(at: lowUpload)
        let client = TranscriptionWireFixture.client()
        TranscriptionWireFixture.reset(failCall: 2)
        do {
            _ = try await transcribe(chunks, folder: folder, client: client)
            throw Failure.failed("Expected second segment failure")
        } catch BBClientError.http(503) {}
        try require(TranscriptionWireFixture.snapshot().calls == 2, "ASR failures must not replay implicitly")
        try require(caches(root).count == 1, "Completed segment wasn't persisted before later failure")
        try require(uploads(root).isEmpty, "Failed ASR left temporary uploads")
        TranscriptionWireFixture.reset()
        let text = try await transcribe(chunks, folder: folder, client: client)
        try require(text == "segment-1\nsegment-1\nsegment-2", "Retry lost cached text or ordered concatenation")
        try require(TranscriptionWireFixture.snapshot().calls == 2, "Retry retranscribed a completed segment")
        try require(caches(root).count == 3, "All completed segments must survive relaunch")
        TranscriptionWireFixture.reset()
        let restored = try await transcribe(chunks, folder: folder, client: TranscriptionWireFixture.client())
        try require(restored == text && TranscriptionWireFixture.snapshot().calls == 0, "Restored caches must avoid ASR")
        // Extending a final partial group must invalidate that group's cache only.
        _ = try await transcribe(Array(chunks.prefix(30)), folder: folder, client: client)
        let extended = chunks + [AudioChunk(filename: chunks[0].filename, duration: 2)]
        _ = try await transcribe(extended, folder: folder, client: client)
        try require(TranscriptionWireFixture.snapshot().calls == 1, "Extended final group reused stale transcript")
        TranscriptionWireFixture.reset(unauthorized: 1)
        let tiny = try TranscriptionPipeline.prepare([chunks[0]], folder: folder)
        defer { try? FileManager.default.removeItem(at: tiny) }
        _ = try await TranscriptionWireFixture.client().transcribe(file: tiny)
        try require(TranscriptionWireFixture.snapshot().calls == 2 && TranscriptionWireFixture.snapshot().authCalls == 2, "ASR should reauthenticate once after an expired session")
        TranscriptionWireFixture.reset(unauthorized: 2)
        do {
            _ = try await TranscriptionWireFixture.client().transcribe(file: tiny)
            throw Failure.failed("Expected repeated auth failure")
        } catch BBClientError.http(401) {}
        try require(TranscriptionWireFixture.snapshot().calls == 2, "ASR auth retry must be bounded")
        let isolated = root.appendingPathComponent("isolated/chunks")
        try FileManager.default.createDirectory(at: isolated, withIntermediateDirectories: true)
        try originals[0].write(to: isolated.appendingPathComponent(chunks[0].filename))
        TranscriptionWireFixture.reset()
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transcribe([chunks[0]], folder: isolated, client: client)
        }
        do { _ = try await cancelled.value; throw Failure.failed("Expected cancellation") } catch is CancellationError {}
        try require(TranscriptionWireFixture.snapshot().calls == 0 && caches(isolated.deletingLastPathComponent()).isEmpty, "Cancelled work reached ASR or persisted")
        do {
            _ = try await TranscriptionPipeline.transcribe([chunks[0]], folder: isolated, using: client, operation: DiagnosticOperation(), foreground: false) { if TranscriptionWireFixture.snapshot().calls > 0 { throw Failure.connectionChanged } }
            throw Failure.failed("Expected changed connection after ASR")
        } catch Failure.connectionChanged {}
        try require(TranscriptionWireFixture.snapshot().calls == 1 && caches(isolated.deletingLastPathComponent()).isEmpty, "Changed identity persisted an ASR result")
        try require(uploads(isolated.deletingLastPathComponent()).isEmpty, "Connection change left temporary uploads")
        TranscriptionWireFixture.reset()
        let cancelledAfterASR = Task {
            try await TranscriptionPipeline.transcribe([chunks[0]], folder: isolated, using: client, operation: DiagnosticOperation(), foreground: false) {
                if TranscriptionWireFixture.snapshot().calls > 0 { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        do { _ = try await cancelledAfterASR.value; throw Failure.failed("Expected cancellation after ASR") } catch is CancellationError {}
        try require(TranscriptionWireFixture.snapshot().calls == 1 && caches(isolated.deletingLastPathComponent()).isEmpty, "Cancelled ASR result was persisted")
        try require(uploads(isolated.deletingLastPathComponent()).isEmpty, "Cancelled ASR left temporary uploads")
        do {
            _ = try TranscriptionPipeline.prepare([chunks[0], AudioChunk(filename: "missing.caf", duration: 2)], folder: folder)
            throw Failure.failed("Expected unreadable source failure")
        } catch is Failure { throw Failure.failed("Missing chunk unexpectedly encoded") } catch {}
        try require(uploads(root).filter { $0 != tiny.lastPathComponent }.isEmpty, "Failed preparation left uploads")
        for (chunk, original) in zip(chunks, originals) {
            try require(try Data(contentsOf: folder.appendingPathComponent(chunk.filename)) == original, "Original audio changed")
        }
        print("PASS: PCM16 retains 15 checkpoints within two LSBs; durable 3-segment retry/relaunch/extension, bounded auth recovery, cancellation/identity isolation, temporary cleanup and unchanged originals.")
    }
    static func samples(_ file: AVAudioFile) throws -> [Float] {
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096)!
        var result: [Float] = []
        // AVAudioFile may return fewer frames than requested without reaching EOF.
        while file.framePosition < file.length {
            try file.read(into: buffer)
            try require(buffer.frameLength > 0, "Decoder stopped before EOF")
            result.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        }
        try require(result.count == Int(file.length), "Decoded frame count differs from file length")
        return result
    }
    static func transcribe(_ chunks: [AudioChunk], folder: URL, client: BBClient) async throws -> String {
        try await TranscriptionPipeline.transcribe(chunks, folder: folder, using: client, operation: DiagnosticOperation(), foreground: false) {}
    }
    static func caches(_ root: URL) -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasPrefix("transcript-") } }
    static func uploads(_ root: URL) -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasPrefix("upload-") } }
    static func require(_ value: Bool, _ message: String) throws { if !value { throw Failure.failed(message) } }
    enum Failure: Error { case failed(String), connectionChanged }
}
