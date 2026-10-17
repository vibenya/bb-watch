import AVFoundation
import Foundation

/// Synthetic host benchmark. No provider calls, private audio or wall-clock claims about LTE.
@main
struct TranscriptionPerformanceCheck {
    static func main() async throws {
        let client = TranscriptionWireFixture.client()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bb-asr-perf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let rate = 48_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        var chunks: [AudioChunk] = []
        for index in 0..<15 {
            let name = "\(index).caf"
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000)!
            buffer.frameLength = buffer.frameCapacity
            for frame in 0..<Int(buffer.frameLength) {
                let time = Double(index * 96_000 + frame) / rate
                buffer.floatChannelData![0][frame] = Float(0.3 * sin(2 * .pi * (220 + Double(index) * 30) * time))
            }
            let file = try AVAudioFile(forWriting: root.appendingPathComponent(name), settings: format.settings)
            try file.write(from: buffer)
            chunks.append(AudioChunk(filename: name, duration: 2))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TranscriptionWireFixture.self]
        let baselineSession = URLSession(configuration: config)
        for run in 0..<5 {
            let file = root.appendingPathComponent("baseline-\(run).wav")
            let start = Date()
            try baselineAssemble(chunks, folder: root, output: file)
            let assembled = Date()
            let boundary = "synthetic-boundary"
            var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8)
            body.append(try Data(contentsOf: file)); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            let end = Date()
            TranscriptionWireFixture.reset()
            var request = URLRequest(url: URL(string: "https://asr-fixture.invalid/api/v1/system/voice-transcription")!)
            request.httpMethod = "POST"; request.httpBody = body
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("fixture-session=fixture-cookie", forHTTPHeaderField: "Cookie")
            _ = try await baselineSession.data(for: request)
            let transported = Date()
            print("baseline run=\(run) duration_s=30 chunks=15 segments=1 pcm_bytes=5760000 encoded_bytes=\(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize!) multipart_bytes=\(body.count) assembly_ms=\(ms(start, assembled)) multipart_ms=\(ms(assembled, end)) local_total_ms=\(ms(start, transported)) mock_transport_ms=\(ms(end, transported)) provider_ms=unmeasured")
        }
        for run in 0..<5 {
            let start = Date()
            let file = try TranscriptionPipeline.prepare(chunks, folder: root)
            defer { try? FileManager.default.removeItem(at: file) }
            let encoded = Date()
            TranscriptionWireFixture.reset()
            _ = try await client.transcribe(file: file)
            let end = Date()
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize!
            guard size < 3_000_000 else { throw CocoaError(.fileWriteUnknown) }
            let decoded = try AVAudioFile(forReading: file)
            guard abs(Double(decoded.length) / decoded.processingFormat.sampleRate - 30) < 0.1 else { throw CocoaError(.fileReadCorruptFile) }
            print("compact run=\(run) duration_s=30 chunks=15 segments=1 pcm_bytes=5760000 encoded_bytes=\(size) multipart_bytes=\(TranscriptionWireFixture.snapshot().bytes) assembly_encoding_ms=\(ms(start, encoded)) mock_transport_ms=\(ms(encoded, end)) local_total_ms=\(ms(start, end)) provider_ms=unmeasured")
        }
    }
    static func ms(_ a: Date, _ b: Date) -> String { String(format: "%.3f", b.timeIntervalSince(a) * 1000) }
    // Exact pre-extraction assembly path, retained only as an independent benchmark comparison.
    static func baselineAssemble(_ chunks: [AudioChunk], folder: URL, output: URL) throws {
        var writer: AVAudioFile?
        for chunk in chunks {
            let reader = try AVAudioFile(forReading: folder.appendingPathComponent(chunk.filename))
            if writer == nil { writer = try AVAudioFile(forWriting: output, settings: reader.processingFormat.settings) }
            let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: 4096)!
            while reader.framePosition < reader.length {
                try reader.read(into: buffer)
                guard buffer.frameLength > 0 else { throw CocoaError(.fileReadCorruptFile) }
                try writer?.write(from: buffer)
            }
        }
        writer = nil
    }
}
