import AVFoundation
import Foundation

/// Executable integration check using actual CAF encoding/decoding on disk.
@main
struct AudioCheckpointCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bb-audio-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rate = 16_000.0
        let framesPerBuffer: AVAudioFrameCount = 4_000
        let count = 21 // 5.25 seconds, including a final incomplete checkpoint.
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let writer = AudioWriter(directory: directory) { _ in }
        var sourceFrame = 0
        for _ in 0..<count {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerBuffer)!
            buffer.frameLength = framesPerBuffer
            for frame in 0..<Int(framesPerBuffer) {
                buffer.floatChannelData![0][frame] = sample(sourceFrame + frame, rate: rate)
            }
            writer.append(buffer)
            sourceFrame += Int(framesPerBuffer)
        }
        try writer.finish()
        let chunks = writer.finalizedChunks()
        guard chunks.count == 3 else { throw Failure.failed("Expected 3 checkpoints; got \(chunks.count)") }
        try writer.finish()
        guard writer.finalizedChunks() == chunks else { throw Failure.failed("Repeated finalization duplicated or changed chunks") }
        var decodedFrames = 0
        for chunk in chunks {
            let reader = try AVAudioFile(forReading: directory.appendingPathComponent(chunk.filename))
            guard abs(chunk.duration - Double(reader.length) / rate) < 0.000001 else { throw Failure.failed("Metadata duration differs from finalized CAF length") }
            guard reader.processingFormat.sampleRate == rate else { throw Failure.failed("Sample rate changed") }
            let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: 4096)!
            while reader.framePosition < reader.length {
                try reader.read(into: buffer)
                for frame in 0..<Int(buffer.frameLength) {
                    let expected = sample(decodedFrames + frame, rate: rate)
                    guard abs(buffer.floatChannelData![0][frame] - expected) < 0.00001 else {
                        throw Failure.failed("Missing, reordered or damaged sample at frame \(decodedFrames + frame)")
                    }
                }
                decodedFrames += Int(buffer.frameLength)
            }
        }
        guard decodedFrames == sourceFrame else { throw Failure.failed("Lost frames: \(decodedFrames) of \(sourceFrame)") }
        guard abs(chunks.reduce(0) { $0 + $1.duration } - 5.25) < 0.000001 else { throw Failure.failed("Incorrect total duration") }
        print("PASS: 3 finalized CAF checkpoints, 84,000 ordered samples, 5.25 seconds; repeated finish is idempotent.")
    }
    static func sample(_ index: Int, rate: Double) -> Float { Float(sin(2 * .pi * 440 * Double(index) / rate) * 0.5) }
    enum Failure: Error { case failed(String) }
}
